# ==============================================================================
# Script Name:    01j_download_nlcd_2016.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-06-23
# Last Updated:   
#
# Purpose: Download NLCD 2016 Land Cover raster clipped to Great Plains
#
# Data URLs:
# -   https://www.mrlc.gov/data
# Workflow Summary:
# 1.   Manually download zipped archive and move to outdir (see notes)
# 2.   Reproject raster to a common CRS (US Albers Equal Area – EPSG:5070) 
#        for spatial analysis.
# 3.   Clip and mask raster
# 4.   Export clipped and masked raster to ~data/processed.
#
# Output:
# Clipped and masked raster projected to a common CRS
#
# Dependencies:   
# -   fs
# -   here
# -   sf
# -   terra
#
# Notes: Using {FedData} All tile requests timed out at ~30 seconds
# Received over 100–200 MB per tile, but not enough to complete the download.
# Then FedData::get_nlcd() tried to crop those partial files → 💥 crash.
#
# crop() -- Trims the raster extent down to the bounding box of the vector 
#    geometry (shape). Keeps all raster cells that intersect the box — even if 
#    they fall outside the exact shape.
# Inputs: raster: a SpatRaster (e.g., the full NLCD)
#         shape:  a SpatVector (e.g., Great Plains boundary)
# mask() -- Replaces all raster cells outside the exact shape with NA. Keeps 
#   only values within the actual polygon boundary.
# Inputs: r_crop: a raster that has already been spatially subset (cropped)
#         shape:  the same or overlapping SpatVector

# here("data/raw/nlcd/NLCD_2016_Land_Cover_L48_20210604.img")

# ==============================================================================

library(fs)
library(here)
library(sf)
library(terra)


# --- Define file paths -------------------------------------------------------
nlcd_file <- here("data", "raw", "nlcd", "Annual_NLCD_LndCov_2016_CU_C1V0.tif")
gpkg_file <- here("data", "processed", "ecoregions", "us_eco_levels.gpkg")

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
