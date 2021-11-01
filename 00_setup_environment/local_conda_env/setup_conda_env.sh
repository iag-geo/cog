#!/usr/bin/env bash

# --------------------------------------------------------------------------------------------------------------------

PYTHON_VERSION="3.9"

# --------------------------------------------------------------------------------------------------------------------

echo "-------------------------------------------------------------------------"
echo "Creating new Conda Environment 'cog'"
echo "-------------------------------------------------------------------------"

# update Conda platform
echo "y" | conda update conda

# WARNING - removes existing environment
conda env remove --name cog

# Create Conda environment
echo "y" | conda create -n cog python=${PYTHON_VERSION}

# activate and setup env
conda activate cog
conda config --env --add channels conda-forge
conda config --env --set channel_priority strict

# reactivate for env vars to take effect
conda activate cog

# install cog related packages
echo "y" | conda install -c conda-forge gdal rasterio[s3] rio-cogeo

## optional - install packages for vector data, Postgres & AWS use
#echo "y" | conda install -c conda-forge psycopg2 postgis shapely fiona requests boto3

# --------------------------
# extra bits
# --------------------------

## activate env
#conda activate cog

## shut down env
#conda deactivate

## delete env permanently
#conda env remove --name cog
