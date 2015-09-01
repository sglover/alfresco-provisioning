#!/bin/bash
#set -x

#packer build -machine-readable packer.json | tee build.log
#grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2

TMPDIR="$PWD/packaging/packer/tmp"
CACHEDIR="$PWD/packaging/packer/cache"
ALFRESCO_DIR="$PWD/alfresco"
AMI_NAME_PREFIX="Services"
AMI_NAME_SUFFIX="$USER-$(date +'%s')"

DEBUG=""

BUILDNAMES="amazon-ebs,virtualbox-iso"

PACKER_BIN="/usr/local/packer/packer"

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
    echo 'Usage : services_pack.sh -key <aws_access_key> -secret <aws_secret_key>'
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

if [[ "$AWS_ACCESS_KEY" = "" ]] || [[ "$AWS_SECRET_KEY" = "" ]]
then
    usage
fi

getActiveMQ() {
    if [ -f $CACHEDIR/activemq.tar.gz ]; then
        echo "found: ActiveMQ zip"
    else
        URL="https://repository.apache.org/content/repositories/releases/org/apache/activemq/apache-activemq/5.11.1/apache-activemq-5.11.1-bin.tar.gz"
        echo "Fetching ActiveMQ dist from url $URL..."
        curl --fail --retry 5 $URL -o $CACHEDIR/activemq.tar.gz
    fi
}

getActiveMQ

ACTIVEMQ_DISTRO=`ls -1 $CACHEDIR/activemq*`

# Override remote paths with local paths

currdate=`date`

cd services

$PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "aws_secret_key=$AWS_SECRET_KEY" -var "activemq_zip_path=$ACTIVEMQ_DISTRO" -var "ami_name=$AMI_NAME_PREFIX-$AMI_NAME_SUFFIX" -var "ami_description=Services, created $currdate" services_install.json
test "$?" != "0" && exit "$?"

echo "AMIs creation done"

if [[ ! "$TMPDIR" =~ target$ ]]; then
    echo "Remove local temporary files"
    rm -rf $TMPDIR
fi