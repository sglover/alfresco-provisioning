#!/bin/bash

ACTIVEMQ_BROKER_HOST_TYPE=$5
JMX_URI=service:jmx:rmi:///jndi/rmi://localhost:50500/alfresco/jmxrmi
JMX_USER="controlRole"
JMX_PASS="change_asap"
JARNAME="alfresco-provisioning-1.0-SNAPSHOT.jar"
ALF_VERSION=5.0.1

sysctl -w kernel.shmmax=17179869184
sysctl -w kernel.shmall=4194304

# wait for the repo to start
echo "Wait for the repository to boot..."
until $(curl --output /dev/null --silent --get --user admin:admin --fail http://localhost:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser); do
    echo -n '.'
    sleep 5
done
echo "Repository booted."

cd /data/alfresco

echo "Getting services hostname"
SERVICES_SERVER_HOSTNAME=`java -jar $JARNAME -hostname $1 $2 $3`
if [[ $? == "0" ]]; then
    echo "Services server hostname is $SERVICES_SERVER_HOSTNAME"
#    echo "Set ActiveMQ broker URL to tcp://${SERVICES_SERVER_HOSTNAME}:61616"
#    echo "Set ActiveMQ broker URL to tcp://${SYNC_SERVER_HOSTNAME}:61616"
#    java -jar $JARNAME -brokeruri $JMX_USER $JMX_PASS $SYNC_SERVER_HOSTNAME
else
    echo "Services instance is not running"
fi

PUBLIC_DNS=`curl -s http://169.254.169.254/latest/meta-data/public-hostname`

if [[ $ACTIVEMQ_BROKER_HOST_TYPE == "services" ]]; then
    MESSAGING_IP=$SERVICES_SERVER_HOSTNAME
    echo "Services host messaging - IP $MESSAGING_IP"
elif [[ $ACTIVEMQ_BROKER_HOST_TYPE == "sync" ]]; then
    MESSAGING_IP=$SYNC_SERVER_HOSTNAME
    echo "Sync host messaging - IP $SYNC_SERVER_HOSTNAME"
else
    echo "Invalid messaging host type $ACTIVEMQ_BROKER_HOST_TYPE (expected services or sync)"
    exit 1
fi

echo "Set ActiveMQ broker URL to tcp://${MESSAGING_IP}:61616"
java -Dsun.rmi.transport.tcp.responseTimeout=5000 -jar $JARNAME -brokeruri $JMX_USER $JMX_PASS $MESSAGING_IP

#echo "Set ActiveMQ broker URL to failover:(tcp://${MESSAGING_IP}:61616?connectionTimeout=5000)?timeout=500&maxReconnectAttempts=5&maxReconnectDelay=500"
#echo "JAVA_OPTS=\"-Dmirror.name=$7 -Dmessaging.broker.url=tcp://${MESSAGING_IP}:61616 -DalfrescoHost=${ALFRESCO_IP} -Dmongo.config.host=$BM_SERVER_IP\"" | sudo tee -a /usr/share/tomcat7/bin/setenv.sh

echo "Getting sync server hostname"
SYNC_SERVER_HOSTNAME=`java -jar $JARNAME -hostname $1 $2 $4`
if [[ $? == "0" ]]; then
    echo "Sync server hostname is $SYNC_SERVER_HOSTNAME"

    SYNC_SERVER_URI="https://$SYNC_SERVER_HOSTNAME:9090/alfresco"
    echo "Sync server uri is $SYNC_SERVER_URI"
    
    echo "Update repository sync service uri"
    
    echo "update the sync service uri to point to the sync server box"
    java -jar $JARNAME -syncuri $JMX_USER $JMX_PASS $SYNC_SERVER_URI  
else
    echo "Sync server instance is not running"
fi

sed -i '/sync.service.uris=/d' /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco-global.properties
echo "sync.service.uris=https://${SYNC_SERVER_HOSTNAME}:9090/alfresco" | sudo tee -a /data/alfresco/alfresco-${ALF_VERSION}/tomcat/shared/classes/alfresco-global.properties

sed -i '/JAVA_OPTS=/d' /data/alfresco/alfresco-${ALF_VERSION}/tomcat/bin/setenv.sh
echo "JAVA_OPTS=\"\$JAVA_OPTS -Djava.rmi.server.hostname=${PUBLIC_DNS}\"" | sudo tee -a /data/alfresco/alfresco-${ALF_VERSION}/tomcat/bin/setenv.sh

echo "Done"