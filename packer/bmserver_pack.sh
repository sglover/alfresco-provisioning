#!/bin/bash
#set -x

#packer build -machine-readable packer.json | tee build.log
#grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2

TMPDIR="$PWD/packaging/packer/tmp"
CACHEDIR="$PWD/packaging/packer/cache"
AMI_NAME_PREFIX="BMServer"
AMI_NAME_SUFFIX="$USER-$(date +'%s')"

DEBUG=""

BUILDNAMES="amazon-ebs"

PACKER_BIN="/usr/local/packer/packer"

DELIVERY_SERVER="pbam01.alfresco.com"
DELIVERY_USER="tomcat"

BMSERVER_VER="2.0.9"

bamboo=https://bamboo.alfresco.com/bamboo/browse

MACHINE_READABLE=""

if [ ! -d $TMPDIR ]; then
    mkdir -p $TMPDIR
fi

if [ ! -d $CACHEDIR ]; then
    mkdir -p $CACHEDIR
fi

usage() {
    echo 'Usage : create-packer-amis.sh -ver <AlfrescoVersion> -bnum <Bamboo Build Number> -key <aws_access_key> -secret <aws_secret_key> -dbtype <postgresql|mysql>'

    exit
}

while [ "$1" != "" ]; do
    case $1 in
        -m )
            MACHINE_READABLE="-machine-readable"
            ;;
        -ver )
                shift
                BMSERVER_VER=$1
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
        -key )  
                shift
                AWS_ACCESS_KEY=$1
                ;;
        -secret)
                shift
                AWS_SECRET_KEY=$1
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

if [ "$AWS_ACCESS_KEY" = "" ] || [ "$AWS_SECRET_KEY" = "" ]
then
    usage
fi

getBMServer() {
    if [ -f $CACHEDIR/alfresco-benchmark-server-${BMSERVER_VER}.war ]; then
        echo "found: BMServer war"
    else
        URL="https://artifacts.alfresco.com/nexus/service/local/repositories/releases/content/org/alfresco/alfresco-benchmark-server/${BMSERVER_VER}/alfresco-benchmark-server-${BMSERVER_VER}.war"
        echo "Fetching BMServer war from url $URL..."
        curl --fail --retry 5 $URL -o $CACHEDIR/alfresco-benchmark-server-${BMSERVER_VER}.war
    fi
}

getBMServer

BMSERVER_WAR=`ls -1 $CACHEDIR/alfresco-benchmark-server-${BMSERVER_VER}.war`

# Override remote paths with local paths

currdate=`date`

cd benchmark

$PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "bmserver_war=$BMSERVER_WAR" -var "bmserver_ver=$BMSERVER_VER" -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "aws_secret_key=$AWS_SECRET_KEY" -var "ami_name=$AMI_NAME_PREFIX-${BMSERVER_VER}-$AMI_NAME_SUFFIX" -var "ami_description=BMServer ${BMSERVER_VER}, created $currdate" bmserver_install.json
#test "$?" != "0" && exit "$?"

echo "AMIs creation done"

if [[ ! "$TMPDIR" =~ target$ ]]; then
    echo "Remove local temporary files"
    rm -rf $TMPDIR
fi