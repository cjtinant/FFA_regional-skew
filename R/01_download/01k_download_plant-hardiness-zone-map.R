# ==============================================================================
# Script Name:     01j_download_plant-hardiness-zone-map.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-04-15
# Last Updated:    2025-06-18      # split climate download scripts
# Change Log:
# - 2025-06-18     Split climate download scripts
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}; Updated header metadata
#
# Purpose: Download, processes, and project USDA Plant Hardiness Zone Map (PHZM).
#
# Workflow Summary:
# 1. Download zipped archives, extract data and organize raster data
# 2. Reproject rasters to a common CRS (US Albers Equal Area – EPSG:5070)
# 3. Write results to data/processed
#
# Inputs/Data URLs:
# - https://prism.oregonstate.edu/projects/plant_hardiness_zones.php
# Outputs:
# - Validated climate rasters projected to a common CRS in
#
# Dependencies:
# - fs             File system operations
# - glue           String interpolation
# - here           Consistent relative paths
# - httr           Makes http easy
# - purrr          Functional programming toolkit
# - sf             Support for simple feature access, a standardized way to
#                  encode and analyze spatial vector data. Binds to 'GDAL'
# - terra          Spatial data analysis
# - tidyverse      Data wrangling & visualization
#
# Helper Functions:
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# Load Libraries
library(fs)
library(glue)
library(here)
library(httr)
library(prism)
library(sf)
library(terra)
library(tidyverse)

# ------------------------------------------------------------------------------
# 1. Download and unzip plant hardiness zone map (PHZM)
# ------------------------------------------------------------------------------
# --- URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR) ---
zip_url <- "https://prism.oregonstate.edu/projects/phm_data/phzm_us_grid_2023.zip"

# --- Local file paths ---
zip_name <- "phzm.zip"
target_dir <- file.path(here(), "data", "raw", "phzm")
zip_path <- file.path(target_dir, zip_name)

# Create target directory if it doesn't exist
dir_create(target_dir, recurse = TRUE)

# Download ZIP if it doesn't already exist
if (!file_exists(zip_path)) {
  message("Downloading PHZM data...")
  GET(zip_url, write_disk(zip_path, overwrite = TRUE))
} else {
  message("ZIP file already exists: ", zip_path)
}

# --- Unzip the ZIP file contents ---
phzm <- unzip(zip_path, exdir = target_dir)
message("Unzipped to: ", target_dir)

# ------------------------------------------------------------------------------
# 2. Reproject and check if EPSG:5070
# ------------------------------------------------------------------------------

# (Re)load raster and check current CRS (should be GCS NAD83)
rast_file <- "phzm_us_grid_2023.bil"
rast_path <- file.path(target_dir, rast_file)
r <- rast(rast_path)

r_proj <- project(r, "EPSG:5070", method = "bilinear")
crs_new <- crs(r_proj)

# Check if projection succeeded
is_proj_5070 <- grepl("5070", crs_new) || grepl("Conus Albers", crs_new)

# ------------------------------------------------------------------------------
# 3. Write results to data/processed
# ------------------------------------------------------------------------------
# Define output path
target_dir <- file.path(here(), "data", "processed", "phzm")
file_name  <- "phzm.tif"
out_path   <- file.path(target_dir, file_name)

# Create directory and write file
dir_create(target_dir, recurse = TRUE)
writeRaster(r_proj, filename = out_path, overwrite = TRUE)
