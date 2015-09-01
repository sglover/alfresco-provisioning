#!/bin/bash

cd /data/alfresco

export SERVICES_IP=`java -jar service-sync-bundle-1.1-SNAPSHOT.jar -hostname $1 $2 $8`
echo "Services hostname is $SERVICES_IP"

export BM_SERVER_IP=`java -jar service-sync-bundle-1.1-SNAPSHOT.jar -hostname $1 $2 $3`
echo "BM server hostname is $BM_SERVER_IP"

export BM_DRIVER_IP=`java -jar service-sync-bundle-1.1-SNAPSHOT.jar -hostname $1 $2 $4`
echo "BM driver hostname is $BM_DRIVER_IP"

export SYNC_IP=`java -jar service-sync-bundle-1.1-SNAPSHOT.jar -hostname $1 $2 $5`
echo "Sync service hostname is $SYNC_IP"

export ALFRESCO_IP=`java -jar service-sync-bundle-1.1-SNAPSHOT.jar -hostname $1 $2 $6`
echo "Alfresco hostname is $ALFRESCO_IP"

mkdir -p /tmp/tomcat7/DesktopSyncBenchmark
mkdir -p /tmp/tomcat7/bm/cached-files
chown -R tomcat7:tomcat7 /tmp/tomcat7
chown -R tomcat7:tomcat7 /var/lib/tomcat7
#chown -R tomcat7:tomcat7 /home/ubuntu/snapshots

echo "JAVA_OPTS=\"\$JAVA_OPTS -Dmirror.name=$7 -Dmessaging.broker.url=tcp://${SERVICES_IP}:61616 -DalfrescoHost=${ALFRESCO_IP} -Dmongo.config.host=$BM_SERVER_IP\"" | sudo tee -a /usr/share/tomcat7/bin/setenv.sh
echo "CATALINA_TMPDIR=\"/tmp/tomcat7\"" | sudo tee -a /usr/share/tomcat7/bin/setenv.sh
/etc/init.d/tomcat7 restart

echo "Uploading releases and creating tests, if necessary"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-ent-signup-2.1.war EntSignup EntSignup
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-cmis-1.0.war CMIS CMIS
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-dataload-2.4.war DataLoad DataLoad
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-device-sync-1.0-SNAPSHOT.war DeviceSync DeviceSync

if [ $9 == "yes" ]; then
    java -jar service-sync-bundle-1.1-SNAPSHOT.jar -deployWAR ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-repomirror-app.war
fi

echo "Updating mirror names"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "users.collectionName" "mirrors.$7.users"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP EntSignup "users.collectionName" "mirrors.$7.users"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "users.collectionName" "mirrors.$7.users"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mirror.sites" "mirrors.$7.sites"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mirror.siteMembers" "mirrors.$7.siteMembers"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DataLoad "mirror.users" "mirrors.$7.users"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DataLoad "mirror.sites" "mirrors.$7.sites"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DataLoad "mirror.siteMembers" "mirrors.$7.siteMembers"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DataLoad "mirror.fileFolders" "mirrors.$7.fileFolders"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mirror.subscribers" "mirrors.$7.subscribers"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mirror.subscriptions" "mirrors.$7.subscriptions"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mirror.syncs" "mirrors.$7.syncs"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mirror.nodes" "mirrors.$7.nodes"

echo "Updating alfresco server name"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "alfresco.server" ${ALFRESCO_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP EntSignup "alfresco.server" ${ALFRESCO_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DataLoad "alfresco.server" ${ALFRESCO_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "cmis.host" ${ALFRESCO_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "cmis.port" 8080

echo "Updating sync server name"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "subs.server" ${SYNC_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "sync.server" ${SYNC_IP}

echo "Updating ActiveMQ hostname"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "activemq.host" ${SERVICES_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "activemq.host" ${SERVICES_IP}

echo "Updating Mongo hostname"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DeviceSync "mongo.test.host" ${BM_SERVER_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP EntSignup "mongo.test.host" ${BM_SERVER_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP DataLoad "mongo.test.host" ${BM_SERVER_IP}
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "mongo.test.host" ${BM_SERVER_IP}

# CMIS
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "cmis.bindingType" "browser"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "cmis.bindingUrl" "http://${ALFRESCO_IP}:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser"
java -jar service-sync-bundle-1.1-SNAPSHOT.jar -setBMProperty $BM_SERVER_IP CMIS "cmis.repositoryId" "-default-"