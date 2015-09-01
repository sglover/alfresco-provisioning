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
import com.amazonaws.services.ec2.model.DescribeInstancesRequest;
import com.amazonaws.services.ec2.model.DescribeInstancesResult;
import com.amazonaws.services.ec2.model.Filter;
import com.amazonaws.services.ec2.model.Instance;
import com.amazonaws.services.ec2.model.Reservation;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.amazonaws.services.s3.model.S3Object;

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
		this.ec2 = Region.getRegion(Regions.EU_WEST_1)
				.createClient(AmazonEC2Client.class, credentials, null);
		this.cloudWatchClient = Region.getRegion(Regions.EU_WEST_1)
				.createClient(AmazonCloudWatchClient.class, credentials, null);
		this.s3 = Region.getRegion(Regions.EU_WEST_1)
				.createClient(AmazonS3Client.class, credentials, null);
	}

	private static AWSCredentialsProvider getCredentials(String accessKeyId, String secretAccessKey)
	{
    	AWSCredentialsProvider credentials = new StaticCredentialsProvider(new BasicAWSCredentials(accessKeyId, secretAccessKey));
    	return credentials;
	}

	private static AWSCredentialsProvider getCredentials()
	{
		AWSCredentialsProvider credentials = null;
	    try
	    {
	        credentials = new DefaultAWSCredentialsProviderChain();
	    }
	    catch (Exception e)
	    {
	        throw new AmazonClientException(
	                "Cannot load the credentials from the credential profiles file. " +
	                "Please make sure that your credentials file is at the correct " +
	                "location (~/.aws/credentials), and is in valid format.",
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
		for(Reservation reservation : reservations)
		{
			List<Instance> reservationInstances = reservation.getInstances();
			for(Instance instance : reservationInstances)
			{
				if(instance.getState().getCode() == 16)
				{
					runningInstances.add(instance);
				}
			}
		}

		if(runningInstances.size() == 0)
		{
			System.out.println("No running instances of " + serverName);
		}
		else if(runningInstances.size() > 1)
		{
			System.err.println("More than one running instance: ");
			for(Instance runningInstance : runningInstances)
			{
				System.err.print(runningInstance.getInstanceId());
				System.err.print(" ");
			}
			System.exit(1);
		}
		else
		{
			ret = runningInstances.get(0);
		}

		return ret;
	}

	private void ensureBucket()
	{
		if(!s3.doesBucketExist(bucketName))
		{
			s3.createBucket(bucketName);
		}
	}

	public void put(String key, String filename) throws IOException
	{
		ensureBucket();

		File f = new File(filename);

		s3.putObject(new PutObjectRequest(bucketName, key, f));
	}

	public void get(String key, String filename) throws IOException
	{
		S3Object object = s3.getObject(new GetObjectRequest(bucketName, key));
		InputStream in = new BufferedInputStream(object.getObjectContent());
		OutputStream out = new BufferedOutputStream(new FileOutputStream(filename));
		try
		{
			IOUtils.copy(in, out);
		}
		finally
		{
			if(in != null)
			{
				in.close();
			}
			if(out != null)
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
		String publicDNSName = (instance != null ? instance.getPublicDnsName(): null);
		return publicDNSName;
	}

	public String getInstanceId(String serverName)
	{
		Instance instance = getEC2Instance(serverName);
		return instance.getInstanceId();
	}

//	private static enum Command
//	{
//		GetServerIP, S3Put, S3Get;
//	};

//	private static AWSService getAWSService(String accessKey, String secret)
//	{
//		AWSService awsService;
//
//		if(accessKey != null && secret != null)
//		{
//			awsService = new AWSService(accessKey, secret);
//		}
//		else
//		{
//			awsService = new AWSService();
//		}
//
//		return awsService;
//	}
//
//	public static void main(String[] args)
//	{
//		java.util.logging.Logger.getLogger("com.amazonaws").setLevel(java.util.logging.Level.OFF);
//
//		int i = 0;
//		String accessKey = null;
//		String secret = null;
//		String serverName = null;
//		Command command = null;
//		String key = null;
//		String filename = null;
//
//		while(i < args.length && args[i].startsWith("-"))
//		{
//            String arg = args[i++];
//
//            for(int j = 1; j < arg.length(); j++)
//            {
//                char flag = arg.charAt(j);
//                switch (flag)
//                {
//                case 'a':
//                {
//                	accessKey = args[i++];
//                    break;
//                }
//                case 's':
//                {
//                	secret = args[i++];
//                    break;
//                }
//                case 'i':
//                {
//                	command = Command.GetServerIP;
//                	serverName = args[i++];
//                    break;
//                }
//                case 'g':
//                {
//                	command = Command.S3Get;
//    				key = args[i++];
//    				filename = args[i++];
//                    break;
//                }
//                case 'p':
//                {
//                	command = Command.S3Put;
//    				key = args[i++];
//    				filename = args[i++];
//                    break;
//                }
//                default:
//                    System.err.println("ParseCmdLine: illegal option " + flag);
//                    break;
//                }
//            }
//		}
//
//		switch(command)
//		{
//		case GetServerIP:
//		{
//			AWSService awsService = getAWSService(accessKey, secret);
//			System.out.println(awsService.getServerPrivateIP(serverName));
//			break;
//		}
//		case S3Put:
//		{
//			try
//			{
//				AWSService awsService = getAWSService(accessKey, secret);
//				awsService.put(key, filename);
//			}
//			catch(IOException e)
//			{
//				e.printStackTrace();
//			}
//			break;
//		}
//		case S3Get:
//		{
//			try
//			{
//				AWSService awsService = getAWSService(accessKey, secret);
//				awsService.get(key, filename);
//			}
//			catch(IOException e)
//			{
//				e.printStackTrace();
//			}
//			break;
//		}
//		default:
//		{
//			System.err.println("invalid command");
//			System.exit(1);
//		}
//		}
//	}

	public static class Metrics implements Comparable<Metrics>
	{
		public Calendar timestamp;
		public Map<String, Double> metrics = new HashMap<String, Double>();

		@Override
		public int compareTo(Metrics compare) {
			return (int) (timestamp.getTimeInMillis() - compare.timestamp.getTimeInMillis());
		}

		public void setMetric(String metricName, double value) {
			metrics.put(metricName, value);
		}

		public Set<String> getMetricNames() {
			return metrics.keySet();
		}

		public double getMetric(String metricName) {
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

			GetMetricStatisticsResult metricStatistics = cloudWatchClient.getMetricStatistics(getMetricRequest);
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
		}
		else
		{
			Collections.sort(sortedMeasureSets);
			return sortedMeasureSets.get(sortedMeasureSets.size() - 1);
		}
	}
}
