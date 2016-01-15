#!/bin/bash

cd /data/alfresco

ACTIVEMQ_BROKER_HOST_TYPE=$5
JARNAME="alfresco-provisioning-1.0-SNAPSHOT.jar"

sysctl -w kernel.shmmax=17179869184
sysctl -w kernel.shmall=4194304

export SERVICES_SERVER_HOSTNAME=`java -jar $JARNAME -hostname $1 $2 $3`
echo "Services server hostname is $SERVICES_SERVER_HOSTNAME"

export ALFRESCO_SERVER_HOSTNAME=`java -jar $JARNAME -hostname $1 $2 $4`
echo "Alfresco server hostname is $ALFRESCO_SERVER_HOSTNAME"

#echo "Wait for the subscription service to boot..."
#until $(curl --output /dev/null --silent --get --user admin:admin --fail http://localhost:9092/alfresco/api/-default-/private/alfresco/versions/1/metrics); do
#    printf '.'
#    sleep 5
#done
#echo "Subscription service booted."

if [[ $ACTIVEMQ_BROKER_HOST_TYPE == "remote" ]]; then
    echo "Set ActiveMQ broker URL to failover:(tcp://$SERVICES_SERVER_HOSTNAME:61616?connectionTimeout=5000)?timeout=500&maxReconnectAttempts=5&maxReconnectDelay=500&&startupMaxReconnectAttempts=0"
    java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml messaging.broker.host $SERVICES_SERVER_HOSTNAME
else
    echo "Set ActiveMQ broker URL to failover:(tcp://localhost:61616?connectionTimeout=5000)?timeout=500&maxReconnectAttempts=5&maxReconnectDelay=500"
    java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml messaging.broker.url localhost
fi

echo "Set loggers"
java -jar $JARNAME -setLogger /data/alfresco/alfresco-sync/service-sync/config.yml org.alfresco DEBUG
echo "Done"

echo "Set Sync Service Alfresco auth URL to http://${ALFRESCO_SERVER_HOSTNAME}:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser"
java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml sync.authentication.basicAuthUrl http://${ALFRESCO_SERVER_HOSTNAME}:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser
java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml sync.repo.hostname ${ALFRESCO_SERVER_HOSTNAME}
echo "Done"

echo "Set Cassandra Hosts"
java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml cassandra.hosts localhost
echo "Done"

#java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml messaging.nodeEvents.numThreads 10

#echo "Set sync.eventsEnabled to true"
#java -jar $JARNAME -updateYaml /data/alfresco/alfresco-sync/service-sync/config.yml sync.eventsEnabled true
#echo "Done"

echo "Restarting sync service"
/etc/init.d/alfresco-sync restart