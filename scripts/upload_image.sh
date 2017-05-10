#!/bin/bash -x

#wget https://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
#wget http://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
#http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
image_name=$1
image_link=$2

wget -O $image_name $image_link


openstack image create --disk-format qcow2 --min-ram 1500 --file $image_name $image_name

openstack image list | grep $image_name