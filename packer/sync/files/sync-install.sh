#!/bin/bash

YOUR_KIT_OPTS="-agentpath:/data/alfresco/yourkit/libyjpagent.so=onexit=snapshot,dir=/data/alfresco/yourkit/snapshots,probe_off=*,probe_on=com.yourkit.probes.builtin.Databases"

cd /data/alfresco

cp -R /tmp/yourkit/ /data/alfresco/yourkit

# Create some users

useradd -m -s /bin/bash activemq
useradd -m -s /bin/bash vagrant
useradd -m -s /bin/bash desktop_sync

# Unzip the sync distribution

unzip -q /tmp/sync-dist.zip -d /tmp
mv /tmp/sync /data/alfresco/alfresco-sync

# Create directories with correct permissions

mkdir /data/alfresco/alfresco-sync/tmp
mkdir -p /data/alfresco/yourkit/snapshots
chmod a+x /data/alfresco/alfresco-sync
chown -R desktop_sync:desktop_sync /data/alfresco/alfresco-sync
chown -R desktop_sync:desktop_sync /data/alfresco/yourkit

# Setup startup scripts

chmod +x /tmp/init.d/*
cp /tmp/init.d/* /etc/init.d
update-rc.d alfresco-sync defaults

# Kernel limits

echo "alfresco soft nofile 4096" >> /etc/security/limits.conf
echo "alfresco hard nofile 65536" >> /etc/security/limits.conf

# Install ActiveMQ

tar zxf /tmp/activemq.tar.gz -C /data/alfresco
mv /data/alfresco/apache-activemq-5.11.2 /data/alfresco/activemq
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

curl https://jdbc.postgresql.org/download/postgresql-9.4.1211.jre7.jar -o /data/alfresco/alfresco-sync/service-sync/postgresql.jar

# sysstat
sed -i -e "s/ENABLED=\"false\"/ENABLED=\"true\"/" /etc/default/sysstat
sed -i -e "s#5-55/10#*/1#" /etc/cron.d/sysstat
