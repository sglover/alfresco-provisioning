#!/bin/bash

cd /data/alfresco

cp -R /tmp/yourkit/ /data/alfresco/yourkit

mkdir -p /data/alfresco/yourkit/snapshots
YOUR_KIT_OPTS="-agentpath:/data/alfresco/yourkit/yourkit/libyjpagent.so=onexit=snapshot,dir=/data/alfresco/yourkit/snapshots,probe_off=*,probe_on=com.yourkit.probes.builtin.Databases"
echo "JAVA_OPTS=\"$JAVA_OPTS $YOUR_KIT_OPTS\"" | sudo tee -a /home/ubuntu/.bashrc
export JAVA_OPTS="$JAVA_OPTS $YOUR_KIT_OPTS"
unzip -q /tmp/sync-dist.zip -d /tmp/alfresco-sync
mkdir -p /data/alfresco/alfresco-${ALF_VERSION}
useradd -m -s /bin/bash alfresco
useradd -m -s /bin/bash vagrant
chmod +x /tmp/alfresco-enterprise-${ALF_VERSION}-installer-linux-x64.bin
/tmp/alfresco-enterprise-${ALF_VERSION}-installer-linux-x64.bin --mode unattended --prefix /data/alfresco/alfresco-${ALF_VERSION} --baseunixservice_install_as_service 0 --alfresco_admin_password admin
chown -R alfresco:alfresco /data/alfresco/alfresco-${ALF_VERSION}
chmod +x /tmp/init.d/*
cp /tmp/init.d/* /etc/init.d
cp /tmp/cron.d/* /etc/cron.d
update-rc.d alfresco defaults
sed -i -e "s/alfresco-5.0/alfresco-${ALF_VERSION}/" /etc/init.d/alfresco
sed -i -e "3,9d" /data/alfresco/alfresco-${ALF_VERSION}/alfresco.sh
echo "host all all 10.0.0.0/8 trust" >> /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/pg_hba.conf
#echo "" >> /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
echo "listen_addresses='\"'*'\"'" >> /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
sed -i -e "s/#checkpoint_segments = 3/checkpoint_segments = 10/" /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf

cp /tmp/alfresco-sync/amps-repository/*.amp /data/alfresco/alfresco-${ALF_VERSION}/amps
/data/alfresco/alfresco-${ALF_VERSION}/java/bin/java -jar /data/alfresco/alfresco-${ALF_VERSION}/bin/alfresco-mmt.jar install /data/alfresco/alfresco-${ALF_VERSION}/amps /data/alfresco/alfresco-${ALF_VERSION}/tomcat/webapps/alfresco.war -directory
chown -R alfresco:alfresco /data/alfresco/alfresco-${ALF_VERSION}
echo "alfresco soft nofile 4096" >> /etc/security/limits.conf
echo "alfresco hard nofile 65536" >> /etc/security/limits.conf
mkdir -p /data/alfresco/temp
sudo chown alfresco:alfresco /data/alfresco/temp
sed -i "/JAVA ENV/a export CATALINA_TMPDIR=/data/alfresco/temp" /data/alfresco/alfresco-${ALF_VERSION}/scripts/setenv.sh
touch /data/alfresco/alfresco-${ALF_VERSION}/tomcat/bin/setenv.sh
echo "JAVA_OPTS=\"\$JAVA_OPTS $YOUR_KIT_OPTS\"" | sudo tee -a /data/alfresco/alfresco-${ALF_VERSION}/tomcat/bin/setenv.sh

mkdir -p /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension
echo "log4j.logger.org.alfresco.repo.events=DEBUG" > /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension/dev-log4j.properties
echo "log4j.logger.org.gytheio.messaging=DEBUG" >> /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension/dev-log4j.properties
echo "log4j.logger.org.alfresco.repo.sync=DEBUG" >> /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension/dev-log4j.properties

# DB connections
# 16GB
echo "kernel.shmmax=2147483648" >> /etc/sysctl.conf
echo "kernel.shmall=4194304" >> /etc/sysctl.conf
sed -i -e "s/max_connections = 100/max_connections = 505/" /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
sed -i -e "s/db.pool.max=40/db.pool.max=500/" /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco-global.properties
sed -i -e "s/#work_mem = 1MB/work_mem = 8MB/" /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
sed -i -e "s/shared_buffers = 128MB/shared_buffers = 5GB/" /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
sed -i -e "s/#temp_buffers = 8MB/temp_buffers = 8MB/" /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
sed -i -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/postgresql.conf
#echo "hostssl all             all             109.146.214.125/32      password" | sudo tee -a /data/alfresco/alfresco-${ALF_VERSION}/alf_data/postgresql/pg_hba.conf

echo "Copying license /tmp/alfresco-license.lic to /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension/license"
mkdir -p /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension/license
cp /tmp/alfresco-license.lic /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco/extension/license