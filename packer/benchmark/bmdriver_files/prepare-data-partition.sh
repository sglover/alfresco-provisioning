#!/bin/bash

mkfs -t ext4 /dev/xvdf
mkdir /data
echo '/dev/xvdf       /data   ext4    defaults,nofail        0       2' | sudo tee -a /etc/fstab
mount /data