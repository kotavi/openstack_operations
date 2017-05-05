#!/bin/bash +x
# for Linux OS only

openrc_path=$1
image_name=$2

if [[ -n "$openrc_path" && -e $openrc_path ]] ; then
    source $openrc_path
else
    echo "Please provide correct path to openrc"
    exit 1
fi

if $(pip freeze | grep sshpass); then
    echo "Package sshpass is already installed"
    continue
else
    echo "Do you want to install sshpass package? (Y/N)"
    read answer
    if [ $answer == "Y" ]; then
        apt-get install sshpass
    else
        echo "Package sshpass will NOT be installed."
    fi
fi


flavor_id=2
floating_net=admin_floating_net
volume_type=netapp
volume_size=2


VM_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
volume_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
snapshot_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')


volume_id=$(openstack volume create --image $image_name --size $volume_size --type $volume_type $volume_name | grep ' id ' | awk {print $4})
snapshot_id=$(openstack snapshot create --name snapshot_from_vol --force $volume_id | grep ' id ' | awk {print $4})

# create keypair
keypair_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)

result="$(nova keypair-add "$keypair_name" >"spt-temporary-keypair" 2>&1)"

# create keypair
result="$(nova keypair-add "spt-temporary-keypair" >"temporary-keypair" 2>&1)"
chmod 600 "temporary-keypair"



VM_id=$(nova boot --snapshot $snapshot_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name temporary-keypair --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
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
