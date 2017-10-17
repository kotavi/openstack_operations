#!/bin/bash -x


floating_net=floating_net
internal_net=fixed
active_check_tries=20
active_check_delay=10
pattern=tkorchak

function volume_status {
    # $1 - volume id
    for i in $(seq 1 $active_check_tries)
    do
        result="$(openstack volume show $1 2>&1)"
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
    exit_ifnot_available $volume_status $result
}

function snapshot_status {
    # $1 - snapshot id
    echo "Check snapshot status"
    for i in $(seq 1 $active_check_tries)
    do
        result="$(openstack snapshot show $1 2>&1)"
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
    exit_ifnot_available $snapshot_status $result
}

function VM_status {
    # $1 - VM id
    for i in $(seq 1 $active_check_tries)
    do
        result="$(nova show $1 2>&1)"
        VM_status=$(echo "$result" | grep "^| *status" | awk '{printf $4}')
        [ "$VM_status" == "ACTIVE" ] && break
        if [ "$VM_status" == "ERROR" ]
        then
            echo "VM is in error state"
            clear_data
            exit 1
        fi
        [ $i -lt $active_check_tries ] && sleep $active_check_delay
    done
    exit_ifnot_active $VM_status $result
}

function exit_ifnot_available {
    # $1 - status
    # $2 - result of show command
    if ! [ "$1" == "available" ]
    then
        echo "timeout waiting for object to become available" "$2"
        clear_data
        exit 1
    fi
}

function exit_ifnot_active {
    # $1 - status
    # $2 - result of show command
    if ! [ "$1" == "ACTIVE" ]
    then
        echo "timeout waiting for object to become available" "$2"
        clear_data
        exit 1
    fi
}

function create_keypair {
    keypair_name=$pattern"_"$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
    result="$(nova keypair-add "$keypair_name" >"temporary-keypair" 2>&1)"
    chmod 600 "temporary-keypair"
    echo $keypair_name >&1
}

create_fip(){
    # $1 - VM id
    internalip=$(nova show $1 | grep $internal_net | awk '{print$5}')
    floatingip=$(neutron floatingip-create $floating_net | grep ' floating_ip_address ' | awk '{print$4}' )
    nova floating-ip-associate --fixed-address $internalip $1 $floatingip
    echo $floatingip >&1
}

function get_volume_attached_id {
    # $1 - name of VM
    new_volume=$(nova show $1 | grep "os-extended-volumes:volumes_attached")
    new_volume_id=$(echo "$new_volume" | awk -F'"' '{print $4}')
    echo "$new_volume_id" >&1
}