/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import javax.management.Attribute;
import javax.management.AttributeNotFoundException;
import javax.management.InstanceNotFoundException;
import javax.management.InvalidAttributeValueException;
import javax.management.MBeanException;
import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;
import javax.management.ReflectionException;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL;

/**
 * 
 * @author sglover
 *
 */
public class JMXService
{
	private JMXConnector jmxc;

	public JMXService(String user, String password) throws IOException
	{
		connect(user, password);
	}

	private void connect(String user, String password) throws IOException
	{
		JMXServiceURL url = new JMXServiceURL("service:jmx:rmi:///jndi/rmi://localhost:50500/alfresco/jmxrmi");
		Map<String,Object> props=new HashMap<String,Object>();
		props.put(JMXConnector.CREDENTIALS, new String[] { user, password });
		this.jmxc = JMXConnectorFactory.connect(url, props);
	}

	public void setSyncServiceUri(String syncServiceUri)
			throws MalformedObjectNameException, InstanceNotFoundException, AttributeNotFoundException,
			InvalidAttributeValueException, MBeanException, ReflectionException, IOException
	{
		ObjectName objectName = new ObjectName("Alfresco:00=DeviceSync,Name=DeviceSyncProperties");
		Attribute attribute = new Attribute("sync.service.uri", syncServiceUri);
		jmxc.getMBeanServerConnection().setAttribute(objectName, attribute);
	}

	public void setBrokerUri(String brokerHostname)
			throws MalformedObjectNameException, InstanceNotFoundException, AttributeNotFoundException,
			InvalidAttributeValueException, MBeanException, ReflectionException, IOException
	{
		StringBuilder sb = new StringBuilder("failover:(tcp://");
		sb.append(brokerHostname);
		sb.append(":61616)?timeout=3000");
		String brokerUri = sb.toString();

		ObjectName objectName = new ObjectName("Alfresco:Category=Messaging,Type=Configuration,id1=default");
		Attribute attribute = new Attribute("messaging.broker.url", brokerUri);
		jmxc.getMBeanServerConnection().setAttribute(objectName, attribute);
	}
}
