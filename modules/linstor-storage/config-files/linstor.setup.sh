#!/bin/bash

VM_NAME=$1
IPADDRESS=$(ip address show | grep ens | awk '/inet / {split($2,var,"/*"); print var[1]}')
STG_POOL="k8-storage-pool"
STG_VOL_GROUP="vg_linstor_group"

linstor node create $VM_NAME.k8.local $IPADDRESS
# verification
linstor node list

# prepare the storage
pvcreate /dev/vdb
vgcreate $STG_VOL_GROUP /dev/vdb
lvcreate -l 100%FREE --thinpool $STG_VOL_GROUP/lvmthinpool
linstor storage-pool create lvmthin $VM_NAME.k8.local $STG_POOL $STG_VOL_GROUP/lvmthinpool