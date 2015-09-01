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
public class ActiveMQServiceTest
{
	@Test
	public void test1() throws Exception
	{
		ActiveMQService activeMQService = new ActiveMQService("localhost", 8161);
//		activeMQService.removeTopic("alfresco.repo.events.nodes");
		activeMQService.removeQueue("alfresco.sync.changes.request");
	}
}
