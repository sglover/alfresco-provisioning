#!/bin/bash

echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" | sudo tee -a /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
add-apt-repository -y ppa:webupd8team/java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections

# stupid loop to get around ubuntu package mirror problems
for attempt in 1 2 3; do
  echo "Trying to install, attempt $attempt"
  apt-get update -yq --fix-missing
  apt-get -q -y install unzip oracle-java8-installer postgresql-9.4 postgresql-client htop sysstat
done

ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java

mkdir -p /data/alfresco/postgres
chown -R postgres:postgres /data/alfresco/postgres

echo "kernel.shmmax=2147483648" >> /etc/sysctl.conf
echo "kernel.shmall=4194304" >> /etc/sysctl.conf

echo "Stopping Postgres"
#/etc/init.d/postgresql restart
service postgresql stop
echo "Done"