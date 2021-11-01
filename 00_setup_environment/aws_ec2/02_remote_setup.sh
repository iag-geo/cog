#!/usr/bin/env bash

# installs Python packages to enable converting images to Cloud Optimised GeoTIFFs (COGs)

# required to keep long running sessions active
sudo yum install -y tmux

# check if proxy server required
while getopts ":p:" opt; do
  case $opt in
  p)
    PROXY=$OPTARG
    ;;
  esac
done

if [ -n "${PROXY}" ];
  then
    export no_proxy="localhost,127.0.0.1,:11";
    export http_proxy="$PROXY";
    export https_proxy=${http_proxy};
    export HTTP_PROXY=${http_proxy};
    export HTTPS_PROXY=${http_proxy};
    export NO_PROXY=${no_proxy};

    echo "-------------------------------------------------------------------------";
    echo " Proxy is set to ${http_proxy}";
    echo "-------------------------------------------------------------------------";
fi

# Install Conda to create a Python 3.9 environment (AWS yum repos stop at Python 3.7)
echo "-------------------------------------------------------------------------"
echo " Installing Conda"
echo "-------------------------------------------------------------------------"

# download & install silently
curl -fSsl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
chmod +x Miniconda3-latest-Linux-x86_64.sh
sh Miniconda3-latest-Linux-x86_64.sh -b

# initialise Conda & reload bash environment
${HOME}/miniconda3/bin/conda init
source ${HOME}/.bashrc

# update Python packages
echo "y" | conda update conda

echo "-------------------------------------------------------------------------"
echo " Installing Python packages"
echo "-------------------------------------------------------------------------"

echo "y" | conda install -c conda-forge gdal rasterio[s3] rio-cogeo psycopg2 postgis shapely fiona requests boto3

# remove proxy if set
if [ -n "${PROXY}" ];
  then
    unset http_proxy
    unset HTTP_PROXY
    unset https_proxy
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY

    echo "-------------------------------------------------------------------------"
    echo " Proxy removed"
    echo "-------------------------------------------------------------------------"
    echo ""
fi

echo "-------------------------------------------------------------------------"
echo " Mount storage"
echo "-------------------------------------------------------------------------"

sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir /data
sudo mount /dev/nvme1n1 /data

sudo chown -R ec2-user:ec2-user /data
mkdir -p /data/tmp/cog

#echo "-------------------------------------------------------------------------"
#echo " Setup Postgres Database"
#echo "-------------------------------------------------------------------------"
#
## start postgres
#initdb -D postgres
#pg_ctl -D postgres -l logfile start
#
## increase memory usage and minimise logging (don't care if it crashes and we lose everything)
#psql -d postgres -c "ALTER SYSTEM SET max_parallel_workers = 64;"
#psql -d postgres -c "ALTER SYSTEM SET max_parallel_workers_per_gather = 64;"
#psql -d postgres -c "ALTER SYSTEM SET shared_buffers = '256GB';"
#psql -d postgres -c "ALTER SYSTEM SET wal_buffers = '2GB';"
#psql -d postgres -c "ALTER SYSTEM SET max_wal_size = '64GB';"
#psql -d postgres -c "ALTER SYSTEM SET wal_level = 'minimal';"
#psql -d postgres -c "ALTER SYSTEM SET max_wal_senders = 0;"
#psql -d postgres -c "ALTER SYSTEM SET archive_mode = 'off';"
#psql -d postgres -c "ALTER SYSTEM SET fsync = 'off';"
#psql -d postgres -c "ALTER SYSTEM SET full_page_writes = 'off';"
#psql -d postgres -c "ALTER SYSTEM SET synchronous_commit = 'off';"
#
#pg_ctl -D postgres restart
#
## create new database on mounted drive (not enough space on default drive)
#mkdir -p /data/postgres
#psql -d postgres -c "CREATE TABLESPACE dataspace OWNER \"ec2-user\" LOCATION '/data/postgres';"
#createdb --owner=ec2-user geo -D dataspace
#
## add PostGIS and create schema
#psql -d geo -c "create extension if not exists postgis;"
#psql -d geo -c "create schema if not exists cog;alter schema cog owner to \"ec2-user\";"

echo "-------------------------------------------------------------------------"
echo " Copy elevation data from S3"
echo "-------------------------------------------------------------------------"

# copy elevation files from S3
aws s3 sync s3://bushfire-rasters/geoscience_australia/1sec-dem /data/tmp/cog/
#aws s3 sync s3://bushfire-rasters/nsw_dcs_spatial_services/ /data/tmp/cog/
