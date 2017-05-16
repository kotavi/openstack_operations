#!/bin/bash -x

openrc_path=$1

if [[ -n "$openrc_path" && -e $openrc_path ]] ; then
    source $openrc_path
else
    echo "Please provide correct path to openrc"
    exit 1
fi

flavor_id=1
flavor_id_new=2

#get list of hypervisors
sorted_list=$(nova hypervisor-list | grep -v Hypervisor | awk '{print$4}' >> test.dat &&  sort -k2 -n test.dat && rm test.dat)
# get information for boot
security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')
image_id=$(glance image-list | grep TestVM | awk '{print$2}')

create_VMs(){
    array=()
    for i in $hypervisor_list
      do
        VM_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        VM_id=$(nova boot --flavor $flavor_id --image $image_id --availability-zone nova:$i --security-groups $security_group_id --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
        sleep 5
        nova show $VM_id
        array+=($VM_id)
      done
}

echo ${array[@]}

get_host_flavor(){
    host=$(nova show ${array[$i]} | grep OS-EXT-SRV-ATTR:hypervisor_hostname | awk '{print$4}')
    echo "Current host: $host"
    flavor_id=$(nova show ${array[$i]} | grep flavor | awk '{print$4}')
    echo "Current host: $flavor_id"
}

execute_resize(){
    echo "-------------Starting resize of VMs-------------"
    for i in ${array[@]}
      do
        get_host_flavor
        nova resize --poll ${array[$i]} 2
        sleep 20
        get_host_flavor
      done
}


execute_migrate(){
    echo "-------------Starting migration of VMs-------------"
    for i in ${array[@]}
      do
        get_host_flavor
        nova migrate --poll ${array[$i]}
        sleep 20
        get_host_flavor
      done
}

#execute_live_migrate(){
#    echo "-------------Starting live migration of VMs-------------"
#    for i in ${array[@]}
#        do
#            for j in $hypervisor_list
#              do
#                get_host_flavor
#                nova live-migration --block-migrate ${array[$i]} $j
#                sleep 20
#                get_host_flavor
#              done
#        done
#}

create_VMs
execute_resize
sleep 10
execute_migrate
