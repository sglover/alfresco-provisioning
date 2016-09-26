#!/bin/bash
#set -x

#packer build -machine-readable packer.json | tee build.log
#grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2

TMPDIR="$PWD/packaging/packer/tmp"
CACHEDIR="$PWD/packaging/packer/cache"
ALFRESCO_DIR="$PWD/alfresco"
AMI_NAME_PREFIX="sync"
AMI_NAME_SUFFIX="$USER-$(date +'%s')"
ACTIVEMQ_VERSION=5.11.2

DEBUG=""

BUILDNAMES="amazon-ebs,virtualbox-iso"

PACKER_BIN=`which packer`

DELIVERY_SERVER="pbam01.alfresco.com"
DELIVERY_USER="tomcat"

bamboo=https://bamboo.alfresco.com/bamboo/browse

INCLUDE_ALFRESCO="n"
INCLUDE_SYNC="n"

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
    echo 'Usage : pack.sh -ver <AlfrescoVersion> -bnum <Bamboo Build Number> -key <aws_access_key> -secret <aws_secret_key> -dbtype <postgresql|mysql>'

    exit
}

while [ "$1" != "" ]; do
    case $1 in
        -a )
            INCLUDE_ALFRESCO="y"
            ;;
        -s )
            INCLUDE_SYNC="y"
            ;;
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
        -alfBuild )  
                shift
                ALFRESCO_BUILD=$1
                ;;
        -alfVer )  
                shift
                ALFRESCO_VERSION=$1
                ;;
        -syncDistBuild )  
                shift
                SYNC_DIST_BUILD=$1
                ;;
        -syncDistVersion )  
                shift
                SYNC_DIST_VERSION=$1
                ;;
        -bnum )	
                shift
                BAMBOO_BUILD_NUMBER=$1
                AMI_NAME_SUFFIX="build-$BAMBOO_BUILD_NUMBER"
                ;;
#        -key )  
#                shift
#                AWS_ACCESS_KEY=$1
#                ;;
#        -secret)
#                shift
#                AWS_SECRET_KEY=$1
#                ;;
        -dbtype )
                shift
                SYNC_DBTYPE=$1
                ;;
        -tmpdir )
                shift
                TMPDIR=$1
                ;;
        -installer_path )
                shift
                ALFRESCO_INSTALLER_PATH=$1
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

if [[ "$INCLUDE_ALFRESCO" = "y" ]]; then
    if [[ "$ALFRESCO_VERSION" = "" ]]; then
        usage
    fi

    OLD_IFS="$IFS"
    IFS="."
    STR_ARRAY=( $ALFRESCO_VERSION )
    IFS="$OLD_IFS"

    ALFRESCO_VERSION_PREFIX="${STR_ARRAY[0]}"
    ALFRESCO_VERSION_MAJOR="${STR_ARRAY[0]}.${STR_ARRAY[1]}"
fi

if [[ "$INCLUDE_SYNC" = "y" ]]; then
    if [[ "$INCLUDE_ALFRESCO" = "y" ]]; then
        SYNC_DIST_VERSION="${STR_ARRAY[0]}.x"
    else
        if [[ "$SYNC_DIST_VERSION" = "" ]]; then
            usage
        fi        
    fi
fi

getAlfrescoInstaller() {
    if [[ -f $CACHEDIR/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin ]]; then
        echo "found: alfresco release"
    else
#        if [ "$ALFRESCO_BUILD" = "latest" ]; then
#            URL="https://releases.alfresco.com/Enterprise-$ALFRESCO_VERSION_MAJOR/$ALFRESCO_VERSION/build-$ALFRESCO_BUILD/ALL/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin"
#            echo "Fetching Alfresco $1 Installer from url $URL..."
#            curl -u $CREDENTIALS --fail --retry 5 $URL -o $CACHEDIR/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin
#        else
#        if [ "$ALFRESCO_VERSION_MAJOR" = "5.1" ]; then
#            URL="http://bamboo.alfresco.com/bamboo/browse/ALF-EPACK-${ALFRESCO_BUILD}/artifact/JOB1/ALL/alfresco-enterprise-installer-20150930-SNAPSHOT-357-linux-x64.bin"
#            echo "Fetching Alfresco $1 Installer from url $URL..."
#            curl -u $CREDENTIALS --fail --retry 5 $URL -o $CACHEDIR/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin
#        else
            URL="https://releases.alfresco.com/Enterprise-$ALFRESCO_VERSION_MAJOR/$ALFRESCO_VERSION/build-$ALFRESCO_BUILD/ALL/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin"
            echo "Fetching Alfresco $1 Installer from url $URL..."
            curl -u $CREDENTIALS --fail --retry 5 $URL -o $CACHEDIR/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin
        fi
#    fi
}

getAlfrescoLicense() {
    if [[ $ALFRESCO_VERSION_PREFIX = "5" ]]; then
        LICENSE_URL="https://svn.alfresco.com/repos/alfresco-internal/alfresco/INTERNAL/projects/license/licenses/enterprise-${ALFRESCO_VERSION_MAJOR}-developer-unlimited.lic"
    else
        LICENSE_URL="https://svn.alfresco.com/repos/alfresco-internal/alfresco/INTERNAL/projects/license/licenses/enterprise-v${ALFRESCO_VERSION_MAJOR}-developer-unlimited.lic"
    fi

    echo "Fetching Alfresco license from url $LICENSE_URL..."
    curl -u $CREDENTIALS --fail --retry 5 $LICENSE_URL -o $CACHEDIR/enterprise-v${ALFRESCO_VERSION_MAJOR}-unlimited.lic
}

getSyncZip() {
    if [[ "$SYNC_DIST_BUILD" = "developer" ]]; then
        if [[ "$SYNC_DIST_VERSION" = "" ]]; then
            if [[ "$ALFRESCO_VERSION_MAJOR" = "4.2" ]]; then
                SYNC_DIST="../../sync-dist-4.x/target/sync-dist-4.2x.zip"
            elif [[ "$ALFRESCO_VERSION_MAJOR" = "5.0" ]]; then
                SYNC_DIST="../../sync-dist-5.x/target/AlfrescoSyncServer.zip"
            else
                echo "Invalid alfVerm value"
                exit 1
            fi
        else
            SYNC_DIST="../../sync-dist-${SYNC_DIST_VERSION}/target/sync-dist-${SYNC_DIST_VERSION}.zip"
        fi

        SYNC_DISTRO=$CACHEDIR/sync-dist-$SYNC_DIST_VERSION.zip
#        if [[ -f $SYNC_DISTRO ]]; then
#            echo "Sync dist $SYNC_DISTRO is in cache"
#        else
        # Always copy over the new version from the build into the cache
            if [[ -f $SYNC_DIST ]]; then
                echo "Copying $SYNC_DIST to $SYNC_DISTRO"
                cp $SYNC_DIST $SYNC_DISTRO
            else
                echo "Sync dist $SYNC_DIST does not exist"
                exit 1
            fi
#        fi
    elif [[ "$SYNC_DIST_BUILD" = "latest" ]]; then
        SYNC_DISTRO=$CACHEDIR/sync-dist-$SYNC_DIST_VERSION-latest.zip
        if [[ -f $SYNC_DISTRO ]]; then
            echo "Sync dist $SYNC_DISTRO is in cache"
        else
            if [[ "$ALFRESCO_VERSION_MAJOR" = "4.2" ]]; then
                SYNC_DIST_VERSION="4.x"
            elif [[ "$ALFRESCO_VERSION_MAJOR" = "5.0" ]]; then
                SYNC_DIST_VERSION="5.x"
            else
                echo "Invalid alfVerm value"
                exit 1
            fi
    
            URL="$bamboo/SRVC-SYNC/latestSuccessful/artifact/JOB1/$SYNC_DIST_VERSION-Distribution-Zip/sync-dist-$SYNC_DIST_VERSION.zip"
            echo "Fetching sync dist from url $URL..."
            curl -u $CREDENTIALS --fail --retry 5 $URL -o $SYNC_DISTRO
        fi
    else
        if [[ "$SYNC_DIST_VERSION" = "" ]]; then
            if [[ "$ALFRESCO_VERSION_MAJOR" = "4.2" ]]; then
                SYNC_DIST_VERSION="4.x"
            elif [[ "$ALFRESCO_VERSION_MAJOR" = "5.0" ]]; then
                SYNC_DIST_VERSION="5.x"
            else
                echo "Invalid alfVerm value"
                exit 1
            fi
        fi

        SYNC_DISTRO=$CACHEDIR/sync-dist-$SYNC_DIST_VERSION-$SYNC_DIST_BUILD.zip
        if [[ -f $SYNC_DISTRO ]]; then
            echo "Sync dist $SYNC_DISTRO is in cache"
        else
            URL="$bamboo/SRVC-SYNC-$SYNC_DIST_BUILD/artifact/JOB1/$SYNC_DIST_VERSION-Distribution-Zip/AlfrescoSyncServer.zip"
            echo "Fetching sync dist from url $URL..."
            curl -u $CREDENTIALS --fail --retry 5 $URL -o $SYNC_DISTRO
        fi
    fi
}

getActiveMQ() {
    if [ -f $CACHEDIR/activemq.tar.gz ]; then
        echo "found: ActiveMQ zip"
    else
        URL="https://repository.apache.org/content/repositories/releases/org/apache/activemq/apache-activemq/${ACTIVEMQ_VERSION}/apache-activemq-${ACTIVEMQ_VERSION}-bin.tar.gz"
        echo "Fetching ActiveMQ dist from url $URL..."
        curl --fail --retry 5 $URL -o $CACHEDIR/activemq.tar.gz
    fi
}

if [ "$INCLUDE_SYNC" = "y" ]; then
    getSyncZip
    getActiveMQ
    ACTIVEMQ_DISTRO=`ls -1 $CACHEDIR/activemq*`
    echo "SYNC_DISTRO=$SYNC_DISTRO"
    echo "ACTIVEMQ_DISTRO=$ACTIVEMQ_DISTRO"
fi

if [ "$INCLUDE_ALFRESCO" = "y" ]; then
#    if [ "$SYNC_DIST_VERSION" = "" ]; then
#        usage
#    fi
#        usage
#    if [ "$SYNC_DIST_VERSION" = "" ]; then
#    fi
    getSyncZip
    getActiveMQ
    getAlfrescoInstaller "$ALFRESCO_VERSION"
    getAlfrescoLicense
    ALFRESCO_INSTALLER=`ls $CACHEDIR/alfresco-enterprise-$ALFRESCO_VERSION-installer-linux-x64.bin`
    ACTIVEMQ_DISTRO=`ls -1 $CACHEDIR/activemq*`
    #SYNC_DISTRO=`ls -1 $CACHEDIR/sync-dist-*.zip`
    ALFRESCO_LICENSE_PATH=`ls -1 $CACHEDIR/enterprise-v${ALFRESCO_VERSION_MAJOR}-unlimited.lic`
    echo "ALFRESCO_VERSION=$ALFRESCO_VERSION"
    echo "ALFRESCO_VERSION_MAJOR=$ALFRESCO_VERSION_MAJOR"
    echo "SYNC_DISTRO=$SYNC_DISTRO"
    echo "ALFRESCO_INSTALLER=$ALFRESCO_INSTALLER"
    echo "ACTIVEMQ_DISTRO=$ACTIVEMQ_DISTRO"
    echo "ALFRESCO_LICENSE_PATH=$ALFRESCO_LICENSE_PATH"
fi

# Override remote paths with local paths

currdate=`date`

echo "INCLUDE_ALFRESCO=$INCLUDE_ALFRESCO"

if [ "$INCLUDE_ALFRESCO" = "y" ]; then
    cd alfresco
    if [ "$INCLUDE_SYNC" = "y" ]; then
        echo "Using install.json"
        $PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "tag_sync_build_num=$SYNC_DIST_BUILD" -var "aws_secret_key=$AWS_SECRET_KEY" -var "activemq_zip_path=$ACTIVEMQ_DISTRO" -var "sync_zip_path=$SYNC_DISTRO" -var "ami_name=$AMI_NAME_PREFIX-alfresco-$ALFRESCO_VERSION-$SYNC_DIST_BUILD-$AMI_NAME_SUFFIX" -var "alfresco-version=$ALFRESCO_VERSION" -var "license_path=$ALFRESCO_LICENSE_PATH" -var "installer_file=$ALFRESCO_INSTALLER" -var "ami_description=Sync $SYNC_DIST_VERSION ($SYNC_DIST_BUILD), Alfresco $ALFRESCO_VERSION, created $currdate" install.json
    else
        echo "Using alfresco_install.json"
        $PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "aws_secret_key=$AWS_SECRET_KEY" -var "activemq_zip_path=$ACTIVEMQ_DISTRO" -var "sync_zip_path=$SYNC_DISTRO" -var "ami_name=alfresco-$ALFRESCO_VERSION-$AMI_NAME_SUFFIX" -var "alfresco-version=$ALFRESCO_VERSION" -var "license_path=$ALFRESCO_LICENSE_PATH" -var "installer_file=$ALFRESCO_INSTALLER" -var "ami_description=Alfresco $ALFRESCO_VERSION, created $currdate" alfresco_install.json
    fi
else
    cd sync
    if [ "$INCLUDE_SYNC" = "y" ]; then
        echo "Using sync_install.json $SYNC_DISTRO"
	echo $PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "tag_sync_build_num=$SYNC_DIST_BUILD" -var "aws_secret_key=$AWS_SECRET_KEY" -var "sync_zip_path=$SYNC_DISTRO" -var "ami_name=$AMI_NAME_PREFIX-$SYNC_DIST_BUILD-$AMI_NAME_SUFFIX" -var "activemq_zip_path=$ACTIVEMQ_DISTRO" -var "ami_description=Sync $SYNC_DIST_VERSION ($SYNC_DIST_BUILD), created $currdate" sync_install.json
        $PACKER_BIN $MACHINE_READABLE build $DEBUG -only=$BUILDNAMES -var "ssh_key=$SSH_KEY" -var "aws_access_key=$AWS_ACCESS_KEY" -var "tag_sync_build_num=$SYNC_DIST_BUILD" -var "aws_secret_key=$AWS_SECRET_KEY" -var "sync_zip_path=$SYNC_DISTRO" -var "ami_name=$AMI_NAME_PREFIX-$SYNC_DIST_BUILD-$AMI_NAME_SUFFIX" -var "activemq_zip_path=$ACTIVEMQ_DISTRO" -var "ami_description=Sync $SYNC_DIST_VERSION ($SYNC_DIST_BUILD), created $currdate" sync_install.json
    else
        usage
    fi
fi
#test "$?" != "0" && exit "$?"

echo "AMIs creation done"

if [[ ! "$TMPDIR" =~ target$ ]]; then
    echo "Remove local temporary files"
    rm -rf $TMPDIR
fi
