/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.util.Map;

import org.junit.Test;
import org.yaml.snakeyaml.Yaml;

/**
 * 
 * @author sglover
 *
 */
public class YAMLTest
{
    @SuppressWarnings("rawtypes")
    @Test
    public void test1() throws Exception
    {
        YAMLService yamlService = new YAMLService();
        Yaml yaml = new Yaml();
        InputStream in = getClass().getResourceAsStream("/config.yml");
        try(Reader reader = new InputStreamReader(in))
        {
            Map config = (Map)yaml.load(reader);
            yamlService.setLogger(config, "org.alfresco.stuff", "DEBUG");
            System.out.println(config);
        }
    }
}
