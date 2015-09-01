#!/bin/bash

mkfs -t ext4 /dev/xvdb
mkdir /data
bash -c "echo '/dev/xvdb       /data   ext4    defaults,nofail,nobootwait        0       2' > /etc/fstab"
mount -a

export DEBIAN_FRONTEND=noninteractive
rm -rf /var/lib/apt/lists

# Java 8
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
add-apt-repository -y ppa:webupd8team/java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get update
apt-get -q -y install unzip oracle-java8-installer htop
ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java

# Elasticsearch + Logstash + Alfresco Plugin
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb http://packages.elastic.co/elasticsearch/1.7/debian stable main" | sudo tee -a /etc/apt/sources.list
echo 'deb http://packages.elasticsearch.org/logstash/1.5/debian stable main' | sudo tee /etc/apt/sources.list.d/logstash.list
apt-get -q -y update
apt-get -q -y install unzip linux-image-generic-lts-raring linux-headers-generic-lts-raring build-essential dkms zlib1g-dev libssl-dev libreadline6-dev libyaml-dev curl wget git-core gcc g++ make autoconf python-software-properties screen elasticsearch logstash
/usr/share/elasticsearch/bin/plugin --install alfresco url file:///tmp/alfresco-elasticsearch-plugin-1.0-SNAPSHOT.zip
/usr/share/elasticsearch/bin/plugin --install royrusso/elasticsearch-HQ
cat /home/ubuntu/es-config.txt | sudo tee -a /etc/elasticsearch/elasticsearch.yml
update-rc.d elasticsearch defaults 95 10
update-rc.d logstash defaults 97 8
mkdir -p /data/elasticsearch/backups
chown -R elasticsearch:elasticsearch /data/elasticsearch

# Kibana
cd /tmp
wget https://download.elasticsearch.org/kibana/kibana/kibana-4.0.1-linux-x64.tar.gz
tar xvf kibana-*.tar.gz
mv kibana-4.0.1-linux-x64 /opt/kibana
cp /tmp/kibana4 /etc/init.d/kibana4
chmod +x /etc/init.d/kibana4
update-rc.d kibana4 defaults 96 9