/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.IOException;
import java.io.UnsupportedEncodingException;

import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPut;
import org.apache.http.conn.HttpClientConnectionManager;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager;
import org.apache.http.message.BasicHeader;
import org.apache.http.protocol.HTTP;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

/**
 * 
 * @author sglover
 *
 */
public class BMService
{
	public static final String UTF_8_ENCODING = "UTF-8";
	public static final String MIME_TYPE_JSON = "application/json";

	private String hostname;
	private CloseableHttpClient client;

	public BMService(String hostname)
	{
		this.hostname = hostname;
		HttpClientConnectionManager poolingConnManager = new PoolingHttpClientConnectionManager();
		this.client = HttpClients.custom().setConnectionManager(poolingConnManager).build();
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

    /**
     * Extract the "data" JSON-object from the method's response.
     * 
     * @param method the method containing the response
     * @return the "data" object. Returns null if response is not JSON or no data-object is present.
     */
    public Object getDataFromResponse(HttpEntity entity, String propertyName)
    {
        Object result = null;
        JSONObject response = readStream(entity);
        // Extract object for "data" property
        result = response.get(propertyName);
        return result;
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

    public JSONObject getTestProperty(String testName, String propertyName) throws IOException
    {
    	CloseableHttpResponse httpResponse = null;
    	JSONObject response = null;

    	try
    	{
			String url = "http://" + hostname + ":9080/alfresco-benchmark-server/api/v1/tests/"
					+ testName + "/props/"
					+ propertyName;
//			System.out.println("Getting property " + testName + ", " + propertyName + ", " + url);
			HttpGet getProperty = new HttpGet(url);
	        httpResponse = client.execute(getProperty);
	        StatusLine status = httpResponse.getStatusLine();
	        // Expecting "OK" status
	        if(status.getStatusCode() == HttpStatus.SC_OK)
	        {
		        HttpEntity entity = httpResponse.getEntity();
		        response = readStream(entity);
	        }
	        else if(status.getStatusCode() == HttpStatus.SC_NOT_FOUND)
	        {
				System.err.println("Property " + propertyName + " for test " + testName + " does not exist");
	        }
	        else
	        {
	        	System.err.println("Unexpected response " + httpResponse.toString());
	        }

	        return response;
    	}
    	finally
    	{
    		httpResponse.close();
    	}
    }

	@SuppressWarnings("unchecked")
    public void setTestProperty(String testName, String propertyName, Object propertyValue) throws IOException
	{
		System.out.println();
		JSONObject json = getTestProperty(testName, propertyName);
		if(json != null)
		{
			Long currentVersion = (Long)json.get("version");
	
			CloseableHttpResponse httpResponse = null;
	
			try
			{
				String url = "http://" + hostname + ":9080/alfresco-benchmark-server/api/v1/tests/"
						+ testName + "/props/"
						+ propertyName;
		
		        JSONObject putJson = new JSONObject();
		        putJson.put("version", currentVersion);
		        putJson.put("value", propertyValue);
		
		        HttpPut updateProperty = new HttpPut(url);
		        StringEntity content = setMessageBody(putJson);
		        updateProperty.setEntity(content);
		
		        httpResponse = client.execute(updateProperty);
		
		        StatusLine status = httpResponse.getStatusLine();
		        // Expecting "OK" status
		        if(status.getStatusCode() == HttpStatus.SC_NOT_FOUND)
		        {
					System.err.println("Property does not exist");
		        }
		        else if(status.getStatusCode() != HttpStatus.SC_OK)
		        {
		        	System.err.println("Unexpected response " + httpResponse.toString());
		        }
			}
			finally
			{
				httpResponse.close();
			}
		}
		else
		{
			System.err.println("Property " + propertyName + " for test " + testName + " does not exist");
		}
	}
}
