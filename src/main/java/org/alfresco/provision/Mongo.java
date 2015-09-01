/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import org.alfresco.service.common.mongo.MongoDbFactory;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import com.mongodb.DB;
import com.mongodb.DBCollection;

/**
 * 
 * @author sglover
 *
 */
public class Mongo
{
	protected static final Log logger = LogFactory.getLog(Mongo.class);

	private DB db;

	public Mongo(String mongoURI, String dbName) throws Exception
	{
		MongoDbFactory factory = new MongoDbFactory();
	    factory.setDbName(dbName);
	    factory.setMongoURI(mongoURI);
		this.db = factory.createInstance();
	}

	private String collectionName(String alfrescoHost, String mirrorName)
	{
		StringBuilder builder = new StringBuilder("mirrors.");
		builder.append(alfrescoHost);
		builder.append(".");
		builder.append(mirrorName);
		return builder.toString();
	}

	public void renameMirror(String fromAlfrescoHost, String toAlfrescoHost, String mirror)
	{
		String fromCollectionName = collectionName(fromAlfrescoHost, mirror);
		String toCollectionName = collectionName(toAlfrescoHost, mirror);
		if(db.collectionExists(toCollectionName))
		{
			throw new RuntimeException(toCollectionName + " exists");
		}
		if(db.collectionExists(fromCollectionName))
		{
			DBCollection fromCollection = db.getCollection(fromCollectionName);
			logger.debug("Renaming " + fromCollectionName + " to " + toCollectionName);
			fromCollection.rename(toCollectionName);
		}
		else
		{
			throw new RuntimeException(fromCollectionName + " doesn't exist");
		}
	}

	private String eventsCollectionName(String testName, String testRunName)
	{
		String collectionName = testName + "." + testRunName + ".events";
		return collectionName;
	}

	private String resultsCollectionName(String testName, String testRunName)
	{
		String collectionName = testName + "." + testRunName + ".results";
		return collectionName;
	}

	private String sessionsCollectionName(String testName, String testRunName)
	{
		String collectionName = testName + "." + testRunName + ".sessions";
		return collectionName;
	}

	public void removeTestRunData(String testName, String testRunName)
	{
		{
			String collectionName = eventsCollectionName(testName, testRunName);
			if(db.collectionExists(collectionName))
			{
				DBCollection collection = db.getCollection(collectionName);
				collection.drop();
			}
		}

		{
			String collectionName = resultsCollectionName(testName, testRunName);
			if(db.collectionExists(collectionName))
			{
				DBCollection collection = db.getCollection(collectionName);
				collection.drop();
			}
		}

		{
			String collectionName = sessionsCollectionName(testName, testRunName);
			if(db.collectionExists(collectionName))
			{
				DBCollection collection = db.getCollection(collectionName);
				collection.drop();
			}
		}
	}

	private boolean isEmpty(String alfrescoHost, String mirror)
	{
		boolean isEmpty = true;

		String collectionName = collectionName(alfrescoHost, mirror);
		if(db.collectionExists(collectionName))
		{
			DBCollection collection = db.getCollection(collectionName);
			long count = collection.count();
			if(count > 0)
			{
				isEmpty = false;
			}
		}

		return isEmpty;
	}

	private boolean mirrorExists(String alfrescoHost, String mirror)
	{
		String collectionName = collectionName(alfrescoHost, mirror);
		return db.collectionExists(collectionName);
	}

	public void renameMirrors(String fromAlfrescoHost, String toAlfrescoHost)
	{
		if(mirrorExists(fromAlfrescoHost, "users"))
		{
			if(!isEmpty(toAlfrescoHost, "users"))
			{
				throw new RuntimeException(toAlfrescoHost + ".users is not empty");
			}
			renameMirror(fromAlfrescoHost, toAlfrescoHost, "users");
		}

		if(mirrorExists(fromAlfrescoHost, "sites"))
		{
			if(!isEmpty(toAlfrescoHost, "sites"))
			{
				throw new RuntimeException(toAlfrescoHost + ".sites is not empty");
			}
			renameMirror(fromAlfrescoHost, toAlfrescoHost, "sites");
		}

		if(mirrorExists(fromAlfrescoHost, "siteMembers"))
		{
			if(!isEmpty(toAlfrescoHost, "siteMembers"))
			{
				throw new RuntimeException(toAlfrescoHost + ".siteMembers is not empty");
			}
			renameMirror(fromAlfrescoHost, toAlfrescoHost, "siteMembers");
		}

		if(mirrorExists(fromAlfrescoHost, "filefolders"))
		{
			if(!isEmpty(toAlfrescoHost, "filefolders"))
			{
				throw new RuntimeException(toAlfrescoHost + ".filefolders is not empty");
			}
			renameMirror(fromAlfrescoHost, toAlfrescoHost, "filefolders");
		}
	}
}
