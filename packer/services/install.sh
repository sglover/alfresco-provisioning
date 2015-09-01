#!/bin/bash

cd /data/alfresco

useradd -m -s /bin/bash vagrant
useradd -m -s /bin/bash activemq

mkdir -p /data/alfresco/yourkit/snapshots
mkdir -p /data/alfresco/temp
sudo chown activemq:activemq /data/alfresco

export DEBIAN_FRONTEND=noninteractive
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
add-apt-repository -y ppa:webupd8team/java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get -y update
apt-get install -y unzip build-essential dkms zlib1g-dev libssl-dev libreadline6-dev libyaml-dev curl wget git-core gcc g++ make autoconf python-software-properties screen puppet puppetmaster htop unzip oracle-java8-installer
ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java
cp -R /tmp/yourkit/ /data/alfresco/yourkit

#YOUR_KIT_OPTS="-agentpath:/data/alfresco/yourkit/yourkit/libyjpagent.so=onexit=snapshot,dir=/data/alfresco/yourkit/snapshots,probe_off=*,probe_on=com.yourkit.probes.builtin.Databases"
#echo "JAVA_OPTS=\"$JAVA_OPTS $YOUR_KIT_OPTS\"" | sudo tee -a /home/ubuntu/.bashrc
#export JAVA_OPTS="$JAVA_OPTS $YOUR_KIT_OPTS -XX:MaxPermSize=1024m -Xms256M -Xmx4G"

echo "alfresco soft nofile 4096" >> /etc/security/limits.conf
echo "alfresco hard nofile 65536" >> /etc/security/limits.conf

tar zxf /tmp/activemq.tar.gz -C /data/alfresco
mv /data/alfresco/apache-activemq-5.11.1 /data/alfresco/activemq
chmod a+x /data/alfresco/activemq
chown -R activemq:activemq /data/alfresco/activemq

echo "" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb=org.apache.log4j.RollingFileAppender" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb.file=\${activemq.base}/data/kahadb.log" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb.maxFileSize=1024KB" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb.maxBackupIndex=5" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb.append=true" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb.layout=org.apache.log4j.PatternLayout" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties
echo "log4j.appender.kahadb.layout.ConversionPattern=%d [%-15.15t] %-5p %-30.30c{1} - %m%n" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties 
echo "log4j.logger.org.apache.activemq.store.kahadb.MessageDatabase=TRACE, kahadb" | sudo tee -a /data/alfresco/activemq/conf/log4j.properties

chmod +x /tmp/init.d/*
cp /tmp/init.d/* /etc/init.d
update-rc.d activemq defaults