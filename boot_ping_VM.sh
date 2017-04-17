#!/bin/bash -x
# for ssh part
# apt-get install sshpass
# for opanstack commands
# source openrc


flavor_id=1
floating_net=admin_floating_net

VM_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')
image_id=$(glance image-list | grep TestVM | awk '{print$2}')

VM_id=$(nova boot --flavor $flavor_id --image $image_id --availability-zone nova --security-groups $security_group_id --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
sleep 5

internalip=$(nova show $VM_id | grep admin_internal_net | awk '{print$5}')

if [ -z "$internalip" ]; then
   nova delete $VM_id
   exit
fi
	
floatingip=$(neutron floatingip-create $floating_net | grep ' floating_ip_address ' | awk '{print$4}' )

nova floating-ip-associate --fixed-address $internalip $VM_id $floatingip
sleep 10

nova show $VM_id

ping $floatingip
ssh_to_VM() { 
	sleep 5
	sshpass -p "cubswin:)" ssh -o StrictHostKeyChecking=no cirros@$floatingip hostname 2>&1
}

clear_data(){
	nova floating-ip-disassociate $VM_id $floatingip
	nova floating-ip-delete $floatingip
	nova floating-ip-list
	nova delete $VM_id
	nova list
}

ssh_to_VM
clear_data
