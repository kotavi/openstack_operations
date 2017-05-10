#!/bin/bash -x

#create volume from image
#launch VM from volume
# check ssh


#./boot_from_volume_ssh.sh -openrc=openrc -i=new_xenial -u=ubuntu -f=2 -v_s=2 -v_t=netapp -p tkorchak


floating_net=admin_floating_net
active_check_tries=10
active_check_delay=10

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
     -p=*|--pattern=*)
    pattern="${i#*=}"
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

random=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
VM1_name=$pattern"_"$random"_VM1"
VM2_name=$pattern"_"$random"_VM2"
volume_name=$pattern"_"$random"_volume"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')

volume_id=$(openstack volume create --image $image_name --size $volume_size --type $volume_type $volume_name | grep ' id ' | awk '{print $4}')
for i in $(seq 1 $active_check_tries)
do
  result="$(openstack volume show $volume_id 2>&1)"
  volume_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$volume_status" == "available" ] && break
  if [ "$volume_status" == "error" ]
  then
    echo "volume is in error state"
    exit 1
  fi
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$volume_status" == "available" ]
then
  echo "timeout waiting for volume to become available" "$result"
  exit
fi

# create keypair
keypair_name_1=$pattern"_"$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
result="$(nova keypair-add "$keypair_name_1" >"temporary-keypair" 2>&1)"
chmod 600 "temporary-keypair"
sleep 5

VM_id_1=$(nova boot --boot-volume $volume_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_1 --nic net-id=$admin_internal_net $VM1_name | grep ' id ' | awk '{print$4}' )
for i in $(seq 1 $active_check_tries)
do
  result="$(nova show $VM_id_1 2>&1)"
  VM1_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$VM1_status" == "ACTIVE" ] && break
  if [ "$VM1_status" == "ERROR" ]
  then
    echo "VM is in error state"
    clear_data
    exit 1
  fi
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$VM1_status" == "ACTIVE" ]
then
  echo "timeout waiting for second VM to become active" "$result"
  clear_data
  exit
fi

#ssh to the first VM
internalip=$(nova show $VM_id_1 | grep admin_internal_net | awk '{print$5}')
floatingip_1=$(neutron floatingip-create $floating_net | grep ' floating_ip_address ' | awk '{print$4}' )
nova floating-ip-associate --fixed-address $internalip $VM_id_1 $floatingip_1
sleep 5
nova show $VM_id_1
ping $floatingip_1
ssh-keygen -R $floatingip_1
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no $user@$floatingip_1 hostname 2>&1

echo "Removing first VM"
nova floating-ip-disassociate $VM_id_1 $floatingip_1
nova delete $VM_id_1
nova floating-ip-delete $floatingip_1
openstack keypair delete $keypair_name_1


# create keypair
keypair_name_2=$pattern"_"$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
result="$(nova keypair-add "$keypair_name_2" >"temporary-keypair" 2>&1)"
chmod 600 "temporary-keypair"
sleep 5

VM_id_2=$(nova boot --boot-volume $volume_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name_2 --nic net-id=$admin_internal_net $VM2_name | grep ' id ' | awk '{print$4}' )
for i in $(seq 1 $active_check_tries)
do
  result="$(nova show $VM_id_2 2>&1)"
  VM2_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$VM2_status" == "ACTIVE" ] && break
  if [ "$VM2_status" == "ERROR" ]
  then
    echo "VM is in error state"
    clear_data
    exit 1
  fi
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$VM1_status" == "ACTIVE" ]
then
  echo "timeout waiting for second VM to become active" "$result"
  clear_data
  exit
fi


#ssh to the second VM
internalip=$(nova show $VM_id_2 | grep admin_internal_net | awk '{print$5}')
floatingip_2=$(neutron floatingip-create $floating_net | grep ' floating_ip_address ' | awk '{print$4}' )
nova floating-ip-associate --fixed-address $internalip $VM_id_2 $floatingip_2
sleep 10
nova show $VM_id_2
ping $floatingip_2
ssh-keygen -R $floatingip_2
ssh -i "temporary-keypair" -o StrictHostKeyChecking=no ConnectTimeout=10  $user@$floatingip_2 hostname 2>&1
