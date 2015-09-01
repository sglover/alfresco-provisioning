#!/bin/bash

mkdir /tmp/vboxguest
mount -t iso9660 -o loop /home/ubuntu/VBoxGuestAdditions.iso /tmp/vboxguest
/tmp/vboxguest/VBoxLinuxAdditions.run
umount /tmp/vboxguest
rmdir /tmp/vboxguest
rm /home/ubuntu/VBoxGuestAdditions.iso