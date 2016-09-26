/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Collections;
import java.util.GregorianCalendar;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;

import org.apache.commons.io.IOUtils;

import com.amazonaws.AmazonClientException;
import com.amazonaws.auth.AWSCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.auth.DefaultAWSCredentialsProviderChain;
import com.amazonaws.internal.StaticCredentialsProvider;
import com.amazonaws.regions.Region;
import com.amazonaws.regions.Regions;
import com.amazonaws.services.cloudwatch.AmazonCloudWatchClient;
import com.amazonaws.services.cloudwatch.model.Datapoint;
import com.amazonaws.services.cloudwatch.model.Dimension;
import com.amazonaws.services.cloudwatch.model.GetMetricStatisticsRequest;
import com.amazonaws.services.cloudwatch.model.GetMetricStatisticsResult;
import com.amazonaws.services.ec2.AmazonEC2;
import com.amazonaws.services.ec2.AmazonEC2Client;
import com.amazonaws.services.ec2.model.CreateTagsRequest;
import com.amazonaws.services.ec2.model.DescribeInstancesRequest;
import com.amazonaws.services.ec2.model.DescribeInstancesResult;
import com.amazonaws.services.ec2.model.Filter;
import com.amazonaws.services.ec2.model.Instance;
import com.amazonaws.services.ec2.model.Reservation;
import com.amazonaws.services.ec2.model.RunInstancesRequest;
import com.amazonaws.services.ec2.model.RunInstancesResult;
import com.amazonaws.services.ec2.model.Tag;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.util.Base64;

/**
 * 
 * @author sglover
 *
 */
public class AWSService
{
    private AmazonEC2 ec2;
    private AmazonS3 s3;
    private String bucketName = "sglover";

    private String cassandraAMI = "ami-50520e27";
    private String elasticSearchAMI = "ami-7cb6e00b";

    private AmazonCloudWatchClient cloudWatchClient;

    public AWSService(String accessKeyId, String secretAccessKey, Regions region)
    {
        this(getCredentials(accessKeyId, secretAccessKey), region);
    }

    public AWSService(Regions region)
    {
        this(getCredentials(), region);
    }

    private AWSService(AWSCredentialsProvider credentials, Regions region)
    {
        this.ec2 = Region.getRegion(Regions.EU_WEST_1).createClient(AmazonEC2Client.class,
                credentials, null);
        this.cloudWatchClient = Region.getRegion(Regions.EU_WEST_1)
                .createClient(AmazonCloudWatchClient.class, credentials, null);
        this.s3 = Region.getRegion(Regions.EU_WEST_1).createClient(AmazonS3Client.class,
                credentials, null);
    }

    private static AWSCredentialsProvider getCredentials(String accessKeyId, String secretAccessKey)
    {
        AWSCredentialsProvider credentials = new StaticCredentialsProvider(
                new BasicAWSCredentials(accessKeyId, secretAccessKey));
        return credentials;
    }

    private static AWSCredentialsProvider getCredentials()
    {
        AWSCredentialsProvider credentials = null;
        try
        {
            credentials = new DefaultAWSCredentialsProviderChain();
        } catch (Exception e)
        {
            throw new AmazonClientException(
                    "Cannot load the credentials from the credential profiles file. "
                            + "Please make sure that your credentials file is at the correct "
                            + "location (~/.aws/credentials), and is in valid format.",
                    e);
        }

        return credentials;
    }

    private Instance getEC2Instance(String serverName)
    {
        Instance ret = null;

        List<Instance> runningInstances = new LinkedList<>();

        Filter filter = new Filter("tag:Name", Arrays.asList(serverName));
        DescribeInstancesRequest r = new DescribeInstancesRequest().withFilters(filter);
        DescribeInstancesResult result = ec2.describeInstances(r);
        List<Reservation> reservations = result.getReservations();
        for (Reservation reservation : reservations)
        {
            List<Instance> reservationInstances = reservation.getInstances();
            for (Instance instance : reservationInstances)
            {
                if (instance.getState().getCode() == 16)
                {
                    runningInstances.add(instance);
                }
            }
        }

        if (runningInstances.size() == 0)
        {
            System.err.println("No running instances of " + serverName);
        } else if (runningInstances.size() > 1)
        {
            System.err.println("More than one running instance: ");
            for (Instance runningInstance : runningInstances)
            {
                System.err.print(runningInstance.getInstanceId());
                System.err.print(" ");
            }
            System.exit(1);
        } else
        {
            ret = runningInstances.get(0);
        }

        return ret;
    }

    private void ensureBucket()
    {
        if (!s3.doesBucketExist(bucketName))
        {
            s3.createBucket(bucketName);
        }
    }

    public void put(String key, String filename, boolean overwrite) throws IOException
    {
        ensureBucket();

        File f = new File(filename);

        if(!s3.doesObjectExist(bucketName, key) && overwrite)
        {
            s3.putObject(new PutObjectRequest(bucketName, key, f));
        }
    }

    public void get(String key, String filename) throws IOException
    {
        S3Object object = s3.getObject(new GetObjectRequest(bucketName, key));
        InputStream in = new BufferedInputStream(object.getObjectContent());
        OutputStream out = new BufferedOutputStream(new FileOutputStream(filename));
        try
        {
            IOUtils.copy(in, out);
        } finally
        {
            if (in != null)
            {
                in.close();
            }
            if (out != null)
            {
                out.close();
            }
        }
    }

    public String getServerPrivateIP(String serverName)
    {
        Instance instance = getEC2Instance(serverName);
        String privateIpAddress = (instance != null ? instance.getPrivateIpAddress() : null);
        return privateIpAddress;
    }

    public String getServerPublicHostname(String serverName)
    {
        Instance instance = getEC2Instance(serverName);
        String publicDNSName = (instance != null ? instance.getPublicDnsName() : null);
        return publicDNSName;
    }

    public String getInstanceId(String serverName)
    {
        Instance instance = getEC2Instance(serverName);
        return instance.getInstanceId();
    }

    public static class Metrics implements Comparable<Metrics>
    {
        public Calendar timestamp;
        public Map<String, Double> metrics = new HashMap<String, Double>();

        @Override
        public int compareTo(Metrics compare)
        {
            return (int) (timestamp.getTimeInMillis() - compare.timestamp.getTimeInMillis());
        }

        public void setMetric(String metricName, double value)
        {
            metrics.put(metricName, value);
        }

        public Set<String> getMetricNames()
        {
            return metrics.keySet();
        }

        public double getMetric(String metricName)
        {
            return metrics.get(metricName);
        }

        public void print()
        {
            System.out.println(String.format("%1$tY-%1$tm-%1$td %1tH:%1$tM:%1$tS", timestamp));
            for (String measureName : getMetricNames())
            {
                System.out.println(measureName + ": " + getMetric(measureName));
            }
        }
    }

    public Metrics getMetrics(String instanceId, List<String> measureNames)
    {
        GetMetricStatisticsRequest getMetricRequest = new GetMetricStatisticsRequest();
        getMetricRequest.setNamespace("AWS/EC2");
        getMetricRequest.setPeriod(60);
        List<String> stats = new LinkedList<>();
        stats.add("Average");
        getMetricRequest.setStatistics(stats);

        getMetricRequest.setNamespace("AWS/EC2");

        Dimension dimension = new Dimension();
        dimension.withName("InstanceId").withValue(instanceId);
        getMetricRequest.setDimensions(Arrays.asList(dimension));

        GregorianCalendar calendar = new GregorianCalendar(TimeZone.getTimeZone("UTC"));
        calendar.add(GregorianCalendar.SECOND, -1 * calendar.get(GregorianCalendar.SECOND));
        getMetricRequest.setEndTime(calendar.getTime());
        calendar.add(GregorianCalendar.MINUTE, -10);
        getMetricRequest.setStartTime(calendar.getTime());

        Map<Long, Metrics> measureSets = new HashMap<>();
        for (String measureName : measureNames)
        {
            getMetricRequest.setMetricName(measureName);

            GetMetricStatisticsResult metricStatistics = cloudWatchClient
                    .getMetricStatistics(getMetricRequest);
            List<Datapoint> datapoints = metricStatistics.getDatapoints();
            for (Datapoint point : datapoints)
            {
                Calendar cal = new GregorianCalendar();
                cal.setTime(point.getTimestamp());
                Metrics measureSet = measureSets.get(cal.getTimeInMillis());
                if (measureSet == null)
                {
                    measureSet = new Metrics();
                    measureSet.timestamp = cal;
                    measureSets.put(cal.getTimeInMillis(), measureSet);
                }
                measureSet.setMetric(measureName, point.getAverage());
            }
        }

        List<Metrics> sortedMeasureSets = new ArrayList<>(measureSets.values());
        if (sortedMeasureSets.size() == 0)
        {
            return null;
        } else
        {
            Collections.sort(sortedMeasureSets);
            return sortedMeasureSets.get(sortedMeasureSets.size() - 1);
        }
    }

    private String getUserData(String[] lines)
    {
        String str = new String(Base64.encode(join(lines, "\n").getBytes()));
        return str;
    }

    private String join(String[] strings, String delimiter)
    {
        StringBuilder builder = new StringBuilder();
        for (String string : strings)
        {
            builder.append(string);
            builder.append(delimiter);
        }

        return builder.toString();
    }

    //"m3.xlarge"
    //"subnet-14819763"
    // sglover
    //"sg-922b95f6"
    //sync
    //3
    public List<Instance> createCassandraCluster(String type, String subnetId, String key,
            String securityGroup, String clusterName, int numNodes)
    {
        RunInstancesRequest runInstancesRequest = new RunInstancesRequest();
        runInstancesRequest.withImageId(cassandraAMI).withInstanceType(type)
                .withMinCount(1).withMaxCount(3).withKeyName(key)
                .withSubnetId(subnetId).withSecurityGroupIds(securityGroup)
                .withUserData(getUserData(new String[] {
                        "--clustername " + clusterName, "--totalnodes " + numNodes, "--version community" }));
        RunInstancesResult runInstancesResult = ec2.runInstances(runInstancesRequest);
        List<Instance> instances = runInstancesResult.getReservation().getInstances();
        int idx = 1;
        for (Instance instance : instances)
        {
            CreateTagsRequest createTagsRequest = new CreateTagsRequest();
            createTagsRequest.withResources(instance.getInstanceId()) //
                    .withTags(new Tag("Name", "sg-cassandra-" + idx));
            ec2.createTags(createTagsRequest);

            idx++;
        }

        return instances;
    }

    public Instance createElasticSearchInstance(String type, String subnetId, String key,
            String securityGroup)
    {
        Instance instance = null;

        RunInstancesRequest runInstancesRequest = new RunInstancesRequest();
        runInstancesRequest.withImageId(elasticSearchAMI)
                .withInstanceType(type)
                .withMinCount(1).withMaxCount(1)
                .withKeyName(key)
                .withSubnetId(subnetId)
                .withSecurityGroupIds(securityGroup);
        RunInstancesResult runInstancesResult = ec2.runInstances(runInstancesRequest);
        List<Instance> instances = runInstancesResult.getReservation().getInstances();
        if(instances.size() != 1)
        {
            System.err.println("Expected 1 instance " + instances.size());
        }
        else
        {
            instance = instances.get(0);
            CreateTagsRequest createTagsRequest = new CreateTagsRequest();
            createTagsRequest.withResources(instance.getInstanceId()) //
                    .withTags(new Tag("Name", "sg-es"));
            ec2.createTags(createTagsRequest);
        }

        return instance;
    }
}
