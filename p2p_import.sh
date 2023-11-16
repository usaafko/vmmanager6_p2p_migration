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

ssh root@$VM_FROM_IP "mkdir -p /root/p2p_migration; docker cp vm_box:/opt/ispsystem/etc/.ssh/vmmgr.1 /root/p2p_migration"
ssh root@$VM_DEST_IP "mkdir -p /root/p2p_migration; docker cp vm_box:/opt/ispsystem/etc/.ssh/vmmgr.1 /root/p2p_migration"
NODE_FROM_IP=$(echo $vm_meta | jq -r '.metadata.node.ip_addr')
VM_DISK_NAME=$(echo $vm_meta | jq -r '.metadata.disks[1].')
ssh root@$VM_FROM_IP "ssh -i root@$NODE_FROM_IP dd="