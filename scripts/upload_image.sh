#!/bin/bash -x

wget https://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img

openstack image create --disk-format qcow2 --min-ram 1500 --file ubuntu-16.04-server-cloudimg-amd64-disk1.img xenial16.04

openstack image list | grep xenial16.04