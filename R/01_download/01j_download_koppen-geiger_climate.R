# ==============================================================================
# Script Name:     01h_download_koppen-geiger_climate.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-04-15
# Last Updated:    2025-07-23
# Changelog:
# - 2025-07-22     Header Cleanup, Use here() for all paths, Add checks for
#                  whether raster exists before trying to reproject, Use
#                  tryCatch() for rast() or unzip() in case something is missing
#                  or corrupt.
# - 2025-07-23     Update header information;
#                  move notes to `script-notes_and_developer-log`.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}.
#
# Purpose:         Download, process, and reproject Köppen-Geiger climate raster
#                  data.
#
# Workflow Summary:
# 1. Download ZIP archive (if not already present)
# 2a. Extract raster and check original CRS (WGS84)
# 2b. Reproject to EPSG:5070 (Conus Albers)
# 3. Save to data/processed/koppen-climate/koppen-geiger.tif
#
# Input/Data URLs:
# - https://www.gloh2o.org/koppen/
# Outputs:
# - Reprojected Köppen-Geiger raster (EPSG:5070) ready for spatial analysis
# in /data/processed/
#
# Dependencies:
# - dplyr, readr   Data manipulation and export
# - fs             File system ops (dir_create)
# - glue           Interpret string literals
# - here           Relative path handling
# - httr           Tools for working with URLs and HTTP
# - sf             Spatial data (simple features)
# - terra           Vector and raster data operations
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# --- Load libraries ---
library(tidyverse)
library(fs)
library(glue)
library(here)
library(httr)
library(sf)
library(terra)

# ------------------------------------------------------------------------------
# 1. Download and unzip Köppen-Geiger data
# ------------------------------------------------------------------------------

zip_url <- "https://www.gloh2o.org/koppen/koppen-geiger.zip" # Define URL
raw_file <- "koppen-geiger.zip"
raw_dir <- file.path(here(), "data", "raw", "koppen_climate")
zip_path <- path(raw_dir, raw_file)

dir_create(raw_dir, recurse = TRUE)

if (!file_exists(zip_path)) {
  message("📦 Downloading Köppen-Geiger climate data...")
  GET(zip_url, write_disk(zip_path, overwrite = TRUE))
} else {
  message("✅ ZIP file already exists: ", zip_path)
}

unzip(zip_path, exdir = raw_dir)
message("📂 Unzipped to: ", raw_dir)

# ------------------------------------------------------------------------------
# 2. Load and reproject raster
# ------------------------------------------------------------------------------

raster_path <- path(raw_dir, "1991_2020", "koppen-geiger_0p1.tif")

if (!file_exists(raster_path)) stop("❌ Raster file not found at: ", raster_path)

r <- rast(raster_path)
message("🗺️  Original CRS: ", crs(r))

r_proj <- project(r, "EPSG:5070", method = "bilinear")
message("✅ Reprojected to: ", crs(r_proj))

# Check if reprojection succeeded
if (!grepl("5070|Conus Albers", crs(r_proj))) {
  warning("⚠️ Reprojection may have failed: target CRS does not contain 'EPSG:5070'")
}

# ------------------------------------------------------------------------------
# 3. Write processed raster
# ------------------------------------------------------------------------------

processed_dir <- file.path(here(), "data", "processed", "koppen_climate")
out_file <- "koppen-geiger.tif"
out_path <- path(processed_dir, out_file)

dir_create(processed_dir, recurse = TRUE)
writeRaster(r_proj, filename = out_path, overwrite = TRUE)

message("📁 Reprojected raster saved to: ", out_path)
