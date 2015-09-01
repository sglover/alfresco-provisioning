/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.IOException;

import javax.management.AttributeNotFoundException;
import javax.management.InstanceNotFoundException;
import javax.management.InvalidAttributeValueException;
import javax.management.MBeanException;
import javax.management.MalformedObjectNameException;
import javax.management.ReflectionException;

import com.amazonaws.regions.Regions;

/**
 * 
 * @author sglover
 *
 */
public class Main
{
	private static AWSService getAWSService(String accessKey, String secret)
	{
		AWSService awsService;
		Regions region = Regions.EU_WEST_1;

		if(accessKey != null && secret != null)
		{
			awsService = new AWSService(accessKey, secret, region);
		}
		else
		{
			awsService = new AWSService(region);
		}

		return awsService;
	}

	private static JMXService getJMXService(String user, String password) throws IOException
	{
		JMXService jmxService = new JMXService(user, password);
		return jmxService;
	}

	private static BMService getBMService(String hostname)
	{
		BMService bmService = new BMService(hostname);
		return bmService;
	}

	public static void main(String[] args)
	{
		java.util.logging.Logger.getLogger("com.amazonaws").setLevel(java.util.logging.Level.OFF);

		int i = 0;

		while(i < args.length && args[i].startsWith("-"))
		{
            String arg = args[i++].substring(1);
            switch(arg)
            {
            case "pip":
            {
            	String accessKey = args[i++];
            	String secret = args[i++];
            	String serverName = args[i++];
    			AWSService awsService = getAWSService(accessKey, secret);
    			String ip = awsService.getServerPrivateIP(serverName);
    			if(ip == null)
    			{
    				System.exit(1);
    			}
    			else
    			{
    				System.out.println(ip);
    				System.exit(0);
    			}
                break;
            }
            case "hostname":
            {
            	String accessKey = args[i++];
            	String secret = args[i++];
            	String serverName = args[i++];
    			AWSService awsService = getAWSService(accessKey, secret);
    			String hostname = awsService.getServerPublicHostname(serverName);
    			if(hostname == null)
    			{
    				System.exit(1);
    			}
    			else
    			{
    				System.out.println(hostname);
    				System.exit(0);
    			}
                break;
            }
            case "s3g":
            {
            	String accessKey = args[i++];
            	String secret = args[i++];
            	String key = args[i++];
            	String filename = args[i++];
				try
				{
					AWSService awsService = getAWSService(accessKey, secret);
					awsService.get(key, filename);
				}
				catch(IOException e)
				{
					e.printStackTrace();
				}
				break;
            }
            case "s3p":
            {
            	String accessKey = args[i++];
            	String secret = args[i++];
            	String key = args[i++];
            	String filename = args[i++];
				try
				{
					AWSService awsService = getAWSService(accessKey, secret);
					awsService.put(key, filename);
				}
				catch(IOException e)
				{
					e.printStackTrace();
				}
                break;
            }
            case "syncuri":
            {
            	String jmxUser = args[i++];
            	String jmxPass = args[i++];
            	String syncServiceUri = args[i++];
				try
				{
					JMXService jmxService = getJMXService(jmxUser, jmxPass);
					jmxService.setSyncServiceUri(syncServiceUri);
				}
				catch(IOException | MalformedObjectNameException | InstanceNotFoundException |
						AttributeNotFoundException | InvalidAttributeValueException | MBeanException | ReflectionException e)
				{
					e.printStackTrace();
				}
                break;
            }
            case "brokeruri":
            {
            	String jmxUser = args[i++];
            	String jmxPass = args[i++];
            	String brokerHostname = args[i++];
				try
				{
					JMXService jmxService = getJMXService(jmxUser, jmxPass);
					jmxService.setBrokerUri(brokerHostname);
				}
				catch(IOException | MalformedObjectNameException | InstanceNotFoundException |
						AttributeNotFoundException | InvalidAttributeValueException | MBeanException | ReflectionException e)
				{
					e.printStackTrace();
				}
                break;
            }
            case "setBMProperty":
            {
            	String bmServerName = args[i++];
            	String testName = args[i++];
            	String propertyName = args[i++];
            	String propertyValue = args[i++];
    			BMService bmService = getBMService(bmServerName);
    			try
    			{
    				bmService.setTestProperty(testName, propertyName, propertyValue);
    			}
    			catch(IOException e)
    			{
    				e.printStackTrace();
    			}
            	break;
            }
            case "updateYaml":
            {
            	String yamlFileName = args[i++];
            	String propertyName = args[i++];
            	String newPropertyValue = args[i++];
            	YAMLService service = new YAMLService();
            	try
            	{
            		service.update(yamlFileName, propertyName, newPropertyValue);
    			}
    			catch(IOException e)
    			{
    				e.printStackTrace();
    			}
            	break;
            }
            case "setLogger":
            {
                String yamlFileName = args[i++];
                String loggerKey = args[i++];
                String level = args[i++];
                YAMLService service = new YAMLService();
                try
                {
                    service.setLogger(yamlFileName, loggerKey, level);
                }
                catch(IOException e)
                {
                    e.printStackTrace();
                }
                break;
            }
            case "deployTestWAR":
            {
            	String bmServerHostname = args[i++];
            	String bmServerPort = args[i++];
            	String bmDriverHostname = args[i++];
            	String bmDriverPort = args[i++];
            	String username = args[i++];
            	String password = args[i++];
            	String warFilename = args[i++];
            	String testName = args[i++];
            	String testDescription = args[i++];

            	try
            	{
	            	DeployTestService service = new DeployTestService(bmDriverHostname, bmDriverPort, username, password,
	            			bmServerHostname, bmServerPort);
	            	service.deployWAR(warFilename, testName, testDescription);
            	}
				catch(Exception e)
				{
					e.printStackTrace();
					System.exit(1);
				}
            	break;
            }
            case "deployWAR":
            {
            	String tomcatHostname = args[i++];
            	String tomcatPort = args[i++];
            	String username = args[i++];
            	String password = args[i++];
            	String warFilename = args[i++];

            	try
            	{
	            	WARDeployService service = new WARDeployService(tomcatHostname, tomcatPort, username, password);
	            	service.deployWAR(warFilename);
            	}
				catch(Exception e)
				{
					e.printStackTrace();
					System.exit(1);
				}
            	break;
            }
            default:
                System.err.println("ParseCmdLine: illegal option " + arg);
                break;
            }
        }

//		switch(command)
//		{
//		case GetBMServerPrivateIP:
//		{
//			AWSService awsService = getAWSService(accessKey, secret);
//			String ip = awsService.getServerPrivateIP(serverName);
//			if(ip == null)
//			{
//				System.exit(1);
//			}
//			else
//			{
//				System.out.println(ip);
//				System.exit(0);
//			}
//			break;
//		}
//		case GetBMServerPublicDNS:
//		{
//			AWSService awsService = getAWSService(accessKey, secret);
//			String hostname = awsService.getServerPublicHostname(serverName);
//			if(hostname == null)
//			{
//				System.exit(1);
//			}
//			else
//			{
//				System.out.println(hostname);
//				System.exit(0);
//			}
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
//		case UpdateSyncServiceUri:
//		{
//			try
//			{
//				JMXService jmxService = getJMXService(jmxUser, jmxPass);
//				jmxService.setSyncServiceUri(syncServiceUri);
//			}
//			catch(IOException | MalformedObjectNameException | InstanceNotFoundException |
//					AttributeNotFoundException | InvalidAttributeValueException | MBeanException | ReflectionException e)
//			{
//				e.printStackTrace();
//			}
//			break;
//		}
//		case SetBMProperty:
//		{
//			BMService bmService = getBMService(bmServerName);
//			try
//			{
//				bmService.setTestProperty(testName, propertyName, propertyValue);
//			} catch(IOException e)
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
	}
}
