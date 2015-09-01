#!/bin/bash

cd /data/alfresco

#YOUR_KIT_OPTS="-agentpath:/data/alfresco/yourkit/yourkit/libyjpagent.so=onexit=snapshot,dir=/data/alfresco/yourkit/snapshots,probe_off=*,probe_on=com.yourkit.probes.builtin.Databases"
#JAVA_OPTS="$JAVA_OPTS $YOUR_KIT_OPTS -XX:MaxPermSize=1024m -Xms256M -Xmx4G"

#echo "JAVA_OPTS=\"$JAVA_OPTS $YOUR_KIT_OPTS -XX:MaxPermSize=1024m -Xms256M -Xmx4G" | sudo tee /home/ubuntu/.bashrc

#/etc/init.d/activemq restart