/*
 * Copyright 2015 Alfresco Software, Ltd.  All rights reserved.
 *
 * License rights for this program may be obtained from Alfresco Software, Ltd. 
 * pursuant to a written agreement and any use of this program without such an 
 * agreement is prohibited. 
 */
package org.alfresco.provision;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Reader;
import java.io.Writer;
import java.util.Map;

import org.yaml.snakeyaml.Yaml;

/**
 * 
 * @author sglover
 *
 */
public class YAMLService
{
    public YAMLService()
    {
    }

    @SuppressWarnings({ "rawtypes", "unchecked" })
    private void update(Map config, String key, String value)
    {
        int idx = key.indexOf(".");
        if(idx != -1)
        {
            String k = key.substring(0, idx);
            String remainder = key.substring(idx + 1);
            Object o = config.get(k);
            if(o == null)
            {
                if(remainder == null || remainder.isEmpty())
                {
                    config.put(key, value);
                }
                else
                {
                    System.err.println("Error updating key " + key + " with value " + value);
                    throw new IllegalArgumentException("Error updating key " + key + " with value " + value);
                }
            }
            if(!(o instanceof Map))
            {
                throw new IllegalArgumentException();
            }
            Map c = (Map)o;
            update(c, remainder, value);
        }
        else
        {
            config.put(key, value);
        }
    }

    @SuppressWarnings({ "rawtypes", "unchecked" })
    public void setLogger(Map config, String loggerKey, String level)
    {
        Object o = config.get("logging");
        if(o == null || !(o instanceof Map))
        {
            throw new RuntimeException("No logging defined");
        }
        else
        {
            Map logging = (Map)o;
            Object o1 = logging.get("loggers");
            if(o1 == null || !(o1 instanceof Map))
            {
                throw new RuntimeException("No loggers defined");
            }
            else
            {
                Map map = (Map)o1;
                map.put(loggerKey, level);
            }
        }
    }

    @SuppressWarnings({ "rawtypes" })
    public void update(String filename, String key, String value) throws IOException
    {
        Yaml yaml = new Yaml();
        Map config = null;
        try(Reader reader = new InputStreamReader(new FileInputStream(filename)))
        {
            config = (Map)yaml.load(reader);
            update(config, key, value);
        }

        if(config != null)
        {
            try(Writer writer = new OutputStreamWriter(new FileOutputStream(filename)))
            {
                yaml.dump(config, writer);
            }
        }
    }

    @SuppressWarnings({ "rawtypes" })
    public void setLogger(String filename, String loggerKey, String level) throws IOException
    {
        Yaml yaml = new Yaml();
        Map config = null;
        try(Reader reader = new InputStreamReader(new FileInputStream(filename)))
        {
            config = (Map)yaml.load(reader);
            setLogger(config, loggerKey, level);
        }

        if(config != null)
        {
            try(Writer writer = new OutputStreamWriter(new FileOutputStream(filename)))
            {
                yaml.dump(config, writer);
            }
        }
    }

    public static void main(String[] args) throws IOException
    {
        new YAMLService().update(
                "/Users/sglover/dev/sync/HEAD/service-synchronization/service-synchronization-dropwizard/target/config.yml",
                "sync.authentication.basicAuthUrl",
                "poo");
    }
}
