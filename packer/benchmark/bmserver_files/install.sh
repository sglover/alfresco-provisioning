#!/bin/bash

cd /data/alfresco

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/3.0 multiverse" | sudo tee -a /etc/apt/sources.list.d/mongodb-org-3.0.list
add-apt-repository -y ppa:webupd8team/java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get update
apt-get install -y build-essential dkms zlib1g-dev libssl-dev libreadline6-dev libyaml-dev curl wget git-core gcc g++ make autoconf python-software-properties screen puppet puppetmaster htop unzip mongodb-org oracle-java8-installer
ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java
apt-get install -y tomcat7 tomcat7-admin htop
cp /tmp/tomcat-users.xml /etc/tomcat7/tomcat-users.xml
sed -i 's@<Connector port=\"8080\" protocol=\"HTTP/1.1\"@<Connector port=\"9080\" protocol=\"HTTP/1.1\"@' /etc/tomcat7/server.xml
cp /tmp/setenv.xml /usr/share/tomcat7/bin/setenv.sh
cp /tmp/alfresco-benchmark-server.war /var/lib/tomcat7/webapps/alfresco-benchmark-server.war
mkdir -p /data/mongo/data
mkdir -p /data/mongo/logs
chown -R mongodb:mongodb /data/mongo

sed -i 's@bindIp: 127.0.0.1@#bindIp: 127.0.0.1@' /etc/mongod.conf
sed -i 's@dbPath: /var/lib/mongodb@dbPath: /data/mongo/data@' /etc/mongod.conf
sed -i 's@path: /var/log/mongodb/mongod.log@path: /data/mongo/logs/mongod.log@' /etc/mongod.conf