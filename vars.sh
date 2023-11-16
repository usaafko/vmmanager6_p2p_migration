###
### Common variables for p2p-migration script
### AO Exo-soft 2023 
### Author: Kalinichenko Ilya 
### mailto: i.kalinichenko@ispsystem.com
###

# VMmanager 6 URLs
VM_FROM_URL='https://172.31.49.33'
VM_DEST_URL='https://172.31.49.33'

# VMmanager 6 user with administrator rights 
VM_FROM_LOGIN='admin@example.com'
VM_FROM_PASS='q1w2e3'
VM_DEST_LOGIN='admin@example.com'
VM_DEST_PASS='q1w2e3'

# VMmanager 6 master server IP. Please configure SSH access from this node to master by ssh keys
VM_FROM_IP='172.31.49.33'
VM_DEST_IP='172.31.49.33'

# VMmanager account id. VM will migrate to that account
VM_DEST_ACCOUNT=3

# VMmanager cluster id. VM will mmigrate to that cluster
VM_DEST_CLUSTER=1