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

# ------------------------------------------------------------------------------
# Metadata for Terrain Covariates

terrain_metadata <- tribble(
  ~attribute, ~value,
  
  "Source", "USGS 3DEP Elevation via {elevatr} R package",
  "Resolution", "Variable by location (~10m or ~30m depending on coverage)",
  "Projection", "WGS84 (EPSG:4326) for download; reproject to NAD83 in later steps",
  "Datum", "WGS84 (EPSG:4326)",
  "Elevation Units", "Meters above sea level",
  "Slope Units", "Degrees",
  "Slope Calculation", "Derived from elevation raster using terra::terrain() with v = 'slope' and unit = 'degrees'",
  "Download Date", format(Sys.Date(), "%Y-%m-%d"),
  "Processing Notes", "Elevation data downloaded via get_elev_raster(locations, z = 10). Slope calculated using terra::terrain(). Extracted to USGS site locations using terra::extract(). Outputs ready for modeling station skew."
)

# ------------------------------------------------------------------------------
# Export Metadata
write_csv(terrain_metadata, here("data/meta/prism_metadata_terrain.csv"))

message("Terrain covariate metadata saved to: data/meta/prism_metadata_terrain.csv")
