#!/bin/bash

TMPDIR="$PWD/packaging/packer/tmp"
CACHEDIR="$PWD/packaging/packer/cache"
AMI_NAME_PREFIX="ES"
AMI_NAME_SUFFIX="$USER-$(date +'%s')"

DEBUG=""

BUILDNAMES="amazon-ebs,virtualbox-iso"

PACKER_BIN=`which packer`

DELIVERY_SERVER="pbam01.alfresco.com"
DELIVERY_USER="tomcat"

bamboo=https://bamboo.alfresco.com/bamboo/browse

MACHINE_READABLE=""

if [ ! -d $TMPDIR ]; then
    mkdir -p $TMPDIR
fi

if [ ! -d $CACHEDIR ]; then
    mkdir -p $CACHEDIR
fi

if [ -d $ALFRESCO_DIR/output-virtualbox-iso ]; then
    rm -rf $ALFRESCO_DIR/output-virtualbox-iso
fi

usage() {
    echo 'Usage : es_pack.sh -key <aws_access_key> -secret <aws_secret_key>'
    exit
}

while [ "$1" != "" ]; do
    case $1 in
        -m )
            MACHINE_READABLE="-machine-readable"
            ;;
        -buildnames )
                shift
                BUILDNAMES=$1
                ;;
        -debug )
                DEBUG="-debug"
                ;;
        -sshKey )
                shift
                SSH_KEY=$1
                ;;
        -ldap )
                shift
                CREDENTIALS=$1
                ;;
        -tmpdir )
                shift
                TMPDIR=$1
                ;;
        -packer )
                shift
                PACKER_BIN=$1
                ;;
        * )     
                break
                ;;
    esac
    shift
done

if [[ "$AWS_ACCESS_KEY" = "" ]] || [[ "$AWS_SECRET_KEY" = "" ]]
then
    usage
fi

# Override remote paths with local paths

currdate=`date`

cd elasticsearch

ES_PLUGIN_PATH=`ls -1 ~/.m2/repository/org/alfresco/extensions/alfresco-elasticsearch-plugin/1.0-SNAPSHOT/*zip`

$PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "alf_plugin_path=$ES_PLUGIN_PATH" -var "aws_access_key=$AWS_ACCESS_KEY" -var "aws_secret_key=$AWS_SECRET_KEY" -var "ami_name=$AMI_NAME_PREFIX-$AMI_NAME_SUFFIX" -var "ami_description=ES Alfresco, created $currdate" elasticsearch_install.json
test "$?" != "0" && exit "$?"

echo "AMIs creation done"

if [[ ! "$TMPDIR" =~ target$ ]]; then
    echo "Remove local temporary files"
    rm -rf $TMPDIR
fi