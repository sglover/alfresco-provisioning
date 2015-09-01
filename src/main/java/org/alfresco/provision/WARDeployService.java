/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.IOException;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.http.HttpEntity;
import org.apache.http.util.EntityUtils;
import org.codehaus.cargo.container.deployable.Deployable;
import org.codehaus.cargo.container.tomcat.Tomcat7xRemoteContainer;
import org.codehaus.cargo.container.tomcat.Tomcat7xRemoteDeployer;
import org.codehaus.cargo.container.tomcat.TomcatRuntimeConfiguration;
import org.codehaus.cargo.container.tomcat.TomcatWAR;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

/**
 * 
 * @author sglover
 *
 */
public class WARDeployService
{
	private static Log logger = LogFactory.getLog(WARDeployService.class.getName());

	private String tomcatServerHostname;
	private String tomcatServerPort;
	private String username;
	private String password;

	public WARDeployService(String tomcatServerHostname, String tomcatServerPort, String username, String password) throws Exception
	{
		this.tomcatServerHostname = tomcatServerHostname;
		this.tomcatServerPort = tomcatServerPort;
		this.username = username;
		this.password = password;
	}

	public void close()
	{
	}

    /**
     * Parses http response stream into a {@link JSONObject}.
     * 
     * @param stream Http response entity
     * @return {@link JSONObject} response
     */
    public JSONObject readStream(final HttpEntity entity)
    {
        String rsp = null;
        try
        {
            rsp = EntityUtils.toString(entity, "UTF-8");
        }
        catch (Throwable ex)
        {
            throw new RuntimeException("Failed to read HTTP entity stream.", ex);
        }
        finally
        {
            EntityUtils.consumeQuietly(entity);
        }
        try
        {
            JSONParser parser = new JSONParser();
            JSONObject result = (JSONObject) parser.parse(rsp);
            return result;
        }
        catch (Throwable e)
        {
            throw new RuntimeException(
                    "Failed to convert response to JSON: \n" +
                    "   Response: \r\n" + rsp,
                    e);
        }
    }

    public JSONArray readJSONArray(final HttpEntity entity)
    {
        String rsp = null;
        try
        {
            rsp = EntityUtils.toString(entity, "UTF-8");
        }
        catch (Throwable ex)
        {
            throw new RuntimeException("Failed to read HTTP entity stream.", ex);
        }
        finally
        {
            EntityUtils.consumeQuietly(entity);
        }
        try
        {
            JSONParser parser = new JSONParser();
            JSONArray result = (JSONArray) parser.parse(rsp);
            return result;
        }
        catch (Throwable e)
        {
            throw new RuntimeException(
                    "Failed to convert response to JSON: \n" +
                    "   Response: \r\n" + rsp,
                    e);
        }
    }

    private class WARDeployInfo
    {
    	private String warFilename;

    	public WARDeployInfo(String warFilename)
    	{
			this.warFilename = warFilename;
    	}

        void deploy() throws IOException
    	{
        	System.out.println("Deploying war " + warFilename + "...");
    		TomcatRuntimeConfiguration runtimeConfig = new TomcatRuntimeConfiguration();
    		runtimeConfig.setProperty("cargo.hostname", tomcatServerHostname);
    		runtimeConfig.setProperty("cargo.servlet.port", tomcatServerPort);
    		runtimeConfig.setProperty("cargo.remote.username", username);
    		runtimeConfig.setProperty("cargo.remote.password", password);
    		Tomcat7xRemoteDeployer deployer = new Tomcat7xRemoteDeployer(
    				new Tomcat7xRemoteContainer(runtimeConfig));
    		Deployable deployable = new TomcatWAR(warFilename);
    		deployer.redeploy(deployable);
    	}
    }

	public void deployWAR(String warFilename) throws IOException
	{
		WARDeployInfo deployInfo = new WARDeployInfo(warFilename);
		deployInfo.deploy();
	}
}
