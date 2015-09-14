#!/bin/bash
#set -x

#packer build -machine-readable packer.json | tee build.log
#grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2

TMPDIR="$PWD/packaging/packer/tmp"
CACHEDIR="$PWD/packaging/packer/cache"
AMI_NAME_PREFIX="BMDriver"
AMI_NAME_SUFFIX="$USER-$(date +'%s')"

DEBUG=""

BUILDNAMES="amazon-ebs"

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

usage() {
    echo 'Usage : bmdriver_pack.sh -ver <AlfrescoVersion> -bnum <Bamboo Build Number> -key <aws_access_key> -secret <aws_secret_key> -dbtype <postgresql|mysql>'

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

if [ "$AWS_ACCESS_KEY" = "" ] || [ "$AWS_SECRET_KEY" = "" ]
then
    usage
fi

# Override remote paths with local paths

currdate=`date`

cd benchmark

$PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "aws_secret_key=$AWS_SECRET_KEY" -var "ami_name=$AMI_NAME_PREFIX-$AMI_NAME_SUFFIX" -var "ami_description=BMDriver, created $currdate" bmdriver_install.json
#test "$?" != "0" && exit "$?"

echo "AMIs creation done"

if [[ ! "$TMPDIR" =~ target$ ]]; then
    echo "Remove local temporary files"
    rm -rf $TMPDIR
fi