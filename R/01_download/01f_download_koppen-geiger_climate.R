# ==============================================================================
# Script Name:    01f_download_koppen-geiger_climate.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-04-15
# Last Updated:   2025-06-18      # split climate raster data downloads
#
# Purpose: Download, processes, and prepare Köppen Geiger climate rasters

# Data URLs:
# -   Köppen Geiger climate -- gewww.gloh2o.org/koppen/
#
# Workflow Summary:
# 1.   Download zipped archives, extract data and organize raster data
# 2.   Reproject rasters to a common CRS (US Albers Equal Area – EPSG:5070) 
#        for spatial analysis.
#
# Output:
# -   Validated climate rasters projected to a common CRS
#
# Dependencies:
# -   tidyverse::dplyr -   Data manipulation
# -   fs               -   File system operations
# -   glue             -   Formats strings
# -   here             -   Locates files relative to a project root
# -   httr             -   Tools for working with URLs and HTTP
# -   sf               -   Support for simple feature access, a standardized way
#                          to encode and analyze spatial vector data. Binds to 
#                          'GDAL'
# -   terra            -   Vector and raster data operations
# ==============================================================================
# Load Libraries
library(tidyverse)
library(fs)
library(glue)
library(here)
library(httr)
library(sf)
library(terra)
# ==============================================================================
# Download Koppen Geiger data
# 1a) Setup

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
#zip_url <- "https://figshare.com/ndownloader/files/45057352"

# Local file paths
file_path  <- "data/raw"                  # top-level folder for raw data
dir_name   <- "koppen_climate"            # subfolder for koppen data
zip_name   <- "koppen_geiger.zip"
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")

# 1b) Create target directory if it doesn't exist
dir_create(target_dir, recurse = TRUE)

# 1c) Download ZIP if it doesn't already exist
if (!file_exists(zip_path)) {
  message("Downloading Köppen-Geiger data...")
  GET(zip_url, write_disk(zip_path, overwrite = TRUE))
} else {
  message("ZIP file already exists: ", zip_path)
}

# 1d) Unzip the contents
koppen_geiger <- unzip(zip_path, exdir = target_dir)
message("Unzipped to: ", target_dir)

# 1e) Project and save the data
# Load and check current CRS (should be GCS WGS84)
#   note: 1991_2020 refers to temporal resolution
#         0p1 refers to 0.1 decimal degrees or 36 arcsec
r <- rast("data/raw/koppen_climate/1991_2020/koppen_geiger_0p1.tif")
crs <- crs(r)

# ------------------------------------------------------------------------------
# 2) Reproject and check if EPSG:5070
# ------------------------------------------------------------------------------
r_proj <- project(r, "EPSG:5070", method = "bilinear")
crs_new <- crs(r_proj)

# Check if projection succeeded
is_proj_5070 <- grepl("5070", crs_new) || grepl("Conus Albers", crs_new)
if (!is_proj_5070) warning("Reprojection may have failed: CRS does not contain EPSG:5070 or 'Conus Albers'")

# ------------------------------------------------------------------------------
# 3) Write results to data/processed
# ------------------------------------------------------------------------------

# 3a) Define output path
file_path  <- "data/processed"
dir_name   <- "koppen_climate"
file_name  <- "koppen_geiger.tif"
target_dir <- here(file_path, dir_name)
out_path   <- file.path(target_dir, file_name)

# 3b) Create directory and write file
dir_create(target_dir, recurse = TRUE)
writeRaster(r_proj, filename = out_path, overwrite = TRUE)

