# ==============================================================================
# Script Name:    01k_download_ned.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-06-25
# Last Updated:   
#
# Purpose: Download NED (National Elevation Dataset) clipped to Great Plains. 
#          Calculate slope using (Fleming & Hoffer / Ritter algorithms), which
#          use the 4 cardinal directions only (rook’s case) to produces smoother,
#          more generalized slope surfaces -- Better matches subtle terrain 
#          transitions, especially in agricultural, prairie, or floodplain 
#          contexts
#
# Data URLs:
# -   Manual download: https://apps.nationalmap.gov/downloader/
# Workflow Summary:
# 1.   Download zipped archive clipped to bounding box with {elevatr} using
#      get_elev_raster(). Bounding box needs to be in WGS84 (EPSG:4326).
# 2.   Reproject raster to a common CRS (US Albers Equal Area – EPSG:5070) 
#      for spatial analysis for slope calculations and masking for accurate 
#      distances and angles.
# 3.  Compute slope (in degrees)
# 4.   Mask raster
# 5.   Export clipped and masked raster to ~data/processed.
#
# Output:
# Clipped and masked raster projected to a common CRS
#
# Dependencies:   
#
# Notes:
# Used neighbors = 4 for smoother slope -- good for prairie landscapes
# Used expand = 1000 for buffer to help prevent clipping artifacts near edges
# ==============================================================================
library(fs)
library(here)
library(elevatr)
library(sf)
library(terra)

# --- Read Great Plains vector ------------------------------------------------
gpkg_file <- here("data", "processed", "ecoregions", "us_eco_levels.gpkg")

gp_sf <- st_read(gpkg_file, layer = "us_eco_l1", quiet = TRUE) %>%
  dplyr::filter(NA_L1NAME == "GREAT PLAINS")

# --- Make bounding box -------------------------------------------------------
# Create a rectangular bounding box and ensure it’s in WGS84 (EPSG:4326)
#    which {elevatr} requires -- and make it compatible with get_elev_raster() 
#    clipping logic
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

# Reproject raster to EPSG:5070
#    Slope calculations and masking require a projected CRS for accurate 
#    distances and angles.
elev_rast_proj <- terra::project(rast(elev_raster), "EPSG:5070")

# --- Compute slope vector ----------------------------------------------------
slope_proj <- terrain(elev_rast_proj, 
                      v = "slope", 
                      neighbors = 4,
                      unit = "degrees")

# --- Mask outputs ------------------------------------------------------------
gp_vect <- vect(gp_sf)

elev_mask <- mask(crop(elev_rast_proj, gp_vect), gp_vect)
slope_mask <- mask(crop(slope_proj, gp_vect), gp_vect)


# --- Save clipped rasters ----------------------------------------------------
dir_create(here("data", "processed", "ned"))

writeRaster(
  elev_mask,
  filename = here("data", "processed", "ned", "elev_30m_gp.tif"),
  overwrite = TRUE
)

writeRaster(
  slope_mask,
  filename = here("data", "processed", "ned", "slope_30m_gp.tif"),
  overwrite = TRUE
)

