#!/bin/bash -x
#!/bin/bash -x
# for Linux OS only

#create volume from image
#launch VM from volume
#create snapshot from volume
#create keypair
#launch VM from snapshot with keypair  and get hostname of VM


#./launch_VM_from_volumesnapshot_attached_to_VM.sh -openrc=openrc -i=TestVM -u=cirros -f=2 -v_s=2 -v_t=netapp

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
VM1_name=$random"_VM1"
VM2_name=$random"_VM2"
volume_name=$random"_volume"
snapshot_name=$random"_snapshot"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')

clear_data(){
        nova floating-ip-disassociate $VM_id $floatingip
        nova floating-ip-delete $floatingip
        nova floating-ip-list
        nova delete $VM_id
        nova delete $VM_temp_id
        nova list
        openstack keypair delete $keypair_name
        openstack snapshot delete $snapshot_id
        openstack volume delete $volume_id
        openstack volume delete $new_volume_id

}

volume_id=$(openstack volume create --image $image_name --size $volume_size --type $volume_type $volume_name | grep ' id ' | awk '{print $4}')
for i in $(seq 1 $active_check_tries)
do
  result="$(openstack volume show $volume_id 2>&1)"
  volume_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$volume_status" == "available" ] && break
  [ "$volume_status" == "error" ] && echo "volume is in error state" && clear_data && break
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$volume_status" == "available" ]
then
  echo "timeout waiting for volume to become available" "$result"
  exit
fi

VM_temp_id=$(nova boot --boot-volume $volume_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --nic net-id=$admin_internal_net $VM1_name | grep ' id ' | awk '{print$4}' )
for i in $(seq 1 $active_check_tries)
do
  result="$(nova show $VM_temp_id 2>&1)"
  VM1_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$VM1_status" == "ACTIVE" ] && break
  [ "$VM1_status" == "ERROR" ] && echo "VM is in error state" && clear_data && break
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$VM1_status" == "ACTIVE" ]
then
  echo "timeout waiting for second VM to become active" "$result"
  exit
fi

snapshot_id=$(openstack snapshot create --name $snapshot_name --force $volume_id | grep ' id ' | awk '{print $4}')
for i in $(seq 1 $active_check_tries)
do
  result="$(openstack snapshot show $snapshot_id 2>&1)"
  snapshot_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$snapshot_status" == "available" ] && break
  [ "$snapshot_status" == "error" ] && echo "snapshot is in error state" && clear_data && break
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$snapshot_status" == "available" ]
then
  echo "timeout waiting for snapshot to become available" "$result"
  exit
fi

# create keypair
keypair_name=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
result="$(nova keypair-add "$keypair_name" >"temporary-keypair" 2>&1)"
chmod 600 "temporary-keypair"
sleep 5

VM_id=$(nova boot --snapshot $snapshot_id --flavor $flavor_id --availability-zone nova --security-groups $security_group_id --key-name $keypair_name --nic net-id=$admin_internal_net $VM2_name | grep ' id ' | awk '{print$4}' )
for i in $(seq 1 $active_check_tries)
do
  result="$(nova show $VM_id 2>&1)"
  VM_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$VM_status" == "ACTIVE" ] && break
  [ "$VM_status" == "ERROR" ] && echo "VM is in error state" && clear_data && break
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$VM_status" == "ACTIVE" ]
then
  echo "timeout waiting for second VM to become active" "$result"
  exit
fi

new_volume=$(nova show $VM_id | grep "os-extended-volumes:volumes_attached")
new_volume_id=$(echo "$new_volume" | awk -F'"' '{print $4}')

internalip=$(nova show $VM_id | grep admin_internal_net | awk '{print$5}')

floatingip=$(neutron floatingip-create $floating_net | grep ' floating_ip_address ' | awk '{print$4}' )

nova floating-ip-associate --fixed-address $internalip $VM_id $floatingip
sleep 10

nova show $VM_id

ping $floatingip
ssh_to_VM() {
        sleep 5
        ssh-keygen -R $floatingip
        ssh -i "temporary-keypair" -o StrictHostKeyChecking=no $user@$floatingip hostname 2>&1
}

ssh_to_VM
clear_data