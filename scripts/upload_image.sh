#!/bin/bash -x

#wget https://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
#wget http://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2


openstack image create --disk-format qcow2 --min-ram 1500 --file ubuntu-16.04-server-cloudimg-amd64-disk1.img xenial16.04

openstack image list | grep xenial16.04