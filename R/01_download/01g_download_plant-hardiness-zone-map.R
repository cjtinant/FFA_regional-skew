# ==============================================================================
# Script Name:    01g_download_plant-hardiness-zone-map.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-04-15
# Last Updated:   2025-06-18      # split climate download scripts
#
# Purpose: Download, processes, and prepare climate rasters:
# -   gridded USDA Plant Hardiness Zone Map (PHZM)
#
# Data URLs:
# -   Plant Hardiness Zones -- https://prism.oregonstate.edu/projects/plant_hardiness_zones.php
#
# Workflow Summary:
# 1.   Download zipped archives, extract data and organize raster data
# 2.   Reproject rasters to a common CRS (US Albers Equal Area – EPSG:5070) 
#
# Output:
# Validated climate rasters projected to a common CRS
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
library(here)
library(fs)
library(glue)
library(httr)
library(prism)
library(terra)
library(sf)
# ==============================================================================
# Download plant hardiness zone map (PHZM)
# 1a) Setup

file_path  <- "data/raw"
dir_name   <- "phzm"
zip_name   <- "phzm.zip"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://prism.oregonstate.edu/projects/phm_data/phzm_us_grid_2023.zip"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")

# Create target directory if it doesn't exist
dir_create(target_dir, recurse = TRUE)

# Download ZIP if it doesn't already exist
if (!file_exists(zip_path)) {
  message("Downloading PHZM data...")
  GET(zip_url, write_disk(zip_path, overwrite = TRUE))
} else {
  message("ZIP file already exists: ", zip_path)
}

# Unzip the contents
phzm <- unzip(zip_path, exdir = target_dir)
message("Unzipped to: ", target_dir)


# ------------------------------------------------------------------------------
# 2) Reproject and check if EPSG:5070
# ------------------------------------------------------------------------------

# (Re)load raster and check current CRS (should be GCS NAD83)

rast_path <- glue("{target_dir}/phzm_us_grid_2023.bil")
r <- rast(rast_path)

r_proj <- project(r, "EPSG:5070", method = "bilinear")
crs_new <- crs(r_proj)

# Check if projection succeeded
is_proj_5070 <- grepl("5070", crs_new) || grepl("Conus Albers", crs_new)

# ------------------------------------------------------------------------------
# 3) Write results to data/processed
# ------------------------------------------------------------------------------
# Define output path
file_path  <- "data/processed"
target_dir <- here(file_path, dir_name)

file_name  <- "phzm.tif"
out_path   <- file.path(target_dir, file_name)

# Create directory and write file
dir_create(target_dir, recurse = TRUE)

writeRaster(r_proj, filename = out_path, overwrite = TRUE)

