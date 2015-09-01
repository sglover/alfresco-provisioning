/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import static org.junit.Assert.assertEquals;

import org.junit.Before;
import org.junit.Test;

/**
 * 
 * @author sglover
 *
 */
public class DeployTest
{
	@Before
	public void before() throws Exception
	{
	}

	@Test
	public void test1() throws Exception
	{
		String warFileName = "/Users/sglover/dev/sync/HEAD/service-sync-bundle/vagrant/cache/alfresco-benchmark-tests-device-sync-1.0-SNAPSHOT.war";
		TestReleaseDeployInfo deployInfo = new TestReleaseDeployInfo("ec2-54-78-212-104.eu-west-1.compute.amazonaws.com", "9080",
				"admin", "admin", warFileName, "ec2-54-78-172-238.eu-west-1.compute.amazonaws.com", "9080",
				"DeviceSync", "DeviceSync");
		assertEquals(28, deployInfo.getSchema());
	}

	@Test
	public void test2() throws Exception
	{
		String warFileName = "/Users/sglover/dev/sync/HEAD/service-sync-bundle/vagrant/cache/alfresco-benchmark-tests-device-sync-1.0-SNAPSHOT.war";
		TestReleaseDeployInfo deployInfo = new TestReleaseDeployInfo("ec2-54-78-212-104.eu-west-1.compute.amazonaws.com", "9080",
				"admin", "admin", warFileName, "ec2-54-78-172-238.eu-west-1.compute.amazonaws.com", "9080",
				"DeviceSync", "DeviceSync");
		deployInfo.deleteTest();
	}
}
