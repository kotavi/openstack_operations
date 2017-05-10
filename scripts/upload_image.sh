#!/bin/bash -x

#https://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
#http://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
#http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
#http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
#http://cdimage.debian.org/cdimage/openstack/current-8/debian-8-openstack-amd64.qcow2

image_name=$1
image_link=$2

wget -O $image_name $image_link


openstack image create --disk-format qcow2 --min-ram 1500 --file $image_name $image_name

openstack image list | grep $image_name