/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import org.junit.Test;

/**
 * 
 * @author sglover
 *
 */
public class RemoveTestRun
{
	@Test
	public void test1() throws Exception
	{
		Mongo mongo = new Mongo("mongodb://ec2-54-74-220-57.eu-west-1.compute.amazonaws.com:27017", "bm20-data");
		mongo.removeTestRunData("DeviceSync", "DeviceSync1");
	}
}
