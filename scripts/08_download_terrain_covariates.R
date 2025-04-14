# ==============================================================================
# Script: 08_download_terrain_covariates.R
# Purpose: Download and prepare terrain covariates (elevation and slope)
#          to support regional skew modeling for unregulated USGS gage sites.
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Covariates:
# - Elevation (meters)
# - Slope (degrees)
#
# Sources:
# - USGS 3DEP (via {elevatr} R package)
#
# Outputs:
# - data/clean/data_covariates_terrain.csv
#
# ==============================================================================

library(tidyverse)
library(here)
library(sf)
library(elevatr)
library(terra)

# ------------------------------------------------------------------------------
# Load Site Locations
sites <- read_csv(here("data/clean/sites_pk_gt_20.csv")) %>%
  distinct(site_no, dec_lat_va, dec_long_va) %>%
  drop_na(dec_lat_va, dec_long_va)

sites_sf <- sites %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4326)

# ------------------------------------------------------------------------------
# Get Elevation Data from USGS 3DEP
elev_raster <- get_elev_raster(locations = sites_sf, z = 10, clip = "bbox")

# ------------------------------------------------------------------------------
# Calculate Slope (degrees)
slope_raster <- terra::terrain(terra::rast(elev_raster), v = "slope", unit = "degrees")

# ------------------------------------------------------------------------------
# Extract Covariates to Site Locations
elev_cov <- terra::extract(terra::rast(elev_raster), vect(sites_sf))
slope_cov <- terra::extract(slope_raster, vect(sites_sf))

# ------------------------------------------------------------------------------
# Combine Covariates with Site Info
covariates_terrain <- sites %>%
  bind_cols(
    elev_cov %>% select(-ID) %>% rename(elev_m = 1),
    slope_cov %>% select(-ID) %>% rename(slope_deg = 1)
  ) %>%
  relocate(site_no, dec_lat_va, dec_long_va, .before = everything())

# ------------------------------------------------------------------------------
# Export Final Terrain Covariates
write_csv(covariates_terrain, here("data/clean/data_covariates_terrain.csv"))

message("Finished downloading, extracting, and exporting terrain covariates.")
