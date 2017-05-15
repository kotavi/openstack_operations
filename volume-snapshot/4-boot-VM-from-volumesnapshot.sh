#!/bin/bash -x


#create volume from image
#create snapshot from volume
#create keypair
#launch VM from snapshot with keypair  and get hostname of VM


#./4-boot-VM-from-volumesnapshot.sh -openrc=openrc -i=TestVM -u=cirros -f=2 -v_s=2 -v_t=netapp

source ../funcs.sh

for i in "$@"
do
case $i in
    -openrc=*)
    openrc_path="${i#*=}"
    ;;
    -i=*|--image_name=*)
    image_name="${i#*=}"
    ;;
    -u=*|--user=*)
    user="${i#*=}"
    ;;
    -f=*|--flavor_id=*)
    flavor_id="${i#*=}"
    ;;
    -v_s=*|--volume_size=*)
    volume_size="${i#*=}"
    ;;
    -v_t=*|--volume_type=*)
    volume_type="${i#*=}"
    ;;
    *)
    ;;
esac
done


if [[ -n "$openrc_path" && -e $openrc_path ]] ; then
    source $openrc_path
else
    echo "Please provide correct path to openrc"
    exit 1
fi

clear_data(){
        [ -n "$VM_id" ] && [ -n "$floatingip" ] && nova floating-ip-disassociate $VM_id $floatingip
        [ -n "$floatingip" ] && nova floating-ip-delete $floatingip
        nova floating-ip-list
        [ -n "$VM_id" ] && nova delete $VM_id
        nova list
        [ -n "$snapshot_id" ] && openstack snapshot delete $snapshot_id
        [ -n "$volume_id" ] && openstack volume delete $volume_id
        [ -n "$new_volume_id" ] && openstack volume delete $new_volume_id
        [ -n "$keypair_name" ] && openstack keypair delete $keypair_name
}

random=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
VM_name=$pattern"_"$random"_VM"
volume_name=$pattern"_"$random"_volume"
snapshot_name=$pattern"_"$random"_snapshot"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')


volume_id=$(openstack volume create --image $image_name --size $volume_size --type $volume_type $volume_name | grep ' id ' | awk '{print $4}')
volume_status $volume_id

snapshot_id=$(openstack snapshot create --name $snapshot_name --force $volume_id | grep ' id ' | awk '{print $4}')
snapshot_status $snapshot_id

keypair_name=`create_keypair`

VM_id=$(nova boot --snapshot $snapshot_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
VM_status $VM_id

new_volume=`get_volume_attached_id $VM_id`

floatingip=`create_fip $VM_id`
sleep 5
nova show $VM_id
ping $floatingip
ssh-keygen -R $floatingip
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user@$floatingip hostname 2>&1

clear_data