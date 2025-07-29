# ==============================================================================
# Script Name:     01n_download_ned.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-06-25
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-24     Update header information; 
#                  move notes to `script-notes_and_developer-log`.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}; Updated header metadata.
#
# Purpose:         Download NED (National Elevation Dataset) clipped to the Great
#                  Plains. Calculate slope using (Fleming & Hoffer / Ritter
#                  algorithms), which use the 4 cardinal directions only
#                  (rook’s case) to produces smoother, more generalized slope
#                  surfaces -- Better matches subtle terrain transitions,
#                  especially in agricultural, prairie, or floodplain contexts.
#
# Workflow Summary:
# 0.5  Download zipped archive clipped to bounding box with {elevatr} using
#      get_elev_raster().
# 1.   Set-up and create a rectangular bounding box and ensure it’s in WGS84
#      (EPSG:4326). The EPSG:4326 CRS is required by elevatr{} and to make the
#      raster compatible with get_elev_raster() clipping logic.
# 2.   Reproject raster to a common CRS (US Albers Equal Area – EPSG:5070) for
#      spatial analysis for slope calculations and masking for accurate distances
#      and angles.
# 3.   Compute slope (in degrees) Slope was calculated using Fleming & Hoffer /
#      Ritter algorithms, which use only the four cardinal directions
#      (rook’s case) to produces smoother, more generalized slope surfaces,
#      which better matches subtle terrain transitions, especially in
#      agricultural, prairie, or floodplain contexts.
# 4.   Clip and mask raster. When clipping I used expand = 1000 for buffer to
#      help prevent clipping artifacts near edges.
# 5.   Export clipped and masked raster to ~data/processed.
#
# Input/Data URLs:
# -   Manual download: https://apps.nationalmap.gov/downloader/
# Output:
# - Clipped and masked raster projected to a common CRS
#
# Dependencies:
# - elevatr        Access to elevation data from various APIs
# - fs             File system operations
# - here           Consistent relative paths: locate files relative to proj root
# - sf             Support for simple feature access, a standardized way to
#                  encode and analyze spatial vector data. Binds to 'GDAL'
# - terra          Spatial data analysis-- wector and raster data operations
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# --- Load libraries ---
library(elevatr)
library(fs)
library(here)
library(sf)
library(terra)

# ------------------------------------------------------------------------------
# 1. Setup and make bounding box
# ------------------------------------------------------------------------------
# --- Read Great Plains vector ------------------------------------------------
gpkg_file <- file.path(
  here(), "data", "processed", "ecoregions", "us_eco_levels.gpkg")

gp_sf <- st_read(gpkg_file, layer = "us_eco_l1", quiet = TRUE) %>%
  dplyr::filter(NA_L1NAME == "GREAT PLAINS")

# --- Make bounding box -------------------------------------------------------
gp_bbox <- st_bbox(gp_sf) %>%
  st_as_sfc() %>%
  st_sf() %>%
  st_transform(4326)

# --- Get elevation raster ----------------------------------------------------
elev_raster <- get_elev_raster(
  locations = gp_bbox,  # <-- this was the key
  z = 10,
  clip = "locations",
  expand = 1000
)

# ------------------------------------------------------------------------------
# 2. Reproject raster to EPSG:5070
# ------------------------------------------------------------------------------
# Slope calculations and masking require a projected CRS
# for accurate distances and angles.
elev_rast_proj <- terra::project(rast(elev_raster), "EPSG:5070")

# ------------------------------------------------------------------------------
# 3. Compute slope raster
# ------------------------------------------------------------------------------
slope_proj <- terrain(elev_rast_proj,
                      v = "slope",
                      neighbors = 4,
                      unit = "degrees")

# ------------------------------------------------------------------------------
# 4. Mask outputs
# ------------------------------------------------------------------------------
gp_vect <- vect(gp_sf)

elev_mask <- mask(crop(elev_rast_proj, gp_vect), gp_vect)
slope_mask <- mask(crop(slope_proj, gp_vect), gp_vect)

# ------------------------------------------------------------------------------
# 4. Save clipped rasters
# ------------------------------------------------------------------------------
dir_create(file.path(here(), "data", "processed", "ned"))

writeRaster(
  elev_mask,
  filename = file.path(here(), "data", "processed", "ned", "elev_30m_gp.tif"),
  overwrite = TRUE
)

writeRaster(
  slope_mask,
  filename = file.path(here(), "data", "processed", "ned", "slope_30m_gp.tif"),
  overwrite = TRUE
)
