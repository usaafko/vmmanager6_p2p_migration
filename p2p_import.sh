#!/bin/bash
###
### Platform2Platform import script for VMmanager 6
### AO Exo-soft 2023 
### Author: Kalinichenko Ilya 
### mailto: i.kalinichenko@ispsystem.com
###

. ./common.sh

IMPORT_VM=$1

### Checking
pprint "Check if VM exists ..."

vm_meta=$(get $token_from $VM_FROM_URL "vm/v3/host/$IMPORT_VM/metadata")
if echo $vm_meta | grep -qv error; then
	pprint "VM id $IMPORT_VM exists"
	
else
	perror "VM not exists"
	exit
fi

pprint "Checking SSH access to $VM_FROM_IP"
ssh root@$VM_FROM_IP true
if [ $? -eq 0 ]; then
	pprint "Ok"
else
	perror "Can't connect to $VM_FROM_IP"
	exit
fi

pprint "Checking SSH access to $VM_DEST_IP"
ssh root@$VM_DEST_IP true
if [ $? -eq 0 ]; then
	pprint "Ok"
else
	perror "Can't connect to $VM_DEST_IP"
	exit
fi

vm_state=$(echo $vm_meta | jq -r '.metadata.state.disabled')
if [ -z "$vm_state" ] || [ "$vm_state" = "false" ]; then
	perror "Please turn off VM before migration"
	exit
fi

# copy ssh key from docker
ssh root@$VM_FROM_IP "mkdir -p /root/p2p_migration; docker cp vm_box:/opt/ispsystem/vm/etc/.ssh/vmmgr.1 /root/p2p_migration"
ssh root@$VM_DEST_IP "mkdir -p /root/p2p_migration; docker cp vm_box:/opt/ispsystem/vm/etc/.ssh/vmmgr.1 /root/p2p_migration"

# get source information
NODE_FROM_IP=$(echo $vm_meta | jq -r '.metadata.node.ip_addr')
VM_NAME=$(echo $vm_meta | jq -r '.metadata.internal_name')
VM_FROM_DISKS_PATH=$(ssh root@$VM_FROM_IP ssh -o StrictHostKeyChecking=no -i /root/p2p_migration/vmmgr.1 root@$NODE_FROM_IP virsh domblklist $VM_NAME | awk 'NR>1 {printf "%s ", $2}' )

# get destination cluster information about storages
dest_cluster_json=$(get $token_dest $VM_DEST_URL "vm/v3/cluster?where=(id+EQ+$VM_DEST_CLUSTER)")
dest_storage=$(echo $dest_cluster_json | jq -r '.list[0].storage.id')
dest_ippool=$(echo $dest_cluster_json | jq -r '.list[0].ippools[0].id')

# create VM on destination
old_vm_name=$(echo $vm_meta | jq -r '.metadata.name')
old_vm_domain=$(echo $vm_meta | jq -r '.metadata.domain')
old_vm_ip=$(echo $vm_meta | jq -r '.metadata.ipv4[0].ip_addr')
old_vm_disks_ids=$(echo $vm_meta | jq -r '.metadata.disks[].name')
old_vm_cpu=$(echo $vm_meta | jq -r '.metadata.base_resources.cpu_number')
old_vm_ram=$(echo $vm_meta | jq -r '.metadata.base_resources.ram_mib')

new_vm_json=$(mktemp /tmp/newvmXXXXX)
cat << EOF > $new_vm_json
{
    "name": "$old_vm_name",
    "os": 1,
    "password": "bsOXBc1FkpRrijB9pwsF",
    "send_email_mode": "default",
    "cluster": $VM_DEST_CLUSTER,
    "account": $VM_DEST_ACCOUNT,
    "cpu_number": $old_vm_cpu,
    "ram_mib": $old_vm_ram,
    "ipv4_number": 1,
    "ipv4_pool": [
    	$dest_ippool
    ],
    "domain": "$old_vm_domain",
    "disks":
    [
EOF
DISK_ITER=0
for DISK_ID in $old_vm_disks_ids; do
	DISK_SIZE=$(echo $vm_meta | jq -r ".metadata.disks[$DISK_ITER].size_mib")
	DISK_NAME=$(echo $vm_meta | jq -r ".metadata.disks[$DISK_ITER].name")
	if [ "$DISK_ITER" -ge 1 ]; then echo ',' >>  $new_vm_json; fi
	cat << EOF >> $new_vm_json
        {
            "size_mib": $DISK_SIZE,
            "boot_order": $((DISK_ITER+1)),
			"storage": $dest_storage,
			"name": "$DISK_NAME",
            "tags":
            []
        }
EOF
	DISK_ITER=$((DISK_ITER+1))
done

cat << EOF >> $new_vm_json
    ]

}
EOF

pprint "Creating new VM..."
cat $new_vm_json

newvm=$(post "@${new_vm_json}" $VM_DEST_URL 'vm/v3/host' $token_dest)
check_err "$newvm"
rm -f $new_vm_json

new_vm_id=$(echo $newvm | jq -r '.id')
while true
do
	new_vm_json=$(get $token_dest $VM_DEST_URL "vm/v3/host/$new_vm_id")
 	check_err "$new_vm_json"
	if [ "x$(echo $new_vm_json | jq -r '.state')" = "xactive" ]; then
		break
	fi
	pprint "Waiting..."
	sleep 5
done

pprint "Turning it off"
post '{ "host_id": '$new_vm_id' }' $VM_DEST_URL "vm/v3/host/$new_vm_id/stop" $token_dest
while true
do
	new_vm_json=$(get $token_dest $VM_DEST_URL "vm/v3/host/$new_vm_id")
	check_err "$new_vm_json"
	if [ "x$(echo $new_vm_json | jq -r '.state')" = "xstopped" ]; then
		break
	fi
	pprint "Waiting..."
	sleep 5
done

# get destination information
new_vm_meta=$(get $token_dest $VM_DEST_URL "vm/v3/host/$new_vm_id/metadata")
NODE_DEST_IP=$(echo $new_vm_meta | jq -r '.metadata.node.ip_addr')
NEW_VM_NAME=$(echo $new_vm_meta | jq -r '.metadata.internal_name')
VM_DEST_DISKS_PATH=$(ssh root@$VM_DEST_IP ssh -o StrictHostKeyChecking=no -i /root/p2p_migration/vmmgr.1 root@$NODE_DEST_IP virsh domblklist $NEW_VM_NAME | awk 'NR>1 {printf "%s ", $2}' )

# Migrate disks
for DISK in $(echo $vm_meta | jq -r ".metadata.disks[].name"); do
	for O_DISK in $VM_FROM_DISKS_PATH;
	do
		if echo $O_DISK | grep -q "${DISK}$"; then
			oldname=$O_DISK
		fi
	done
	if [ -z "$oldname" ]; then 
		perror "Can't find source disk name"
		exit
	fi
	for D_DISK in $VM_DEST_DISKS_PATH;
	do
		if echo $D_DISK | grep -q "${DISK}$"; then
			newname=$D_DISK
		fi
	done
	if [ -z "$newname" ]; then 
		perror "Can't find destination disk name"
		exit
	fi
	
	pprint "Migrating disk $oldname from host $NODE_FROM_IP to host $NODE_DEST_IP $newname"
	ssh -o Compression=no root@$VM_FROM_IP "ssh -i /root/p2p_migration/vmmgr.1 -o Compression=no -o StrictHostKeyChecking=no  root@$NODE_FROM_IP dd if=$oldname bs=1M" | \
		ssh -o Compression=no root@$VM_DEST_IP "ssh -i /root/p2p_migration/vmmgr.1 -o Compression=no -o StrictHostKeyChecking=no root@$NODE_DEST_IP dd of=$newname"
done

pprint "Turning VM on"
post '{ "host_id": '$new_vm_id' }' $VM_DEST_URL "vm/v3/host/$new_vm_id/start" $token_dest


pprint "Done"