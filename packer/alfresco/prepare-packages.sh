#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

#deb mirror://mirrors.ubuntu.com/mirrors.txt trusty main restricted universe multiverse
#deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-updates main restricted universe multiverse
#deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-backports main restricted universe multiverse
#deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-security main restricted universe multiverse
#deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-partner  main restricted universe multiverse

#            "sudo sed -i -e \"s@# deb http://extras.ubuntu.com/ubuntu trusty main@deb http://extras.ubuntu.com/ubuntu trusty main@\" /etc/apt/sources.list",
#            "sudo sed -i -e \"s@# deb http://archive.canonical.com/ubuntu trusty partner@deb http://archive.canonical.com/ubuntu trusty partner@\" /etc/apt/sources.list"

sudo rm -rf /var/lib/apt/lists

sudo apt-get -q -y update
#apt-get -q -y dist-ugprade