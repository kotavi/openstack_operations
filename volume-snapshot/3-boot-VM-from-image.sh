#!/bin/bash -x


#launch VM1 from image
#check ping and ssh
#launch VM2 from image
#check ping and ssh
#delete VM2

#./3-boot-VM-from-image.sh -openrc=openrc -i=new_xenial -u=ubuntu -f=5

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

if [[ -n "$openrc_path" && -e $openrc_path ]] ; then
    source $openrc_path
else
    echo "Please provide correct path to openrc"
    exit 1
fi

clear_data(){
    [ -n "$floatingip_1" ] && [ -n "$VM_id_1" ] && nova floating-ip-disassociate $VM_id_1 $floatingip_1
    [ -n "$floatingip_2" ] && [ -n "$VM_id_2" ] && nova floating-ip-disassociate $VM_id_2 $floatingip_2
    [ -n "$floatingip_1" ] && nova floating-ip-delete $floatingip_1
    [ -n "$floatingip_2" ] && nova floating-ip-delete $floatingip_2
    [ -n "$VM_id_1" ] && nova delete $VM_id_1
    [ -n "$VM_id_2" ] && nova delete $VM_id_2
    sleep 5
    [ -n "$keypair_name_1" ] && openstack keypair delete $keypair_name_1
    [ -n "$keypair_name_2" ] && openstack keypair delete $keypair_name_2
}

random=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
VM1_name=$pattern"_"$random"_VM1"
VM2_name=$pattern"_"$random"_VM2"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')

keypair_name_1=`create_keypair`
VM_id_1=$(nova boot --image $image_name --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_1 --nic net-id=$admin_internal_net $VM1_name | grep ' id ' | awk '{print$4}' )
VM_status $VM_id_1
floatingip_1=`create_fip $VM_id_1`
sleep 5
nova show $VM_id_1
ping $floatingip_1
ssh-keygen -R $floatingip_1
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user@$floatingip_1 hostname 2>&1


keypair_name_2=`create_keypair`
VM_id_2=$(nova boot --image $image_name --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_2 --nic net-id=$admin_internal_net $VM2_name | grep ' id ' | awk '{print$4}' )
VM_status $VM_id_2
floatingip_2=`create_fip $VM_id_2`
sleep 5
nova show $VM_id_2
ping $floatingip_2
ssh-keygen -R $floatingip_2
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user@$floatingip_2 hostname 2>&1


clear_data