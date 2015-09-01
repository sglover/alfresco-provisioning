#!/bin/bash

psql -c "CREATE USER alfresco WITH PASSWORD 'admin';"
createdb -O alfresco alfresco

# DB - Postgres
echo "Updating Postgres"
sed -i -e "s/#work_mem = 4MB/work_mem = 8MB/" /etc/postgresql/9.4/main/postgresql.conf
sed -i -e "s/shared_buffers = 128MB/shared_buffers = 5GB/" /etc/postgresql/9.4/main/postgresql.conf
sed -i -e "s/#temp_buffers = 8MB/temp_buffers = 8MB/" /etc/postgresql/9.4/main/postgresql.conf
sed -i -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/9.4/main/postgresql.conf
sed -i -e "s/max_connections = 100/max_connections = 410/" /etc/postgresql/9.4/main/postgresql.conf
sed -i -e "s/#checkpoint_segments = 3/checkpoint_segments = 20/" /etc/postgresql/9.4/main/postgresql.conf
echo "hostssl all             all             109.146.214.125/32      password" | tee -a /etc/postgresql/9.4/main/pg_hba.conf
echo "Done"

echo "Restarting Postgres"
/etc/init.d/postgresql restart
echo "Done"