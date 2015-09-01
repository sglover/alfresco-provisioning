#!/bin/bash

cd /data/alfresco

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
add-apt-repository -y ppa:webupd8team/java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get update
apt-get install -y build-essential dkms zlib1g-dev libssl-dev libreadline6-dev libyaml-dev curl wget git-core gcc g++ make autoconf python-software-properties screen puppet puppetmaster htop unzip oracle-java8-installer
ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java
apt-get install -y tomcat7 tomcat7-admin htop

mkdir -p /tmp/tomcat7/DesktopSyncBenchmark
mkdir -p /tmp/tomcat7/bm/cached-files

unzip /data/alfresco/jnotify/jnotify-lib-0.94.zip -d /data/alfresco/jnotify

chown -R tomcat7:tomcat7 /tmp/tomcat7
chown -R tomcat7:tomcat7 /var/lib/tomcat7
chown -R tomcat7:tomcat7 /usr/share/tomcat7

cp /tmp/tomcat-users.xml /etc/tomcat7/tomcat-users.xml
sed -i 's@<Connector port=\"8080\" protocol=\"HTTP/1.1\"@<Connector port=\"9080\" protocol=\"HTTP/1.1\"@' /etc/tomcat7/server.xml

echo "JAVA_OPTS=\"\$JAVA_OPTS -Xms256M -Xmx4G -agentpath:/data/alfresco/yourkit/linux-x86-64/libyjpagent.so=onexit=snapshot,dir=/data/alfresco/yourkit/snapshots,probe_off=* -Djava.library.path=/data/alfresco/jnotify/64-bit\ Linux -server\"" | sudo tee -a /usr/share/tomcat7/bin/setenv.sh
