/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.IOException;

/**
 * 
 * @author sglover
 *
 */
public class ActiveMQCommand
{
	public static void main(String[] args)
	{
		ActiveMQService activeMQService = new ActiveMQService("localhost", 8161);
		switch(args[0])
		{
		case "removeQueues":
		{
			try
			{
				String queueNamesStr = args[1];
				String[] queueNames = queueNamesStr.split(",");
				activeMQService.removeQueues(queueNames);
			}
			catch(IOException e)
			{
				e.printStackTrace();
				System.exit(1);
			}
			break;
		}
		case "removeTopics":
		{
			try
			{
				String topicNamesStr = args[1];
				String[] topicNames = topicNamesStr.split(",");
				activeMQService.removeTopics(topicNames);
			}
			catch(IOException e)
			{
				e.printStackTrace();
				System.exit(1);
			}
			break;
		}
		default:
			System.exit(1);
		}
	}
}
