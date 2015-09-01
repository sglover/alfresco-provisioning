/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.util.Arrays;

import org.alfresco.provision.AWSService.Metrics;
import org.junit.Test;

import com.amazonaws.regions.Regions;

/**
 * 
 * @author sglover
 *
 */
public class AWSTest
{
	@Test
	public void test1() throws Exception
	{
		AWSService aws = new AWSService("AKIAJSUE6OVGVRIWGL4Q", "2LLOPmthRBpN3iuUR64ROQ44YWD6kNXayJOf42mu",
				Regions.EU_WEST_1);
		String instanceId = aws.getInstanceId("bmserveraws");
		Metrics metrics = aws.getMetrics(instanceId, Arrays.asList("CPUUtilization"));
		metrics.print();
	}
}
