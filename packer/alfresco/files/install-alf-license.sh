#!/bin/bash

echo "Wait for the repository to boot..."
until $(curl --output /dev/null --silent --get --user admin:admin --fail http://localhost:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser); do
    printf '.'
    sleep 5
done

mkdir -p /data/alfresco/alfresco-${ALF_VERSION}/shared/classes/alfresco/extension/license
echo "Copying license /tmp/alfresco-license.lic to /data/alfresco/alfresco-${ALF_VERSION}/shared/classes/alfresco/extension/licenses"
cp /tmp/alfresco-license.lic /data/alfresco/alfresco-${ALF_VERSION}/shared/classes/alfresco/extension/license

/etc/init.d/alfresco restart tomcat
