# ==============================================================================
# Script Name:    01c_download_nhdplus_v2.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-05-19
# Last Updated:   2025-06-04
#
# Purpose:        Download NHDPlusV2.1 flowlines and catchments clipped to the
#                 Great Plains. The data are at a regional scale (1:100,000)
#
# Workflow Summary:
# 1.   Load Great Plains Level IV Ecoregions and keep only external boundary
# 2.   Move datum from WGS84 to NAD83 and buffer.
# 3.   Download NHDPlusV2.1 data
# 4.   Validate and repair geometries and coerce to consistent geometry type.
# 5.   Reproject to a common CRS (US Albers Equal Area – EPSG:5070)
# 5.   -- TO DO --Recalculate area in sq-km using a common CRS
# 6.   Export reprojected, clipped, cleaned data as a gpkg for downstream use.
#
# Output:
# -    NHDPlusV2.1 flowlines and catchment boundaries for the Great Plains
#      Ecoregion
#
# Dependencies:
# -    dplyr
# -    fs
# -    ggplot2
# -    here:                 # consistent relative path
# -    nhdplusTools          # Tools for working with National Hydrography
#                                 Dataset Plus (NHDPlus) data.
# -    sf:                   # handling spatial data
# -    units                 # unit conversion
#
# Notes:
# -
# =============================================================================

# Load libraries
library(dplyr)
library(ggplot2)
library(here)
library(nhdplusTools)
library(sf)
library(units)
library(fs)

# ------------------------------------------------------------------------------
# 1. Load and Process Great Plains Level IV Ecoregion Boundary
# ------------------------------------------------------------------------------

# Load EPA Level IV Ecoregions (should be already subset to Great Plains)
# UPDDATE THIS FILE PATH
eco_lev4 <- st_read("data/raw/vector_raw/ecoregions_unprojected/us_eco_lev4_GreatPlains_geographic.gpkg")

# Filter and dissolve all polygons for Great Plains (Level I)
eco_lev4_gp_union <- eco_lev4 %>%
  filter(na_l1name == "GREAT PLAINS") %>%
  st_union() %>%
  st_sf(geometry = .)

# Check EPSG (should be WGS84 / EPSG:4326)
epsg_ck1 <- st_crs(eco_lev4_gp_union)$epsg

# Extract only the largest contiguous landmass
eco_lev4_gp_main <- eco_lev4_gp_union %>%
  st_cast("POLYGON") %>%
  st_sf() %>%
  mutate(area = st_area(.)) %>%
  arrange(desc(area)) %>%
  slice(1)

# Buffer and transform to EPSG:4269 (NAD83), required by NHDPlus
eco_lev4_gp_main_buf <- eco_lev4_gp_main %>%
  st_buffer(dist = 1) %>%
  st_transform(4269)

# Check EPSG (should be NAD83 / EPSG:4269)
epsg_ck2 <- st_crs(eco_lev4_gp_main_buf)$epsg

# Quick reality check (visually)
ggplot() +
  geom_sf(data = eco_lev4_gp_main_buf,
          fill = "gray80",
          color = "white") +
  geom_sf(data = eco_lev4_gp_main,
          fill = "gray60",
          color = "white")

# ------------------------------------------------------------------------------
# 2. Download Download NHDPlusV2 (1:100k) flowlines and catchments
#    for Great Plains (should be 144 tiles)
# ------------------------------------------------------------------------------

# Retrieve flowlines and catchments intersecting the buffered AOI
#   The code below:
#     get_nhdplus() loops through 144 tiles that intersect AOI.
#   It fetches data chunk-by-chunk and begins stitching them together.
#   Midway or After Completion: Invalid Geometry Detected
#      The function detects one or more invalid geometries (e.g.,
#         self-intersecting polygons or degenerate line segments).
# It triggers a geometry repair step internally.
#    sf / s2 Geometry Repair Mode Kicks In
#
# You see:
#   Found invalid geometry, attempting to fix.
# Spherical geometry (s2) switched on
# Spherical geometry (s2) switched off
#
# This temporarily activates s2 geometry engine to fix topological errors,
# which is common in large hydrologic datasets.
#
# Tiles Are Downloaded Again
#   The function starts over, reloading the same set of tiles (tiles 1–144)
#      with geometry corrections in place.
#
# ✅ Is This Normal?
#   Yes — this is expected behavior in nhdplusTools when:
#   An invalid feature is encountered (common with complex catchments or
#     clipped geometries),
# And get_nhdplus() must retry with geometry repair enabled.

nhdV2_gp <- get_nhdplus(
  AOI = eco_lev4_gp_main_buf,
  realization = "all",   # Includes flowline, catchment, outlet
  streamorder = 3,    # Or set a threshold like 3
  t_srs = 5070           # Reproject output to CONUS Albers (EPSG:5070)
)

# ------------------------------------------------------------------------------
# 3. Save Output as GeoPackage
# ------------------------------------------------------------------------------

# Write flowlines and catchments to GeoPackage
st_write(nhdV2_gp$flowline, "data/raw/nhdplus/nhd_flowline_v21.gpkg",
         delete_dsn = TRUE)
st_write(nhdV2_gp$catchment, "data/raw/nhdplus/nhd_catchment_v21.gpkg",
         delete_dsn = TRUE)

# Quick reality check (visually)
ggplot() +
  geom_sf(data = nhdV2_gp$catchment, fill = "gray80", color = "white") +
  geom_sf(data = nhdV2_gp$flowline, color = "blue", alpha = 0.4) +
  labs(title = "NHDPlusV2 Flowlines and Catchments - Great Plains Subset") +
  theme_minimal()

# ------------------------------------------------------------------------------
# 4. Check Projection of Catchments and Write to processed/
# ------------------------------------------------------------------------------

# 4.1. Load the GeoPackage
catchments <- st_read("data/raw/nhdplus/nhd_catchment_v21.gpkg")

# 4.2. Check the current CRS
st_crs(catchments)

# 4.3. Project to EPSG:5070 (CONUS Albers Equal Area)
catchments_proj <- st_transform(catchments, crs = 5070)

st_crs(catchments_proj)

# 4.4. Write the projected data to a new GeoPackage
# Define output path
file_path  <- "data/processed"
dir_name   <- "nhdplus"
file_name  <- "nhd_catchment_v21.gpkg"
target_dir <- here(file_path, dir_name)
out_path   <- file.path(target_dir, file_name)

# 4.5 Create directory and write file
dir_create(target_dir, recurse = TRUE)

st_write(catchments_proj,
         dsn = out_path,
         delete_dsn = TRUE)

# ------------------------------------------------------------------------------
# 5. Check Projection of Flowlines and Write to processed/
# ------------------------------------------------------------------------------

# 5.1. Load the GeoPackage
flowlines <- st_read("data/raw/nhdplus/nhd_flowline_v21.gpkg")

# 4.2. Check the current CRS
st_crs(flowlines)

# 4.3. Project to EPSG:5070 (CONUS Albers Equal Area)
flowlines_proj <- st_transform(flowlines, crs = 5070)

# 4.4. Write the projected data to a new GeoPackage
# Define output path
file_path  <- "data/processed"
dir_name   <- "nhdplus"
file_name  <- "nhd_flowlines_v21.gpkg"
target_dir <- here(file_path, dir_name)
out_path   <- file.path(target_dir, file_name)

st_write(flowlines,
         dsn = out_path,
         delete_dsn = TRUE)
