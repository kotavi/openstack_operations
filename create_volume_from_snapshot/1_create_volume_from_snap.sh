#!/bin/bash -x


#create volume from image
#create snapshot from volume
#create volume from snapshot


#./1_create_volume_from_snap.sh -openrc=openrc -i=TestVM -f=2 -v_s=2 -v_t=netapp

floating_net=admin_floating_net
active_check_tries=20
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
        openstack snapshot delete $snapshot_id
        openstack volume delete $volume_id_1
        openstack volume delete $volume_id_2
}

random=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
volume_name=$random"_volume"
snapshot_name=$random"_snapshot"

security_group_id=$(nova secgroup-list | grep default | awk '{print$2}')
admin_internal_net=$(neutron net-list | grep admin_internal_net | awk '{print$2}')


volume_id_1=$(openstack volume create --image $image_name --size $volume_size --type $volume_type $volume_name | grep ' id ' | awk '{print $4}')
for i in $(seq 1 $active_check_tries)
do
  result="$(openstack volume show $volume_id_1 2>&1)"
  volume_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$volume_status" == "available" ] && break
  if [ "$volume_status" == "error" ]
  then
    echo "volume is in error state"
    clear_data
    exit 1
  fi
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$volume_status" == "available" ]
then
  echo "timeout waiting for volume to become available" "$result"
  clear_data
  exit
fi

snapshot_id=$(openstack snapshot create --name $snapshot_name --force $volume_id_1 | grep ' id ' | awk '{print $4}')
for i in $(seq 1 $active_check_tries)
do
  result="$(openstack snapshot show $snapshot_id 2>&1)"
  snapshot_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$snapshot_status" == "available" ] && break
  if [ "$snapshot_status" == "error" ]
  then
    echo "snapshot is in error state"
    clear_data
    exit 1
  fi
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$snapshot_status" == "available" ]
then
  echo "timeout waiting for snapshot to become available" "$result"
  clear_data
  exit
fi

echo "Create volume from snapshot"
volume_id_2=$(openstack volume create --snapshot $snapshot_id --size $volume_size --type $volume_type $volume_name | grep ' id ' | awk '{print $4}')
for i in $(seq 1 $active_check_tries)
do
  result="$(openstack volume show $volume_id_2 2>&1)"
  volume_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
  [ "$volume_status" == "available" ] && break
  if [ "$volume_status" == "error" ]
  then
    echo "volume is in error state"
    clear_data
    exit 1
  fi
  [ $i -lt $active_check_tries ] && sleep $active_check_delay
done
if ! [ "$volume_status" == "available" ]
then
  echo "timeout waiting for volume to become available" "$result"
  clear_data
  exit
fi

clear_data