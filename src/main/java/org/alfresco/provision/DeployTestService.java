/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

/**
 * 
 * @author sglover
 *
 */
public class DeployTestService
{
	public static final String UTF_8_ENCODING = "UTF-8";
	public static final String MIME_TYPE_JSON = "application/json";

	private static Log logger = LogFactory.getLog(DeployTestService.class.getName());

	private String bmServerHostname;
	private String bmServerPort;
	private String bmDriverHostname;
	private String bmDriverPort;
	private String username;
	private String password;

	public DeployTestService(String bmDriverHostname, String bmDriverPort, String username, String password,
			String bmServerHostname, String bmServerPort) throws Exception
	{
		this.bmDriverHostname = bmDriverHostname;
		this.bmDriverPort = bmDriverPort;
		this.username = username;
		this.password = password;
		this.bmServerHostname = bmServerHostname;
		this.bmServerPort = bmServerPort;
	}

	public void close()
	{
	}

	public void deployWAR(String warFilename, String testName, String testDescription) throws Exception
	{
		TestReleaseDeployInfo deployInfo = new TestReleaseDeployInfo(bmDriverHostname, bmDriverPort, username, password, warFilename,
				bmServerHostname, bmServerPort, testName, testDescription);
		deployInfo.deploy();
	}
}
