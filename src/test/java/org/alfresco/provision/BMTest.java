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
public class BMTest
{
	@Test
	public void test1() throws Exception
	{
		BMService bmService = new BMService("ec2-54-78-199-208.eu-west-1.compute.amazonaws.com");
		bmService.setTestProperty("DeviceSync", "mirror.subscribers", "mirrors.sync1.subscribers");
		bmService.setTestProperty("DeviceSync", "users.collectionName", "mirrors.sync1.users");
		bmService.setTestProperty("DeviceSync", "mirror.sites", "mirrors.sync1.sites");
		bmService.setTestProperty("DeviceSync", "mirror.siteMembers", "mirrors.sync1.siteMembers");
		bmService.setTestProperty("DeviceSync", "mirror.subscriptions", "mirrors.sync1.subscriptions");
		bmService.setTestProperty("DeviceSync", "mirror.syncs", "mirrors.sync1.syncs");
	}
}
