Building Alfresco Boxes (AMIs and VirtualBox) using Packer
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Support for building and provisioning Alfresco One (repository, single instance only at present), sync and benchmark boxes.

cd packer

- Build Alfresco 4.2.4, Sync build 411 (implicitly assumes sync dist 4.x, compatible with Alfresco 4.2.x)

./pack.sh -ldap ldapuser:ldappassword -alfBuild 00082 -alfVer 4.2.4 [-syncDistBuild 411] -key <aws key> -secret <aws secret> [-dbtype postgres] -packer <packer executable path> -buildnames [virtualbox-iso|amazon-ebs|docker]

# Build Alfresco image

./pack.sh -a -ldap ldapuser:ldappassword -syncDistBuild 429 -alfBuild 00082 -alfVer 4.2.4 -key <aws key> -secret <aws secret> [-dbtype postgres] -packer <packer executable path> -buildnames [virtualbox-iso|amazon-ebs|docker]

# Build sync services image

./pack.sh -s -ldap ldapuser:ldappassword -syncDistVer 4.x -syncDistBuild 425 -key <aws key> -secret <aws secret> -packer <packer executable path> -buildnames [virtualbox-iso|amazon-ebs|docker]

Provisioning/Running Alfresco AWS Instances using Vagrant
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

cd vagrant

- Initial Config (first time only)

For AWS:

i) vagrant plugin install vagrant-aws
ii) vagrant plugin install vagrant-awsinfo
iii) vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box  (for AWS)

For VirtualBox (still wip):

i) vagrant box add alfsync ../packer/alfresco/alfsync.box                                   (VirtualBox)
ii) vagrant box add alfresco ../packer/alfresco/alfresco.box                                     (VirtualBox)
iii) vagrant box add sync ../packer/alfresco/sync.box                                     (VirtualBox)

Make sure that you have the following environment variables set:

e.g.

AWS_ACCESS_KEY=xyz
AWS_SECRET_KEY=abc
AWS_KEYPAIR_PATH=/Users/sglover/.ssh/sync-key.pem
AWS_KEYPAIR_NAME=sync-key-01
AWS_NAME_PREFIX=sg

- Provisioning Instances

-- View status of instances

vagrant status

-- Start an instance, with optional provisioning

vagrant up [--provision] alfaws

-- Provision a started instance

vagrant provision alfaws

-- Get the AWS instance public hostname (amongst other things)

vagrant awsinfo -m alfaws

-- SSH into the AWS instance

vagrant ssh alfaws

-- Stop the AWS instance

vagrant halt alfaws

-- Destroy the AWS instance

vagrant destroy alfaws

Note that I usually start them as follows:

vagrant up --provision servicesaws      (bring up ActiveMQ instance)
vagrant up alfaws                       (bring up Alfresco instance)
vagrant up --provision syncaws          (bring up Sync Services instance)
vagrant provision alfaws                (re-provision Alfresco instance e.g. to set sync service uris)
vagrant up --provision bmserveraws      (bring up Benchmark Server instance)
vagrant up --provision bmdriver1aws     (bring up Benchmark Driver instance)

Miscellaneous
~~~~~~~~~~~~~

- Stop Tomcat on the instance

sudo su -c "/opt/alfresco-4.2.4/alfresco.sh stop tomcat" alfresco

- Login to the aws instance (alternative to Vagrant ssh)

awsl ec2-54-220-141-176.eu-west-1.compute.amazonaws.com

- An assortment of URLs

http://192.168.33.10:8080/share
https://192.168.33.10:9090/healthcheck
https://192.168.33.10:9090/api/-default-/private/alfresco/versions/1/metrics		sync service
http://192.168.33.10:9092/api/-default-/private/alfresco/versions/1/metrics         subscription service

