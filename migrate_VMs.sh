#!/bin/bash -x
# for ssh part
# apt-get install sshpass
# for opanstack commands
# source openrc



flavor_id=1


#get list of hypervisors
hypervisor_list=$(nova hypervisor-list | grep '{print$4}' | grep -v Hypervisor)

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')
image_id=$(glance image-list | grep TestVM | awk '{print$2}')
for i in $hypervisor_list
  do
    VM_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    VM_id=$(nova boot --flavor $flavor_id --image $image_id --availability-zone nova:$i --security-groups $security_group_id --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
    sleep 5
    nova show $VM_id
  done


#
#VM_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
#security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
#admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')
#image_id=$(glance image-list | grep TestVM | awk '{print$2}')
#
#VM_id=$(nova boot --flavor $flavor_id --image $image_id --availability-zone nova --security-groups $security_group_id --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
#sleep 5
#host=$(nova show $VM_id | grep OS-EXT-SRV-ATTR:hypervisor_hostname | awk '{print$4}')
#nova show $VM_id
#
#
#
#clear_data(){
#	nova delete $VM_id
#	nova list
#}
#
#ssh_to_VM
#clear_data
