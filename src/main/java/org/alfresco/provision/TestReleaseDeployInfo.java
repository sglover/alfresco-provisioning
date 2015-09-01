/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.util.LinkedList;
import java.util.List;

import org.alfresco.bm.test.mongo.MongoTestDAO;
import org.alfresco.service.common.mongo.MongoDbFactory;
import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.ParseException;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.conn.HttpClientConnectionManager;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager;
import org.apache.http.message.BasicHeader;
import org.apache.http.protocol.HTTP;
import org.apache.http.util.EntityUtils;
import org.codehaus.cargo.container.deployable.Deployable;
import org.codehaus.cargo.container.deployer.DeployableMonitor;
import org.codehaus.cargo.container.deployer.DeployableMonitorListener;
import org.codehaus.cargo.container.tomcat.Tomcat7xRemoteContainer;
import org.codehaus.cargo.container.tomcat.Tomcat7xRemoteDeployer;
import org.codehaus.cargo.container.tomcat.TomcatRuntimeConfiguration;
import org.codehaus.cargo.container.tomcat.TomcatWAR;
import org.codehaus.cargo.module.JarArchive;
import org.codehaus.cargo.module.JarArchiveIo;
import org.codehaus.cargo.util.log.Logger;
import org.jdom.JDOMException;
import org.json.simple.JSONObject;

import com.mongodb.DB;
import com.mongodb.DBCursor;
import com.mongodb.DBObject;

/**
 * 
 * @author sglover
 *
 */
public class TestReleaseDeployInfo
{
	public static final String UTF_8_ENCODING = "UTF-8";
	public static final String MIME_TYPE_JSON = "application/json";

	private String release;
	private int schema;
	private String warFilename;
	private String bmServerHostname;
	private String bmServerPort;
	private String bmDriverHostname;
	private String bmDriverPort;
	private String username;
	private String password;
	private String testName;
	private String testDescription;

	private CloseableHttpClient client;
	private MongoTestDAO testDAO;

	public TestReleaseDeployInfo(String bmDriverHostname, String bmDriverPort, String username, String password,
			String warFilename, String bmServerHostname, String bmServerPort, String testName, String testDescription)
					throws Exception
	{
		int idx1 = warFilename.lastIndexOf("/");
		int idx2 = warFilename.lastIndexOf(".");
		this.release = warFilename.substring(idx1 + 1, idx2);
		this.warFilename = warFilename;
		this.bmDriverHostname = bmDriverHostname;
		this.bmDriverPort = bmDriverPort;
		this.username = username;
		this.password = password;
		this.bmServerHostname = bmServerHostname;
		this.bmServerPort = bmServerPort;
		this.testName = testName;
		this.testDescription = testDescription;
		this.schema = getSchema();

		HttpClientConnectionManager poolingConnManager = new PoolingHttpClientConnectionManager();
		this.client = HttpClients.custom().setConnectionManager(poolingConnManager).build();

        final MongoDbFactory factory = new MongoDbFactory();
        factory.setMongoURI("mongodb://" + bmServerHostname + ":27017");
        factory.setDbName("bm20-config");
        final DB db = factory.createInstance();
		this.testDAO = new MongoTestDAO(db);
	}

	public String getRelease()
	{
		return release;
	}


	public String getWarFilename()
	{
		return warFilename;
	}


	public String getBmServerHostname()
	{
		return bmServerHostname;
	}


	public String getBmServerPort()
	{
		return bmServerPort;
	}


	public String getBmDriverHostname()
	{
		return bmDriverHostname;
	}


	public String getBmDriverPort()
	{
		return bmDriverPort;
	}


	public String getUsername()
	{
		return username;
	}


	public String getPassword()
	{
		return password;
	}


	public String getTestName()
	{
		return testName;
	}


	public String getTestDescription()
	{
		return testDescription;
	}

	

	private String testsURL()
	{
		StringBuilder sb = new StringBuilder("http://");
		sb.append(bmServerHostname);
		sb.append(":");
		sb.append(bmServerPort);
		sb.append("/alfresco-benchmark-server/api/v1/tests");
		return sb.toString();
	}

	private String testURL()
	{
		StringBuilder sb = new StringBuilder("http://");
		sb.append(bmServerHostname);
		sb.append(":");
		sb.append(bmServerPort);
		sb.append("/alfresco-benchmark-server/api/v1/tests/");
		sb.append(testName);
		return sb.toString();
	}
	
	private String privateEC2IPURL()
	{
		return "http://instance-data/latest/meta-data/local-ipv4";
	}

	boolean isDeployed() throws IOException
	{
		boolean isDeployed = isDeployed(release, schema);
		return isDeployed;
	}

    /**
     * Populate HTTP message call with given content.
     * 
     * @param content String content
     * @return {@link StringEntity} content.
     * @throws UnsupportedEncodingException if unsupported
     */
    public StringEntity setMessageBody(final String content) throws UnsupportedEncodingException
    {
        if (content == null || content.isEmpty()) throw new UnsupportedOperationException("Content is required.");
        return new StringEntity(content, UTF_8_ENCODING);
    }

    /**
     * Populate HTTP message call with given content.
     * 
     * @param json {@link JSONObject} content
     * @return {@link StringEntity} content.
     * @throws UnsupportedEncodingException if unsupported
     */
    public StringEntity setMessageBody(final JSONObject json) throws UnsupportedEncodingException
    {
        if (json == null || json.toString().isEmpty())
            throw new UnsupportedOperationException("JSON Content is required.");

        StringEntity se = setMessageBody(json.toString());
        se.setContentType(new BasicHeader(HTTP.CONTENT_TYPE, MIME_TYPE_JSON));
        return se;
    }

    private String getEC2PrivateIP() throws ParseException, IOException
    {
    	String ec2PrivateIP = null;

		String url = privateEC2IPURL();
		HttpGet get = new HttpGet(url);
		CloseableHttpResponse httpResponse = client.execute(get);
		try
		{
			StatusLine status = httpResponse.getStatusLine();
			// Expecting "OK" status
			if(status.getStatusCode() == HttpStatus.SC_OK)
			{
				HttpEntity entity = httpResponse.getEntity();
				ec2PrivateIP = EntityUtils.toString(entity);
				System.out.println("ec2PrivateIP = " + ec2PrivateIP);
			}
			else
			{
				throw new RuntimeException("Unable to get test " + testName + ", " + httpResponse + ", " + status);
			}
		}
		finally
		{
			if(httpResponse != null)
			{
				httpResponse.close();
			}
		}

		return ec2PrivateIP;
    }

    private boolean isDeployed(String release, int schema) throws ParseException, IOException
	{
		boolean isDeployed = false;

		String ec2PrivateIP = getEC2PrivateIP();

		DBCursor cursor = testDAO.getDrivers(release, schema, true);
		try
		{
			for(DBObject dbObject : cursor)
			{
				String releasePrivateDNS = (String)dbObject.get("ipAddress");
				if(releasePrivateDNS.equals(ec2PrivateIP))
				{
					isDeployed = true;
				}
			}

			System.out.println("isDeployed " + ec2PrivateIP + ", " + release + ", " + schema + ", " + isDeployed);
		}
		finally
		{
			if(cursor != null)
			{
				cursor.close();
			}
		}

        return isDeployed;
	}

	@SuppressWarnings("unchecked")
	private void createTest() throws IOException
	{
		JSONObject body = new JSONObject();
		body.put("name", testName);
		body.put("description", testDescription);
		body.put("release", release);
		body.put("schema", schema);
		StringEntity entity = setMessageBody(body);

		String url = testsURL();
		HttpPost post = new HttpPost(url);
		post.setEntity(entity);
		CloseableHttpResponse httpResponse = client.execute(post);
		try
		{
			StatusLine status = httpResponse.getStatusLine();
			// Expecting "OK" status
			if(status.getStatusCode() == HttpStatus.SC_OK)
			{
				System.out.println("Test " + testName + " created");
			}
			else if(status.getStatusCode() == HttpStatus.SC_CONFLICT)
			{
				// already created
				System.out.println("Test " + testName + " already created");
			}
			else
			{
				throw new RuntimeException("Unable to create test " + testName + ", " + httpResponse + ", " + status);
			}
		}
		finally
		{
			if(httpResponse != null)
			{
				httpResponse.close();
			}
		}
	}

	public void deleteTest() throws IOException
	{
		StringBuilder sb = new StringBuilder(testURL());
		sb.append("?clean=false");
		String url = sb.toString();

		HttpDelete delete = new HttpDelete(url);
		CloseableHttpResponse httpResponse = client.execute(delete);
		try
		{
			StatusLine status = httpResponse.getStatusLine();
			// Expecting "OK" status
			if(status.getStatusCode() == HttpStatus.SC_NO_CONTENT)
			{
				System.out.println("Test " + testName + " deleted");
			}
			else
			{
				throw new RuntimeException("Unable to delete test " + testName + ", " + httpResponse + ", " + status);
			}
		}
		finally
		{
			if(httpResponse != null)
			{
				httpResponse.close();
			}
		}
	}

	private boolean testExists() throws IOException
	{
		boolean testExists = false;

		String url = testURL();
		HttpGet get = new HttpGet(url);
		CloseableHttpResponse httpResponse = client.execute(get);
		try
		{
			StatusLine status = httpResponse.getStatusLine();
			// Expecting "OK" status
			if(status.getStatusCode() == HttpStatus.SC_OK)
			{
				System.out.println("Test " + testName + " exists");
				testExists = true;
			}
			else if(status.getStatusCode() == HttpStatus.SC_NOT_FOUND)
			{
				System.out.println("Test " + testName + " does not exist");
				testExists = false;
			}
			else
			{
				throw new RuntimeException("Unable to get test " + testName + ", " + httpResponse + ", " + status);
			}
		}
		finally
		{
			if(httpResponse != null)
			{
				httpResponse.close();
			}
		}

		return testExists;
	}

	public int getSchema() throws IOException, JDOMException
	{
		int schema = -1;

		BufferedReader reader = null;
		try
		{
			JarArchive jarArchive = JarArchiveIo.open(new File(warFilename));
			InputStream in = jarArchive.getResource("WEB-INF/classes/config/startup/app.properties");
			if(in == null)
			{
				throw new RuntimeException("Unable to determine app.schema for test WAR, no app.properties found");
			}
			else
			{
				reader = new BufferedReader(new InputStreamReader(in));
				String line = null;
				while((line = reader.readLine()) != null)
				{
					line = line.trim();
					if(line.toLowerCase().startsWith("app.schema"))
					{
						int idx = line.indexOf("=");
						if(idx == -1)
						{
							throw new RuntimeException("Unable to determine app.schema for test WAR");
						}
						else
						{
							Integer i = Integer.valueOf(line.substring(idx + 1));
							if(i == null)
							{
								throw new RuntimeException("Unable to determine app.schema for test WAR");
							}
							schema = i.intValue();
							break;
						}
					}
				}
			}
		}
		finally
		{
			if (reader != null)
			{
				reader.close();
			}
		}

		return schema;
	}

	public void deploy() throws IOException
	{
		if(isDeployed())
		{
			System.out.println("Release " + release + " " + schema + " already deployed");
		}
		else
		{
			if(testExists())
			{
				deleteTest();
			}

			System.out.println("Deploying war " + warFilename + ", release " + release + " schema " + schema + "...");
			TomcatRuntimeConfiguration runtimeConfig = new TomcatRuntimeConfiguration();
			runtimeConfig.setProperty("cargo.hostname", bmDriverHostname);
			runtimeConfig.setProperty("cargo.servlet.port", bmDriverPort);
			runtimeConfig.setProperty("cargo.remote.username", username);
			runtimeConfig.setProperty("cargo.remote.password", password);
			Tomcat7xRemoteDeployer deployer = new Tomcat7xRemoteDeployer(
					new Tomcat7xRemoteContainer(runtimeConfig));
			Deployable deployable = new TomcatWAR(warFilename);
			DeployableMonitor monitor = new DeployableMonitorImpl(release, schema);
			deployer.redeploy(deployable, monitor);
			System.out.println("Release " + release + " " + schema + " deployed");
		}

		if(!testExists())
		{
			createTest();
		}
	}

    private class DeployableMonitorImpl implements DeployableMonitor
	{
    	private List<DeployableMonitorListener> listeners = new LinkedList<>();

    	private String release;
    	private int schema;

    	DeployableMonitorImpl(String release, int schema)
    	{
    		this.schema = schema;
    		this.release = release;
    	}

		/**
		 * {@inheritDoc}
		 * @see org.codehaus.cargo.container.deployer.DeployableMonitor#getDeployableName()
		 */
		public String getDeployableName()
		{
			return "";
		}

		/**
		 * {@inheritDoc}
		 * @see DeployableMonitor#registerListener(DeployableMonitorListener)
		 */
		public void registerListener(DeployableMonitorListener listener)
		{
			this.listeners.add(listener);
		}

		/**
		 * @see DeployableMonitor#monitor()
		 */
		public void monitor()
		{
    		boolean isDeployed;

            try
            {
	            isDeployed = isDeployed(release, schema);
            }
            catch (ParseException e)
            {
            	isDeployed = false;
            }
            catch (IOException e)
            {
            	isDeployed = false;
            }

			for (DeployableMonitorListener listener : listeners)
			{
				if (isDeployed)
				{
					listener.deployed();
				}
				else
				{
					listener.undeployed();
				}
			}
		}

		/**
		 * {@inheritDoc}
		 * @see DeployableMonitor#getTimeout()
		 */
		public long getTimeout()
		{
			return 60000;
		}

		@Override
        public Logger getLogger()
        {
            return null;
        }

		@Override
        public void setLogger(Logger arg0)
        {
        }
	}
}
