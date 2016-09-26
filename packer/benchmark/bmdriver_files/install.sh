#!/bin/bash

cd /data/alfresco

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
add-apt-repository -y ppa:webupd8team/java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get update
apt-get install -y build-essential dkms libreadline6-dev libyaml-dev curl wget git-core gcc g++ make autoconf python-software-properties screen puppet puppetmaster htop unzip oracle-java8-installer
ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java
apt-get install -y tomcat8 tomcat8-admin htop

mkdir -p /tmp/tomcat/DesktopSyncBenchmark
mkdir -p /tmp/tomcat/bm/cached-files

chown -R tomcat8:tomcat8 /tmp/tomcat
chown -R tomcat8:tomcat8 /var/lib/tomcat8
chown -R tomcat8:tomcat8 /usr/share/tomcat8

cp /tmp/tomcat-users.xml /etc/tomcat8/tomcat-users.xml
sed -i 's@<Connector port=\"8080\" protocol=\"HTTP/1.1\"@<Connector port=\"9080\" protocol=\"HTTP/1.1\"@' /etc/tomcat8/server.xml

echo "JAVA_OPTS=\"\$JAVA_OPTS -Xms256M -Xmx4G -agentpath:/data/alfresco/yourkit/linux-x86-64/libyjpagent.so=onexit=snapshot,dir=/data/alfresco/yourkit/snapshots,probe_off=* -Djava.library.path=/data/alfresco/jnotify/64-bit\ Linux -server\"" | sudo tee -a /usr/share/tomcat8/bin/setenv.sh
