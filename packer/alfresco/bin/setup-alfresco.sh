#!/bin/bash
cd $(dirname $0)
ALFRESCO_OPTS=$(curl -sf http://169.254.169.254/latest/user-data | python parse-java-opts.py)
if [ -n "$ALFRESCO_OPTS" -a -f /opt/alfresco-5.0/tomcat/bin/setenv.sh ]; then
    sed -i "/^export JAVA_HOME/i\# Custom user-data options $(date)\nJAVA_OPTS=\"$ALFRESCO_OPTS \$JAVA_OPTS\"" /opt/alfresco-5.0/tomcat/bin/setenv.sh
fi