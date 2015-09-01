#!/bin/bash

# Setup sudo to allow no-password sudo for "admin"
groupadd -r admin
usermod -a -G admin ubuntu
cp /etc/sudoers /etc/sudoers.orig
sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=admin' /etc/sudoers
sed -i -e 's/%admin ALL=(ALL) ALL/%admin ALL=(ALL) NOPASSWD:ALL/g' /etc/sudoers
