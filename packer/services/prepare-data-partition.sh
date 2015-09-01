#!/bin/bash

sudo mkfs -t ext4 /dev/xvdb
sudo mkdir /data
sudo bash -c "echo '/dev/xvdb       /data   ext4    defaults,nofail,nobootwait        0       2' > /etc/fstab"
sudo mount -a