#!/bin/bash

JARNAME="alfresco-provisioning-1.0-SNAPSHOT.jar"

ACTIVEMQ_BROKER_HOST_TYPE=${11}

echo "ACTIVEMQ_BROKER_HOST_TYPE=$ACTIVEMQ_BROKER_HOST_TYPE"

cd /data/alfresco

export SERVICES_IP=`java -jar $JARNAME -hostname $1 $2 $9`
echo "Services hostname is $SERVICES_IP"

export BM_SERVER_IP=`java -jar $JARNAME -hostname $1 $2 $3`
echo "BM server hostname is $BM_SERVER_IP"

export BM_DRIVER_IP=`java -jar $JARNAME -hostname $1 $2 $4`
echo "BM driver hostname is $BM_DRIVER_IP"

export SYNC_IP=`java -jar $JARNAME -hostname $1 $2 $5`
echo "Sync service hostname is $SYNC_IP"

export ALFRESCO_IP=`java -jar $JARNAME -hostname $1 $2 $6`
echo "Alfresco hostname is $ALFRESCO_IP"

export REPO2_IP=`java -jar $JARNAME -pip $1 $2 $7`
echo "Repo2 hostname is $REPO2_IP"

export MIRROR_NAME=$8
echo "Mirror name is $MIRROR_NAME"

mkdir -p /tmp/tomcat8/DesktopSyncBenchmark
mkdir -p /tmp/tomcat8/bm/cached-files
chown -R tomcat8:tomcat8 /tmp/tomcat8
chown -R tomcat8:tomcat8 /var/lib/tomcat8
#chown -R tomcat8:tomcat8 /home/ubuntu/snapshots

if [[ $ACTIVEMQ_BROKER_HOST_TYPE == "services" ]]; then
    MESSAGING_IP=$SERVICES_IP
    echo "Services host messaging - IP $MESSAGING_IP"
elif [[ $ACTIVEMQ_BROKER_HOST_TYPE == "sync" ]]; then
    MESSAGING_IP=$SYNC_IP
    echo "Sync host messaging - IP $SYNC_IP"
else
    echo "Invalid messaging host type (expected services or sync)"
    exit 1
fi

if [[ -z "$MESSAGING_IP" ]]; then
    BROKER_URL=""
else
    BROKER_URL="-Dmessaging.broker.url=failover\:\(tcp\:\/\/${MESSAGING_IP}\:61616\?connectionTimeout=5000\)\?timeout=500\&maxReconnectAttempts=5\&maxReconnectDelay=500"
fi

if [[ -z "$ALFRESCO_IP" ]]; then
    ALFRESCO_HOST=""
else
    ALFRESCO_HOST="-DalfrescoHost=${ALFRESCO_IP}"
fi

echo "Set ActiveMQ broker URL to $BROKER_URL"
echo "JAVA_OPTS=\"\$JAVA_OPTS -Dmirror.name=${MIRROR_NAME} $BROKER_URL $ALFRESCO_HOST -Dmongo.config.host=$BM_SERVER_IP"\" | sudo tee /usr/share/tomcat8/bin/setenv.sh
echo "CATALINA_TMPDIR=\"/tmp/tomcat8\"" | sudo tee -a /usr/share/tomcat8/bin/setenv.sh
echo "CATALINA_OPTS=\" -Xmx3096M\" " | sudo tee -a /usr/share/tomcat8/bin/setenv.sh
/etc/init.d/tomcat8 restart

echo "Uploading releases and creating tests, if necessary"
java -jar $JARNAME -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-ent-signup-2.1.war EntSignup EntSignup
java -jar $JARNAME -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-cmis-1.0.war CMIS CMIS
java -jar $JARNAME -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-dataload-2.4.war DataLoad DataLoad
java -jar $JARNAME -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-tests-device-sync-1.0-SNAPSHOT.war DeviceSync DeviceSync
java -jar $JARNAME -deployTestWAR ${BM_SERVER_IP} 9080 ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-benchmark-repo2-1.0-SNAPSHOT.war Repo2 Repo2

if [ $10 == "yes" ]; then
    java -jar $JARNAME -deployWAR ${BM_DRIVER_IP} 9080 admin admin /data/alfresco/alfresco-repomirror-app.war
fi

echo "Updating mirror names"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "users.collectionName" "mirrors.${MIRROR_NAME}.users"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP EntSignup "users.collectionName" "mirrors.${MIRROR_NAME}.users"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "users.collectionName" "mirrors.${MIRROR_NAME}.users"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "mirror.sites" "mirrors.${MIRROR_NAME}.sites"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "mirror.siteMembers" "mirrors.${MIRROR_NAME}.siteMembers"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DataLoad "mirror.users" "mirrors.${MIRROR_NAME}.users"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DataLoad "mirror.sites" "mirrors.${MIRROR_NAME}.sites"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DataLoad "mirror.siteMembers" "mirrors.${MIRROR_NAME}.siteMembers"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DataLoad "mirror.fileFolders" "mirrors.${MIRROR_NAME}.fileFolders"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "mirror.subscribers" "mirrors.${MIRROR_NAME}.subscribers"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "mirror.subscriptions" "mirrors.${MIRROR_NAME}.subscriptions"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "mirror.syncs" "mirrors.${MIRROR_NAME}.syncs"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP Repo2 "mirror.nodes" "mirrors.${MIRROR_NAME}.nodes2"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP Repo2 "mirror.auths" "mirrors.${MIRROR_NAME}.auths2"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP Repo2 "mirror.assocs" "mirrors.${MIRROR_NAME}.assoc2"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP Repo2 "mirror.users" "mirrors.${MIRROR_NAME}.users2"

echo "Updating alfresco server name"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "alfresco.server" ${ALFRESCO_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP EntSignup "alfresco.server" ${ALFRESCO_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DataLoad "alfresco.server" ${ALFRESCO_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "cmis.host" ${ALFRESCO_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "cmis.port" 8080

java -jar $JARNAME -setBMProperty $BM_SERVER_IP Repo2 "repo2.server" ${REPO2_IP}

echo "Updating sync server name"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "sync.server" ${SYNC_IP}

echo "Updating ActiveMQ hostname"
#java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "activemq.host" ${SERVICES_IP}
#java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "activemq.host" ${SERVICES_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "activemq.host" ${MESSAGING_IP}
#java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "activemq.host" ${MESSAGING_IP}

echo "Updating Mongo hostname"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DeviceSync "mongo.test.host" ${BM_SERVER_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP EntSignup "mongo.test.host" ${BM_SERVER_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP DataLoad "mongo.test.host" ${BM_SERVER_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "mongo.test.host" ${BM_SERVER_IP}
java -jar $JARNAME -setBMProperty $BM_SERVER_IP Repo2 "mongo.test.host" ${BM_SERVER_IP}

# CMIS
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "cmis.bindingType" "browser"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "cmis.bindingUrl" "http://${ALFRESCO_IP}:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser"
java -jar $JARNAME -setBMProperty $BM_SERVER_IP CMIS "cmis.repositoryId" "-default-"