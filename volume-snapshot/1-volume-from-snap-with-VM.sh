#!/bin/bash -x


#create volume from image
#boot VM from volume
#check ssh and ping
#create snapshot from volume
#create volume from snapshot


#./1-volume-from-snap-with-VM.sh -openrc=openrc -i=TestVM -u=cirros -f=2 -v_s=2 -v_t=netapp

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
    [ -n "$floatingip_1" ] && [ -n "$VM_id" ] && nova floating-ip-disassociate $VM_id $floatingip_1
    [ -n "$floatingip_1" ] && nova floating-ip-delete $floatingip_1
    [ -n "$VM_id" ] && nova delete $VM_id
    sleep 5
    [ -n "$snapshot_id" ] && openstack snapshot delete $snapshot_id
    [ -n "$volume_id_1" ] && openstack volume delete $volume_id_1
    [ -n "$volume_id_2" ] && openstack volume delete $volume_id_2
    [ -n "$keypair_name_1" ] && openstack keypair delete $keypair_name_1
}

random=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
volume1_name=$pattern"_"$random"_volume1"
volume2_name=$pattern"_"$random"_volume2"
VM_name=$pattern"_"$random"_VM1"
snapshot_name=$pattern"_"$random"_snapshot"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')


volume_id_1=$(openstack volume create --image $image_name --size $volume_size --type $volume_type $volume1_name | grep ' id ' | awk '{print $4}')
volume_status $volume_id_1

keypair_name_1=`create_keypair`
VM_id=$(nova boot --boot-volume $volume_id_1 --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_1 --nic net-id=$admin_internal_net $VM_name | grep ' id ' | awk '{print$4}' )
VM_status $VM_id
floatingip_1=`create_fip $VM_id`
sleep 5
nova show $VM_id
ping $floatingip_1
ssh-keygen -R $floatingip_1
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user@$floatingip_1 hostname 2>&1

echo "Creating snapshot"
snapshot_id=$(openstack snapshot create --name $snapshot_name --force $volume_id_1 | grep ' id ' | awk '{print $4}')
snapshot_status $snapshot_id

echo "Create volume from snapshot"
volume_id_2=$(openstack volume create --snapshot $snapshot_id --size $volume_size --type $volume_type $volume2_name | grep ' id ' | awk '{print $4}')
volume_status $volume_id_2

clear_data
