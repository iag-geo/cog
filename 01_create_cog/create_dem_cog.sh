#!/usr/bin/env bash

mkdir -p /data/dem/cog
cd /data/dem

# download and unzip SRTM 1 second (~30m) resolution smoothed elevation data for Australia
curl -O https://elevation-direct-downloads.s3-ap-southeast-2.amazonaws.com/1sec-dem/70715.zip --progress-bar
unzip -o 70715.zip
rm 70715.zip

# convert elevation data from ESRI Grid to Cloud Optimised GeoTIFF
gdal_translate ./aac46307-fce8-449d-e044-00144fdd4fa6/hdr.adf ./cog/srtm_1sec_dem_s.tif -of COG -co BIGTIFF=YES -co COMPRESS=DEFLATE -co NUM_THREADS=ALL_CPUS
gdal_translate ./aac46307-fce8-449d-e044-00144fdd4fa6/hdr.adf ./cog/srtm_1sec_dem_s_non_cog.tif -of GTiff -co TILED=YES -co BIGTIFF=YES -co COMPRESS=DEFLATE -co NUM_THREADS=ALL_CPUS
gdal_translate ./aac46307-fce8-449d-e044-00144fdd4fa6/hdr.adf ./cog/srtm_1sec_dem_s_lzw.tif -of COG -co BIGTIFF=YES -co COMPRESS=LZW -co NUM_THREADS=ALL_CPUS
gdal_translate ./aac46307-fce8-449d-e044-00144fdd4fa6/hdr.adf ./cog/srtm_1sec_dem_s_zstd.tif -of COG -co BIGTIFF=YES -co COMPRESS=ZSTD -co NUM_THREADS=ALL_CPUS

## create slope data
#gdaldem slope ./aac46307-fce8-449d-e044-00144fdd4fa6/hdr.adf ./cog/srtm_1sec_slope.tif -s 111120 -of COG -co BIGTIFF=YES -co COMPRESS=DEFLATE -co NUM_THREADS=ALL_CPUS
#
## create aspect data
#gdaldem aspect ./aac46307-fce8-449d-e044-00144fdd4fa6/hdr.adf ./cog/srtm_1sec_aspect.tif -zero_for_flat -of COG -co BIGTIFF=YES -co COMPRESS=DEFLATE -co NUM_THREADS=ALL_CPUS

## copy COG files to S3
#aws s3 sync /data/tmp/cog s3://bushfire-rasters/geoscience_australia/1sec-dem/ --exclude "*" --include "*.tif"
