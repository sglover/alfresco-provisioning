/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import org.junit.Test;

public class Test1
{
	@Test
	public void test1()
	{
		String path = "/Company Home/Sites";
    	if(path.startsWith("/Company Home"))
    	{
    		path = path.substring("/Company Home".length());
    	}
    	System.out.println(path);
	}
	
	@Test
	public void test2()
	{
		System.out.println("a.b.c".replaceAll("\\.", "-"));
	}
}
