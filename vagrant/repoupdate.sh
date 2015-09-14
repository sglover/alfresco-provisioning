#!/bin/bash

JMX_URI=service:jmx:rmi:///jndi/rmi://localhost:50500/alfresco/jmxrmi
JMX_USER="controlRole"
JMX_PASS="change_asap"
JARNAME="alfresco-provisioning-1.0-SNAPSHOT.jar"

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

echo "Getting services hostname"
#SERVICES_SERVER_HOSTNAME=`java -jar $JARNAME -hostname $1 $2 $3`
#if [[ $? == "0" ]]; then
#    echo "Services server hostname is $SERVICES_SERVER_HOSTNAME"

#    echo "Set ActiveMQ broker URL to tcp://${SERVICES_SERVER_HOSTNAME}:61616"
    echo "Set ActiveMQ broker URL to tcp://${SYNC_SERVER_HOSTNAME}:61616"
    java -jar $JARNAME -brokeruri $JMX_USER $JMX_PASS $SYNC_SERVER_HOSTNAME
#else
#    echo "Services instance is not running"
#fi

echo "Done"