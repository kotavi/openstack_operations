#!/bin/bash -x

source ./funcs.sh


VM_ids=$(nova list | grep $pattern | awk '{print $2}')
for uuid in $VM_ids; do
    fip=`nova show $uuid | grep network | awk '{print $6}'`
    key_name=`nova show $uuid | grep key_name | awk '{print $4}'`
    nova floating-ip-disassociate $uuid $fip;
    nova floating-ip-delete $fip;
    nova delete $uuid;
done

volume_ids=$(openstack volume list | grep $pattern | awk '{print $2}')
for uuid in $volume_ids; do
    openstack volume delete $uuid;

done

keypair_names=$(openstack keypair list | grep $pattern | awk '{print $2}')
for key_name in $keypair_names; do
    openstack keypair delete $key_name

done

