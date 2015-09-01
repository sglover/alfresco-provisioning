/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

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

import com.amazonaws.auth.AWSCredentials;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.regions.Region;
import com.amazonaws.regions.Regions;
import com.amazonaws.services.cloudwatch.AmazonCloudWatchClient;
import com.amazonaws.services.cloudwatch.model.Datapoint;
import com.amazonaws.services.cloudwatch.model.Dimension;
import com.amazonaws.services.cloudwatch.model.GetMetricStatisticsRequest;
import com.amazonaws.services.cloudwatch.model.GetMetricStatisticsResult;

/**
 * 
 * @author sglover
 *
 */
public class CloudWatchMonitor
{
	private String instanceId;

	private AmazonCloudWatchClient cloudWatchClient;

	public CloudWatchMonitor(String instanceId, String accessKeyId, String secretAccesskey)
	{
		AWSCredentials awsCredentials = new BasicAWSCredentials(accessKeyId, secretAccesskey);
		cloudWatchClient = new AmazonCloudWatchClient(awsCredentials);
		cloudWatchClient.setRegion(Region.getRegion(Regions.EU_WEST_1));
		this.instanceId = instanceId;
	}

	public static class MeasureSet implements Comparable<MeasureSet>
	{
		public Calendar timestamp;
		public Map<String, Double> measures = new HashMap<String, Double>();

		@Override
		public int compareTo(MeasureSet compare) {
			return (int) (timestamp.getTimeInMillis() - compare.timestamp.getTimeInMillis());
		}

		public void setMeasure(String measureName, double value) {
			measures.put(measureName, value);
		}

		public Set<String> getMeasureNames() {
			return measures.keySet();
		}

		public double getMeasure(String measureName) {
			return measures.get(measureName);
		}

		public void print()
		{
			System.out.println(String.format("%1$tY-%1$tm-%1$td %1tH:%1$tM:%1$tS", timestamp));
			for (String measureName : getMeasureNames()) {
				System.out.println(measureName + ": " + getMeasure(measureName));
			}
		}
	}

	public MeasureSet retrieveMeasureSet(List<String> measureNames)
	{
		  GetMetricStatisticsRequest getMetricRequest = new GetMetricStatisticsRequest();
		  getMetricRequest.setNamespace("AWS/EC2");
		  getMetricRequest.setPeriod(60);
		  List<String> stats = new LinkedList<>();
		  stats.add("Average");
		  getMetricRequest.setStatistics(stats);
		  List<Dimension> dimensions = new LinkedList<>();
		  Dimension dimension = new Dimension();
		  dimensions.add(dimension.withName("InstanceId").withValue(instanceId));
//		  getMetricRequest.setDimensions(dimensions);
		  GregorianCalendar calendar = new GregorianCalendar(TimeZone.getTimeZone("UTC"));
		  calendar.add(GregorianCalendar.SECOND, -1 * calendar.get(GregorianCalendar.SECOND));
		  getMetricRequest.setEndTime(calendar.getTime());
		  calendar.add(GregorianCalendar.MINUTE, -600);
		  getMetricRequest.setStartTime(calendar.getTime());

//		  DimensionFilter dimFilter = new DimensionFilter();
//		  dimFilter.withName("InstanceId").withValue(instanceId);
//		  List<DimensionFilter> dimFilters = new LinkedList<>();
//		  dimFilters.add(dimFilter);
//		  ListMetricsRequest listMetricsRequest = new ListMetricsRequest();
//		  listMetricsRequest.setDimensions(dimFilters);
//		  ListMetricsResult metrics = cloudWatchClient.listMetrics();
//		  for(Metric metric : metrics.getMetrics())
//		  {
//			  System.out.println("IM" + metric);
//		  }

//		  getMetricRequest.setNamespace("AWS/EC2");
//		  getMetricRequest.setMetricName("CPUUtilization");
////		  Dimension dimension = new Dimension();
////		  dimensions.add(dimension.withName("InstanceId").withValue(instanceId));
//		  getMetricRequest.setDimensions(dimensions);
//		  GetMetricStatisticsResult metricStatistics = cloudWatchClient.getMetricStatistics(getMetricRequest);
//		  Map<Long, MeasureSet> measureSets = new HashMap<>();
//		  List<Datapoint> datapoints = metricStatistics.getDatapoints();
//		  for (Datapoint point : datapoints) {
//			  Calendar cal = new GregorianCalendar();
//			  cal.setTime(point.getTimestamp());
////			  cal.add(GregorianCalendar.HOUR, timeOffset);
//			  MeasureSet measureSet = measureSets.get(cal.getTimeInMillis());
//			  if (measureSet == null) {
//				  measureSet = new MeasureSet();
//				  measureSet.timestamp = cal;
//				  measureSets.put(cal.getTimeInMillis(), measureSet);
//			  }
//			  measureSet.setMeasure("CPUUtilization", point.getAverage());
//		  }

		  Map<Long, MeasureSet> measureSets = new HashMap<>();
		  for (String measureName : measureNames)
		  {
			  getMetricRequest.setNamespace("AWS/EC2");
			  getMetricRequest.setMetricName(measureName);
			  Dimension dimension1 = new Dimension();
			  dimension1.withName("InstanceId").withValue(instanceId);
			  getMetricRequest.setDimensions(Arrays.asList(dimension1));

			  GetMetricStatisticsResult metricStatistics = cloudWatchClient.getMetricStatistics(getMetricRequest);
			  List<Datapoint> datapoints = metricStatistics.getDatapoints();
			  for (Datapoint point : datapoints) {
				  Calendar cal = new GregorianCalendar();
				  cal.setTime(point.getTimestamp());
//				  cal.add(GregorianCalendar.HOUR, timeOffset);
				  MeasureSet measureSet = measureSets.get(cal.getTimeInMillis());
				  if (measureSet == null) {
					  measureSet = new MeasureSet();
					  measureSet.timestamp = cal;
					  measureSets.put(cal.getTimeInMillis(), measureSet);
				  }
				  measureSet.setMeasure(measureName, point.getAverage());
			  }
		  }

		  List<MeasureSet> sortedMeasureSets = new ArrayList<>(measureSets.values());
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