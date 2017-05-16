#!/bin/bash -x

#launch VM1 from image
#check ping and ssh
#echo "Hello" > file.dat
#create snapshot from VM
#launch VM2 from snapshot
#check ping and ssh
#cat file.dat
#delete VM1, VM2


#./boot_with_snapshot.sh -openrc=openrc -i=TestVM -u=cirros -f=2

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
    *)
    ;;
esac
done

clear_data(){
    [ -n "$floatingip_1" ] && [ -n "$VM_id_1" ] && nova floating-ip-disassociate $VM_id_1 $floatingip_1
    [ -n "$floatingip_2" ] && [ -n "$VM_id_2" ] && nova floating-ip-disassociate $VM_id_2 $floatingip_2
    [ -n "$floatingip_1" ] && nova floating-ip-delete $floatingip_1
    [ -n "$floatingip_2" ] && nova floating-ip-delete $floatingip_2
    [ -n "$VM_id_1" ] && nova delete $VM_id_1
    [ -n "$VM_id_2" ] && nova delete $VM_id_2
    [ -n "$snapshot_id" ] && openstack snapshot delete $snapshot_id
    [ -n "$keypair_name_1" ] && openstack keypair delete $keypair_name_1
    [ -n "$keypair_name_2" ] && openstack keypair delete $keypair_name_2
    [ -n "$new_volume_id" ] && openstack keypair delete $new_volume_id
}

if [[ -n "$openrc_path" && -e $openrc_path ]] ; then
    source $openrc_path
else
    echo "Please provide correct path to openrc"
    exit 1
fi

random=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
VM1_name=$pattern"_"$random"_VM1"
VM2_name=$pattern"_"$random"_VM2"
snapshot_name=$pattern"_"$random"_snapshot"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')

keypair_name_1=`create_keypair`
VM_id_1=$(nova boot --image $image_name --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_1 --nic net-id=$admin_internal_net $VM1_name | grep ' id ' | awk '{print$4}' )
VM_status $VM_id_1

floatingip_1=`create_fip $VM_id_1`
nova show $VM_id_1
ping $floatingip_1
ssh-keygen -R $floatingip_1
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user@$floatingip_1 'echo "hello" > text.dat | hostname' 2>&1

snapshot_id=$(nova image-create $VM_id_1 $snapshot_name | grep ' id ' | awk '{print $4}')
snapshot_status $snapshot_id

keypair_name_2=`create_keypair`
VM_id_2=$(nova boot --snapshot $snapshot_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_2 --nic net-id=$admin_internal_net $VM2_name | grep ' id ' | awk '{print$4}' )
VM_status $VM_id_2

floatingip_2=`create_fip $VM_id_2`
nova show $VM_id_2
ping $floatingip_2
ssh-keygen -R $floatingip_2
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user@$floatingip_2 'cat text.dat | hostname' 2>&1

new_volume_id=`get_volume_attached_id $VM2_name`

clear_data
