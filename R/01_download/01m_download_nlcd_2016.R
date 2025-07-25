# ==============================================================================
# Script Name:     01m_download_nlcd_2016.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-06-23
# Last Updated:    2025-07-23
# Change Log:
# - 2025-07-23     Update header information; 
#                  move notes to `script-notes_and_developer-log`.
#
# Purpose: Download NLCD 2016 Land Cover raster clipped to Great Plains.
#
# Workflow Summary:
# 1.   Manually download zipped archive and move to outdir (see notes)
# 2.   Reproject raster to a common CRS (US Albers Equal Area – EPSG:5070)
#        for spatial analysis.
# 3.   Clip and mask raster
# 4.   Export clipped and masked raster to ~data/processed.
#
# Input/Data URLs:
# - Data are downloaded from https://www.mrlc.gov/data.
# Output:
# Clipped and masked raster projected to a common CRS
#
# Dependencies:
# - dplyr:         Data manipulation
# - fs             File system operations
# - sf             Support for simple feature access, a standardized way to
#                    encode and analyze spatial vector data. Binds to 'GDAL'
# - terra:         Spatial data analysis-- wector and raster data operations

# - mapview        Interactive viewing of spatial data
# - nhdplusTools   Tools for traversing and working with National
#                  Hydrography Dataset Plus (NHDPlus) data.
# - purrr          Functional programming toolkit
# - readr          Reads rectangular data
# - stringr        Wrappers for string operations
# - tidyverse:     Data wrangling & visualization
# - units          Unit conversion -- to convert from m² to km²
# - dataRetrieval: Access USGS NWIS data
#
# Helper Functions:
#
# Related Milestone Reports: 
# - milestone_01_download_prepare_covariates.Rmd
# - milestone_01_download_prepare_covariates.pdf

# ==============================================================================
# --- Load libraries ---
library(fs)
library(here)
library(sf)
library(terra)

# --- Define file paths -------------------------------------------------------
nlcd_file <- here("data", "raw", "nlcd", "Annual_NLCD_LndCov_2016_CU_C1V0.tif")
gpkg_file <- here("data", "processed", "ecoregions", "us-eco-levels.gpkg")

# --- Read raster and vector --------------------------------------------------
r_nlcd <- rast(nlcd_file)

eco_lev1 <- st_read(gpkg_file, layer = "us_eco_l1", quiet = TRUE)
gp_sf <- eco_lev1[eco_lev1$NA_L1NAME == "GREAT PLAINS", ]

# Check CRS -- should be EPSG 5070
st_crs(gp_sf)

# Reproject raster to match vector CRS (EPSG:5070)
r_nlcd_proj <- project(r_nlcd, "EPSG:5070")

# --- Clip and mask -----------------------------------------------------------
gp_vect <- vect(gp_sf)                 # rasterize great plains vector

# Slice out a rectangular chunk around the area you're interested in"
r_crop <- crop(r_nlcd_proj, gp_vect)

# Apply a stencil so only values inside the shape are kept"
r_mask <- mask(r_crop, gp_vect)

# Check CRS
crs(r_mask)

# --- Prepare to save clipped raster ------------------------------------------
dir_create(here("data", "processed", "nlcd"))

writeRaster(
  r_mask,
  filename = here("data", "processed", "nlcd", "nlcd_2016_gp.tif"),
  overwrite = TRUE
)

message("✓ Saved: NLCD 2016 clipped to Great Plains.")
