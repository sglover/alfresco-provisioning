#!/bin/bash

# add DataStax repo for APT
echo "deb http://debian.datastax.com/community stable main" | sudo tee -a /etc/apt/sources.list.d/datastax.community.list
wget -q -O - http://debian.datastax.com/debian/repo_key | sudo apt-key add -
apt-get update

# install OpsCenter and a few base packages
apt-get install vim curl zip unzip git python-pip opscenter -y

# start OpsCenter
service opscenterd start