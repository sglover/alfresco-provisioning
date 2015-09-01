"""
Manage Sync environments in EC2

Usage: python aws.py action [options]

Where action is one of

    * create-instance           Create a new named environment
    * list-amis                 List active amis
    * list-instances            List active environments
    * terminate[-instances]     Terminate and clean up environments
    * delete[-images]           Delete images
    * add-[security-]rule       Add a rule to an existing security group
    * connect                   Connect to an instance via SSH

General options and arguments:

    --help / -h                 Print this message
    --debug / -d                Turn on debug mode (prints CLI commands used)
    --base / -b                 Base name for instances to create, e.g. Reporting-TestX

create-instances options

    --sync-build-num
    --alfresco-version
    --ami                       AMI to use. Overrides --sync-build-num and --alfresco-version
    --instance-type             Instance type to use (default: m3.2xlarge)
    --alfresco-user-data-file   Name of file containing instance data to pass to the Alfresco instance
    --alfresco-device-mappings  Block device mapping overrides for the Alfresco instance (defaults taken from the AMI definition)
    --security-groups           Security group names to apply to the instances, comma-separated
    --security-groups-id        Security group IDs to apply to the instances, comma-separated
    --keyname                   SSH key name for connecting to the instances, must already have been created in EC2
    --spot-price                Max bid price for spot instances in dollars. By default if not set spot instances will not be used.

terminate-instances options

    --base / -b                 Environment base name to terminate instances, e.g. BigG2

delete-images options

    --names                     Comma-separated list of names to delete

add-security-rule options

    --group-id                  ID of the security group to modify
    --group-name                Name of the security group to modify
    --my-ip                     Look up my external IP and add this to the security group
    --source-ip                 Specific named IP to add access to
    --port                      Single port or range of TCP ports, in the format x-y, to grant access to (default - all ports)

connect options

    --instance                  ID or name of the instance to connect to
    --key                       Local filesystem path of the identity file to supply to SSH via -i (default - look up automatically from instance)
    --user                      User to connect to the machine as (default - ubuntu)

"""
import base64
import dateutil.parser
import getopt
import json
import os
import random
import string
import subprocess
import tempfile
import time
import urllib2
import sys
import time
from datetime import tzinfo, timedelta, datetime
from os.path import expanduser

# python aws.py list-instances
# python aws.py create-instance --base Sync-sg1 --sync-build-num 411 --alfresco-version 4.2.4 --instance-type m3.2xlarge --security-groups Sync-01 
# python aws.py list-instances
# python aws.py terminate-instances
# python aws.py terminate-instances --base Sync-sg1
# python aws.py terminate-instances --base Sync-sg1 -d
# python aws.py terminate-instances --base Sync-sg1 -d
# python aws.py terminate-instances --base Sync-sg1 -d
# python aws.py terminate-instances --base Sync-sg1 -d
# python aws.py terminate-instances --base Sync-sg1
# python aws.py terminate-instances --base Sync-sg1
# python aws.py terminate-instances --base Sync-sg1

alfresco_admin_pw="admin"
ssh_user="ubuntu"
_debug=0

ALL_INSTANCE_STATES = ('pending', 'running', 'shutting-down', 'stopping', 'stopped', 'terminated')
ACTIVE_INSTANCE_STATES = ('pending', 'running', 'shutting-down', 'stopping', 'stopped')

def time2str(td):
    secs = td.total_seconds()
    MINUTE = 60
    HOUR = MINUTE*60
    DAY = HOUR*24
    if secs < MINUTE:
        return "%ds" % secs
    elif secs < HOUR:
        return "%dm" % round(secs/MINUTE)
    elif secs < DAY:
        return "%dh" % round(secs/HOUR)
    else:
        return "%dd" % round(secs/DAY)

class UTC(tzinfo):
  def utcoffset(self, dt):
    return timedelta(0)
  def tzname(self, dt):
    return "UTC"
  def dst(self, dt):
    return timedelta(0)

def execute_cli(cmd, params):
    cmd = ["aws", "ec2", cmd]
    cmd.extend(params)
    if _debug == 1:
        print "DEBUG: Run: %s" % (" ".join(cmd))
    output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
    return json.loads(output) if len(output) > 0 and output.strip()[0] == '{' else None

def execute_shell(cmd):
    if _debug == 1:
        print "DEBUG: Run interactive: %s" % (" ".join(cmd))
    proc = subprocess.Popen(cmd)
    proc.wait()

def tag_resource(id, tags):
    params = ["--resources", id, "--tags"]
    params.extend(["Key=%s,Value=%s" % (k, v) for (k, v) in tags.items()])
    return execute_cli("create-tags", params)

def get_ami(sync_build_num, alfresco_version):
    data = execute_cli("describe-images", ["--filters", "Name=tag:AMIType,Values=Sync", "Name=tag:SyncBuildNum,Values=%s" % sync_build_num, "Name=tag:AlfrescoVersion,Values=%s" % alfresco_version])
    if 'Images' in data and len(data['Images']) > 0:
        sortedList = sorted(data['Images'], key=lambda i: i['Name'])
        return sortedList[len(sortedList)-1]
    else:
        return None

def get_instances(filters):
    tostr = lambda x: hasattr(x, '__iter__') and ",".join(x) or x
    filterstrs = [ "Name=%s,Values=%s" % (k, tostr(v)) for k, v in filters.items() ]
    data = execute_cli("describe-instances", ["--filters"] + filterstrs)
    instances = []
    if 'Reservations' in data:
        for r in data['Reservations']:
            if 'Instances' in r:
                instances.extend(r['Instances'])
    return instances

def run_instance(ami, keyname, security_groups, security_group_ids=[], instance_type="m3.2xlarge", user_data=None, spot_price=None, name="", device_mappings=None):
    if not ami.startswith("ami-"):
        ami_data = get_ami(ami)
        if ami_data is not None:
            ami = ami_data["ImageId"]
        else:
            print "AMI '%s' not found" % (ami)
    cmdparams = ["--image-id", ami, "--count", "1", "--instance-type", instance_type, "--key-name", keyname]
    if len(security_groups) > 0 and security_groups != ['']:
        cmdparams.append("--security-groups")
        cmdparams.extend(security_groups)
    if len(security_group_ids) > 0 and security_group_ids != ['']:
        cmdparams.append("--security-group-ids")
        cmdparams.extend(security_group_ids)
    tmp = None
    instance_id = None
    mappings_data = execute_cli("describe-images", ["--image-ids", ami])["Images"][0]["BlockDeviceMappings"]
    if user_data is not None:
        tmp = tempfile.mkstemp()
        f = os.fdopen(tmp[0], "w")
        f.write(user_data)
        f.close()
        cmdparams.append("--user-data")
        # Does not work
        #cmd.append(base64.b64encode(user_data))
        cmdparams.append("file://%s" % (tmp[1]))
    # Are any overrides provided for block device parameters? This allows the size to be changed while still using the snapshotid from the AMI def
    if device_mappings is not None:
        for dev in mappings_data:
            if dev["DeviceName"] in device_mappings: # Is an override there?
                dev["Ebs"].update(device_mappings[dev["DeviceName"]])
            # cannot specify the encrypted flag if specifying a snapshot id
            if "Ebs" in dev and "SnapshotId" in dev["Ebs"] and "Encrypted" in dev["Ebs"]:
                del dev["Ebs"]["Encrypted"]
    cmdparams.extend(["--block-device-mappings", json.dumps(mappings_data)])
    if spot_price is not None and spot_price > 0:
        cliskel = {}
        cliskel["ImageId"] = ami
        cliskel["InstanceType"] = instance_type
        cliskel["KeyName"] = keyname
        cliskel["SecurityGroupIds"] = security_groups
        if user_data is not None:
            cliskel["UserData"] = base64.b64encode(user_data)
        cliskel["BlockDeviceMappings"] = mappings_data
        jsonstr = json.dumps(cliskel)
        spotdata = execute_cli("request-spot-instances", ["--spot-price", str(spot_price), "--instance-count", "1", "--launch-specification", jsonstr])
        spot_request_id=spotdata["SpotInstanceRequests"][0]["SpotInstanceRequestId"]
        print "Spot instance request %s" % (spot_request_id)
        for i in range(0, 30):
            sirdata = json.loads(subprocess.check_output(["aws", "ec2", "describe-spot-instance-requests", "--spot-instance-request-ids", spot_request_id]))
            if ("InstanceId" in sirdata["SpotInstanceRequests"][0]):
                instance_id = sirdata["SpotInstanceRequests"][0]["InstanceId"]
                break
            time.sleep(30)
        data = {'Instances':[{'InstanceId': instance_id }]}
    else:
        data = execute_cli("run-instances", cmdparams)
        instance_id = data["Instances"][0]["InstanceId"]
    if tmp is not None:
        os.remove(tmp[1])
    print "Instance %s (%s) is active" % (name, instance_id)
    tag_resource(instance_id, {"Name": name})
    return data

def terminate_instances(instance_ids):
    return execute_cli("terminate-instances", ["--instance-ids"] + instance_ids)

def get_instance_metadata(instance_id, keys=["PrivateIpAddress", "PublicIpAddress"], values={}, waitTime=0):
    ip_address=None
    public_ip_address=None
    retvalues = [None]*len(keys)
    waitInterval = 10
    for i in range(0, waitTime, waitInterval):
      rundata = json.loads(subprocess.check_output(["aws", "ec2", "describe-instances", "--instance-ids", instance_id]))
      if 'Reservations' in rundata and len(rundata['Reservations']) == 1 and 'Instances' in rundata['Reservations'][0] and len(rundata['Reservations'][0]['Instances']) == 1:
        instance_data = rundata['Reservations'][0]['Instances'][0]
        retvalues = [ instance_data[k] if k in instance_data else None for k in keys ]
        matchedvalues = { k : instance_data[k] for k in values.keys() }
        if all(v is not None for v in retvalues) and (len(matchedvalues) == 0 or all(values[k](v) for k, v in matchedvalues)) and waitTime > 0: # Have all values been obtained?
            break
        else:
            time.sleep(waitInterval)
    return dict(zip(keys, retvalues))

def create_security_group(name, description):
    data = execute_cli("create-security-group", ["--group-name", name, "--description", description])
    if data is not None and 'GroupId' in data:
        # Allow intra-group communications between nodes
        execute_cli("authorize-security-group-ingress", ["--group-id", data['GroupId'], "--source-group", data['GroupId'], "--port", "0-65335", "--protocol", "tcp"])
        return data['GroupId']
    else:
        return None

def get_security_group(name):
    try:
        return execute_cli("describe-security-groups", ["--group-name", name])
    except Exception, e:
        return None

def delete_security_group(name):
    sg_data = get_security_group(name)
    if sg_data is not None and 'SecurityGroups' in sg_data and len(sg_data['SecurityGroups']) > 0:
        sgid = sg_data['SecurityGroups'][0]['GroupId']
        if 'IpPermissions' in sg_data['SecurityGroups'][0] and len(sg_data['SecurityGroups'][0]['IpPermissions']) > 0:
            execute_cli("revoke-security-group-ingress", ["--group-id", sgid, "--source-group", sgid, "--port", "0-65335", "--protocol", "tcp"])
        return execute_cli("delete-security-group", ["--group-id", sgid])
    else:
        return None

def get_ssh_command(hostname, identity_file=None, user=ssh_user, command=None):
    cmd = ["ssh"]
    if identity_file is not None:
        cmd.extend(("-i", identity_file))
        cmd.extend(("-o", r"StrictHostKeyChecking no", "-o" , "UserKnownHostsFile=/dev/null", "-q"))
    cmd.append("%s@%s" % (user, hostname))
    if command is not None:
        cmd.append(command)
    return cmd

def run_ssh_command(hostname, identity_file=None, user=ssh_user, command=None):
    return subprocess.check_output(get_ssh_command(hostname, identity_file, user, command))

def http_connect(url):
    for i in range(0, 30):
        try:
            resp = urllib2.urlopen(url, None, 300)
            html = resp.read()
            return html
        except urllib2.URLError, e:
            #print "Could not load Alfresco service page: %s" % (e)
            pass
        except IOError, e:
            # Assume Alfresco is down
            pass
        time.sleep(10)

def json_post(url, data, username, password, method="POST"):
    hdrs = {"Authorization": "Basic %s" % base64.encodestring('%s:%s' % (username, password)).replace('\n', ''), "Content-Type": "application/json"}
    request = urllib2.Request(url, json.dumps(data), hdrs)
    request.get_method = lambda: method
    return urllib2.urlopen(request)

def change_admin_password(alfurl, oldpass, newpass):
    username = "admin"
    postdata = {"oldpw": oldpass, "newpw": newpass}
    return json_post("%ss/api/person/changepassword/%s" % (alfurl, username), postdata, username, oldpass)

def generate_password(length):
    return ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for _ in range(length))

def usage():
    print __doc__

def get_identity_file(keyname):
    return expanduser("~/.ssh/%s.pem" % (keyname))

def run_create_instances(argv):

    default_ami=None
    alfresco_instance_type="m3.2xlarge"
    alfresco_user_data=None
    alfresco_device_mappings={"/dev/sdb":{"VolumeSize": 8, "DeleteOnTermination": True}}
    ami = None

    keyname="sync-key-01"
    security_groups=None
    security_group_ids=[]
    additional_security_groups = []

    # Max spot price, set to None if you don't want to use spot instances
    spot_price=None
    base_name="Sync-%s" % (int(time.time()))

    global _debug

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ['debug', 'base=', 'ami=', 'sync-build-num=', 'alfresco-version=', 'instance-type=', 'alfresco-user-data-file=', 'alfresco-device-mappings=', 'security-groups=', 'security-group_ids=', 'additional-security-groups=', 'keyname=', 'spot-price='])
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-d', '--debug']:
                _debug = 1
            elif opt in ['-b', '--base']:
                base_name = arg
            elif opt in ['--sync-build-num']:
                sync_build_num = arg
            elif opt in ['--alfresco-version']:
                alfresco_version = arg
            elif opt in ['--ami']:
                ami = arg
            elif opt in ['--instance-type']:
                alfresco_instance_type = arg
            elif opt in ['--alfresco-user-data-file']:
                alfresco_user_data = open(arg).read()
            elif opt in ['--alfresco-device-mappings']:
                print arg
                alfresco_device_mappings = json.loads(arg)
            elif opt in ['--security-groups']:
                security_groups = arg.split(',')
            elif opt in ['--security-groups-id']:
                security_group_ids = arg.split(',')
            elif opt in ['--additional-security-groups']:
                additional_security_groups = arg.split(',')
            elif opt in ['--keyname']:
                keyname = arg
            elif opt in ['--spot-price']:
                spot_price = float(arg)
    else:
        usage()
        sys.exit(1)

    # Look up AMI IDs using prefixes and suffixes if not specified already
    if sync_build_num is not None and alfresco_version is not None:
        if ami is None:
            ami_data = get_ami(sync_build_num, alfresco_version)
            if ami_data is not None:
                print 'Using AMI %s (%s)' % (ami_data['Name'], ami_data['ImageId'])
                ami = ami_data['ImageId']
            else:
                print 'Unable to locate AMI'
                sys.exit(1)

    # Fall back to defaults if still no AMI IDs
    if ami is None:
        ami = default_ami
 
    if ami is None:
        print "No suitable AMI could be found"
        sys.exit(1)

    if security_groups is None:
        sg_name = "Sync-%s" % (base_name)
        sg_id = create_security_group(sg_name, "Security group created for instances %s-Alfresco and %s-Pentaho" % (base_name, base_name))
        if sg_id is not None:
            security_groups = [sg_name]
            security_groups.extend(additional_security_groups)
        else:
            print 'Could not create security group'
            sys.exit(1)

    rundata = run_instance(ami, keyname=keyname, security_groups=security_groups, security_group_ids=security_group_ids, instance_type=alfresco_instance_type, user_data=alfresco_user_data, spot_price=spot_price, name="%s-Alfresco" % (base_name), device_mappings=alfresco_device_mappings)
    instance_id=rundata['Instances'][0]['InstanceId']
    tag_resource(instance_id, {"InstanceType": "Sync"})
    tag_resource(instance_id, {"SyncBaseName": base_name})

    metadata = get_instance_metadata(instance_id, waitTime=60)

    if (metadata["PrivateIpAddress"] is None or metadata["PublicIpAddress"] is None):
        print "IP addresses could not be found"
        sys.exit(1)

    print "Instance: %s" % (metadata)

    alfurl = "https://%s:9090/healthcheck" % (metadata["PublicIpAddress"])
    print "Waiting for Sync Service to start"
    resp = http_connect(alfurl)
    if resp is not None and len(resp) > 0:
        print "Sync service started"
    else:
        print "Count not connect to Sync service. Check that the security groups allow you to connect and that the server is up and running."
        sys.exit(1)

    alfurl = "http://%s:8080/alfresco/" % (metadata["PublicIpAddress"])
    print "Waiting for Alfresco to start"
    resp = http_connect(alfurl)
    if resp is not None and len(resp) > 0:
        print "Alfresco started"
    else:
        print "Count not connect to Alfresco. Check that the security groups allow you to connect and that the server is up and running."
        sys.exit(1)

    alfurl = "http://%s:8080/share/" % (metadata["PublicIpAddress"])
    print "Waiting for Share to start"
    resp = http_connect(alfurl)
    if resp is not None and len(resp) > 0:
        print "Share started"
    else:
        print "Count not connect to Share. Check that the security groups allow you to connect and that the server is up and running."
        sys.exit(1)

    newpass = generate_password(20)
    change_admin_password(alfurl, alfresco_admin_pw, newpass)
    print "Changed Alfresco admin password to %s" % (newpass)
    tag_resource(instance_id, {"AlfAdminPassword": newpass})

    if sync_build_num is not None:
        tag_resource(instance_id, {"SyncBuildNum": sync_build_num})

    if alfresco_version is not None:
        tag_resource(instance_id, {"AlfrescoVersion": alfresco_version})

    # Cannot create user before ActiveMQ is up :-(
    #system_user_data = {"userName": "pentaho-system", "firstName": "Pentaho", "lastName": "System", "email": "pentaho-system@alfresco.com", "password": generate_password(20), "groups": ["ANALYTICS_SYSTEM"]}
    #json_post("%ss/api/people" % (alfurl), system_user_data, "admin", newpass)
    #print "Created pentaho-system user %s" % (system_user_data["userName"])
    #json_post("%ss/api/people/admin" % (alfurl), {"addGroups": ["ANALYTICS_SYSTEM"]}, "admin", newpass, "PUT")
    #print "Updated groups for admin user"

#    print "Configuring Alfresco server via SSH (may take some time)"
#    identity_file=get_identity_file(keyname)
#    sed_cmd = "sudo resize2fs /dev/xvdb; sudo sed -i -e 's/pentaho.ba-server.url=http:\\/\\/127.0.0.1:8080\\/pentaho\\//pentaho.ba-server.url=http:\\/\\/%s:8080\\/pentaho\\//' -e 's/pentaho.ba-server.public.url=http:\\/\\/127.0.0.1:8080\\/pentaho\\//pentaho.ba-server.public.url=http:\\/\\/%s:8080\\/pentaho\\//' /opt/alfresco-5.0/tomcat/shared/classes/alfresco-global.properties && sudo /etc/init.d/alfresco restart" % (pentaho_data["PrivateIpAddress"], pentaho_data["PublicIpAddress"])
#    print run_ssh_command(alfresco_data["PublicIpAddress"], identity_file, ssh_user, sed_cmd)

def input(prompt):
    try:
            print '%s in 5 seconds...' % prompt
            foo = raw_input()
            return foo
    except:
            # timeout
            return

def run_terminate_instances(argv):

    base_name=None
    global _debug

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ['debug', 'base='])
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-d', '--debug']:
                _debug = 1
            elif opt in ['-b', '--base']:
                base_name = arg
    else:
        usage()
        sys.exit(1)

    if base_name is None:
        print "Must supply a base name of images to terminate via --base / -b"
        sys.exit(1)

    instances = get_instances({'tag:Name': [("%s-%s" % (base_name, suffix)) for suffix in ["Alfresco"]], 'instance-state-name': ACTIVE_INSTANCE_STATES})
    iids = [i['InstanceId'] for i in instances]

    if len(iids) > 0:
        print "Terminating instances %s" % (iids)
        time.sleep(2)
        terminate_instances(iids)
        print "Terminated instances %s" % (iids)
    else:
        print "No instances were found"

    # Remove security group, if auto-created
    sgname = "Sync-%s" % (base_name)
    sgdata = get_security_group(sgname)
    if sgdata is not None:
        count = 300
        print "Will wait for instances to shut down (max %s secs) before deleting %s" % (count, sgname)
        running_instances = 0
        while count > 0:
            # find any non-terminated instances using this group
            running_instances = len(get_instances({'instance.group-name': sgname, 'instance-state-name': ACTIVE_INSTANCE_STATES}))
            if running_instances == 0:
                break
            count = count - 1
            time.sleep(1)
        if running_instances == 0:
            del_res = delete_security_group(sgname)
            print "Deleted security group %s" % (sgname)
        else:
            print "Timed out waiting for instances to shut down"
    else:
        print "No security group was found"

def run_list_instances(argv):

    global _debug
    maxlen = lambda x: max([len(s) for s in x])
    firstelement = lambda l: l[0] if l else None
    gettag = lambda i, k: firstelement([ t['Value'] for t in i['Tags'] if t['Key'] == k ])
    matchtag = lambda i, k, v: any([ t['Key'] == k and t['Value'] == v for t in i['Tags']])
    gettype = lambda i: i.get('InstanceLifecycle') and "%s, %s" % (i['InstanceType'], i.get('InstanceLifecycle')) or i['InstanceType']
    getstate = lambda i: "%s, %s" % (i['State']['Name'], time2str(datetime.now(UTC())-dateutil.parser.parse(i.get('LaunchTime'))))

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ['debug', 'names='])
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-t']:
                tag = arg

    instances = get_instances({'tag:InstanceType': "Sync"})
    if len(instances) == 0:
        print "No environments found"
        sys.exit()

    basenames = sorted(set([ i for i in [ gettag(i, "SyncBaseName") for i in instances ] if i is not None ] ))
    labels = [ "%s (%s)" % (gettag(i, 'Name'), i['InstanceId']) for i in instances ]
    instancesbybn = [ filter(lambda x: matchtag(x, "SyncBaseName", name), instances) for name in basenames ]
    col0 = maxlen(basenames) + 2
    coln = max(maxlen(labels), maxlen(ALL_INSTANCE_STATES), len('xxx.xxx.xxx.xxx')) + 2
    for i in range(0, len(basenames)):
        print basenames[i].ljust(col0) + ''.join([("%s (%s)" % (gettag(inst, 'Name'), inst['InstanceId'])).ljust(coln) for inst in instancesbybn[i]])
        print ' '*col0 + ''.join([gettype(inst).ljust(coln) for inst in instancesbybn[i]])
        if any(['PublicIpAddress' in inst for inst in instancesbybn[i]]):
            print ' '*col0 + ''.join([inst.get('PublicIpAddress', '(none)').ljust(coln) for inst in instancesbybn[i]])
        print ' '*col0 + ''.join([getstate(inst).ljust(coln) for inst in instancesbybn[i]])
        print ' '*col0 + 'Sync Build Num: ' + ''.join([gettag(inst, "SyncBuildNum").ljust(coln) for inst in instancesbybn[i]])
        print ' '*col0 + 'Alfresco Version: ' + ''.join([gettag(inst, "AlfrescoVersion").ljust(coln) for inst in instancesbybn[i]])
        print ''

def run_list_amis(argv):

    global _debug
    maxlen = lambda x: max([len(s) for s in x])
    gettag = lambda i, k: [ t['Value'] for t in i['Tags'] if t['Key'] == k ][0]
    matchtag = lambda i, k, v: any([ t['Key'] == k and t['Value'] == v for t in i['Tags']])
    gettype = lambda i: i.get('InstanceLifecycle') and "%s, %s" % (i['InstanceType'], i.get('InstanceLifecycle')) or i['InstanceType']
    getstate = lambda i: "%s, %s" % (i['State']['Name'], time2str(datetime.now(UTC())-dateutil.parser.parse(i.get('LaunchTime'))))
    getname = lambda i: i['Name']
    getid = lambda i: i['ImageId']

    amis = []

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ['debug', 'names='])
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-t']:
                tag = arg

    data = execute_cli("describe-images", ["--filters", "Name=tag:AMIType,Values=Sync"])
    if 'Images' in data and len(data['Images']) > 0:
        amis = sorted(data['Images'], key=lambda i: i['Name'])

    if len(amis) == 0:
        print "No amis found"
        sys.exit()

    col0 = maxlen(amis) + 2
    for i in range(0, len(amis)):
        ami = amis[i]
        ami_id = getid(ami)
        name = getname(ami)
        alfrescoVersion = gettag(ami, "AlfrescoVersion")
        syncBuildNum = gettag(ami, "SyncBuildNum")
        print '%s (%s)' % (name.ljust(col0), ami_id)
        print '      Sync build ' + syncBuildNum
        print '      Alfresco version ' + alfrescoVersion
        print ''

def run_delete_amis(argv):

    global _debug
    names = []

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ['debug', 'names='])
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-d', '--debug']:
                _debug = 1
            elif opt in ['--names']:
                names = arg.split(',')

        if len(names) == 0:
            print "You must supply a comma-separated list of names to delete via --names="
            sys.exit(1)

        for bn in names:
            for ami in [ get_ami('reporting-%s-%s' % (prefix, bn)) for prefix in ('alfresco', 'alfresco-5.0', 'pentaho') ]:
                if ami is not None:
                    print 'De-registering %s' % (ami['ImageId'])
                    execute_cli('deregister-image', ('--image-id', ami['ImageId']))
                    if 'BlockDeviceMappings' in ami:
                        for dev in ami['BlockDeviceMappings']:
                            if 'Ebs' in dev and 'SnapshotId' in dev['Ebs']:
                                print 'Deleting %s' % (dev['Ebs']['SnapshotId'])
                                execute_cli('delete-snapshot', ('--snapshot-id', dev['Ebs']['SnapshotId']))
    else:
        usage()
        sys.exit(1)

def add_security_rule(argv):

    base_name=None
    group_id=None
    group_name=None
    source_ip=None
    ports='0-65535'

    global _debug

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ['debug', 'group-id=', 'group-name=', 'source-ip=', 'my-ip', 'port='])
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-d', '--debug']:
                _debug = 1
            elif opt in ['--group-id']:
                group_id = arg
            elif opt in ['--group-name']:
                group_name = arg
            elif opt in ['--source-ip']:
                source_ip = arg
            elif opt in ['--my-ip']:
                source_ip = http_connect('http://checkip.amazonaws.com/').strip()
            elif opt in ['--port']:
                ports = arg

        if group_id is None and group_name is None:
            print 'Either a group ID or group name must be specified via --group-id= or --group-name'
            sys.exit(1)
        if source_ip is None:
            print 'Source IP must be specified via --source-ip= or --my-ip'
            sys.exit(1)

        cidr = '%s/32' % (source_ip)
        params = []
        if group_id is not None:
            params.extend(('--group-id', group_id))
        if group_name is not None:
            params.extend(('--group-name', group_name))
        params.extend(('--protocol', 'tcp'))
        params.extend(('--port', ports))
        params.extend(('--cidr', cidr))
        execute_cli('authorize-security-group-ingress', params)

    else:
        usage()
        sys.exit(1)

def connect(argv):

    instance_id = None
    keyfile = None
    user = 'ubuntu'

    global _debug

    if len(argv) > 0:
        if argv[0] in ["--help", "-h"]:
            usage()
            sys.exit()
        try:
            opts, args = getopt.getopt(argv, 'db:',
                ('debug', 'instance=', 'key=', 'user='))
        except getopt.GetoptError, e:
            print e
            usage()
            sys.exit(1)

        for opt, arg in opts:
            if opt in ['-d', '--debug']:
                _debug = 1
            elif opt in ['--instance']:
                instance_id = arg
            elif opt in ['--key']:
                keyfile = arg
            elif opt in ['--user']:
                user = arg

        if instance_id is None:
            print 'An AMI must be specified via --instance=instance-id or --instance=instance-name'
            sys.exit(1)

        if instance_id.startswith('i-'):
            instances = get_instances({'instance-id': (instance_id)})
        else:
            instances = get_instances({'tag:Name': (instance_id)})

        if len(instances) == 0:
            print "No instance %s found" % (instance_id)
            sys.exit(1)

        ip_address = instances[0]['PublicDnsName']
        if keyfile is None:
            keyfile = get_identity_file(instances[0]['KeyName'])

        execute_shell(get_ssh_command(ip_address, keyfile, user))

    else:
        usage()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 1:
        usage()
        sys.exit(1)
    action = sys.argv[1]
    if action in ("create-instance"):
        run_create_instances(sys.argv[2:])
    elif action in ("terminate", "terminate-instances"):
        run_terminate_instances(sys.argv[2:])
    elif action in ("list-instances"):
        run_list_instances([])
    elif action in ("list-amis"):
        run_list_amis([])
    elif action in ("delete", "delete-images"):
        run_delete_amis(sys.argv[2:])
    elif action in ("add-rule", "add-security-rule"):
        add_security_rule(sys.argv[2:])
    elif action in ("connect"):
        connect(sys.argv[2:])
    else:
        print "Unknown action %s" % (action)
        usage()
        sys.exit(1)
