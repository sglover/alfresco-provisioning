/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import org.junit.Before;
import org.junit.Test;

/**
 * 
 * @author sglover
 *
 */
public class TestMongo
{
	private Mongo mongo;

	@Before
	public void before() throws Exception
	{
		mongo = new Mongo("mongodb://ec2-54-155-203-161.eu-west-1.compute.amazonaws.com:27017",
				"bm20-data");
	}

	@Test
	public void testRenameMirrors() throws Exception
	{
		mongo.renameMirrors("ec2-54-195-225-30.eu-west-1.compute.amazonaws.com",
				"ec2-54-155-4-171.eu-west-1.compute.amazonaws.com");
	}
}
