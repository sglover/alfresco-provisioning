#!/bin/bash

cd /data/alfresco

JARNAME="alfresco-provisioning-1.0-SNAPSHOT.jar"

export BM_SERVER_IP=`java -jar $JARNAME -hostname $1 $2 $6`
mkdir -p /tmp/tomcat7/bm/cached-files
chown -R tomcat7:tomcat7 /tmp/tomcat7
echo "JAVA_OPTS=\"$JAVA_OPTS -server -XX:MaxPermSize=1024m -Xms256M -Xmx2G -Dmongo.config.host=localhost\"" | sudo tee /usr/share/tomcat7/bin/setenv.sh
echo "CATALINA_TMPDIR=\"/tmp/tomcat7\"" | sudo tee -a /usr/share/tomcat7/bin/setenv.sh
/etc/init.d/tomcat7 restart