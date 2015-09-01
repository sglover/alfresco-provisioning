#!/bin/bash

cd /home/ubuntu

export SERVICES_IP=`java -jar service-sync-bundle-1.1-SNAPSHOT.jar -hostname $1 $2 $3`
echo "Services hostname is $SERVICES_IP"

sed -i -e "s@\(broker.url: tcp://\).*\(:61616\)@\1${SERVICES_IP}\2@" /etc/elasticsearch/elasticsearch.yml
#echo "  org.alfresco.service.common.elasticsearch: DEBUG" | sudo tee -a /etc/elasticsearch/logging.yml

/etc/init.d/elasticsearch stop

/usr/share/elasticsearch/bin/plugin --remove alfresco
/usr/share/elasticsearch/bin/plugin --install alfresco url file:///home/ubuntu/alfresco-elasticsearch-plugin-1.0-SNAPSHOT.zip

/etc/init.d/elasticsearch start