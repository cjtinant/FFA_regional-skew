# ==============================================================================
# Script Name:     01f_download_nhdplus_v2.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-05-19
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-23     Update header information;
#                  move notes to `script-notes_and_developer-log`.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}.
#
# Purpose:         Download NHDPlusV2.1 flowlines and catchments clipped to the
#                  Great Plains. The data are at a regional scale (1:100,000)
#
# Workflow Summary:
# 1. Load Great Plains Level IV Ecoregions and keep only external boundary.
# 2. Move datum from WGS84 to NAD83 and buffer.
# 3. Download NHDPlusV2.1 data.
# 4. Validate and repair geometries and coerce to consistent geometry type.
# 5. Reproject to a common CRS (US Albers Equal Area – EPSG:5070).
# 6. Export reprojected, clipped, cleaned data as a gpkg for downstream use.
#
# Input/Data URLs:
# Output:
# - NHDPlusV2.1 flowlines and catchment boundaries for the GP Ecoregion.
#
# Dependencies:
# - dplyr          Data manipulation
# - fs             File system ops (dir_create)
# - here           Relative path handling
# - ggplot2        Data visualization
# - nhdplusTools   Download National Hydrography Dataset Plus (NHDPlus) data
# - sf             Spatial data (simple features)
# - units          Unit conversion
#
# Helper Functions:
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# =============================================================================
# --- Load libraries ---
library(dplyr)
library(fs)
library(ggplot2)
library(here)
library(nhdplusTools)
library(sf)
library(units)

# ------------------------------------------------------------------------------
# 1. Load and Process Great Plains Level IV Ecoregion Boundary
# ------------------------------------------------------------------------------
# --- Load EPA Level IV Ecoregions (should be already subset to Great Plains) ---
# --- check layers ---

st_layers(
  file.path(here(), "data", "processed", "us_ecoregions", "us_eco_levels.gpkg"))

eco_lev4 <- st_read(
  file.path(here(), "data", "processed", "us_ecoregions", "us_eco_levels.gpkg"),
  layer = "us_eco_l4"
)

# --- Filter and dissolve all polygons for Great Plains (Level I) ---
eco_lev4_gp_union <- eco_lev4 %>%
  filter(NA_L1NAME == "GREAT PLAINS") %>%
  summarise()

# --- Check EPSG (should be WGS84 / EPSG:4326) ---
epsg_ck1 <- st_crs(eco_lev4_gp_union)$epsg

# --- Extract only the largest contiguous landmass ---
eco_lev4_gp_main <- eco_lev4_gp_union %>%
  st_cast("POLYGON") %>%
  st_sf() %>%
  mutate(area = st_area(.)) %>%
  arrange(desc(area)) %>%
  slice(1)

# --- Buffer and transform to EPSG:4269 (NAD83), required by NHDPlus ---
eco_lev4_gp_main_buf <- eco_lev4_gp_main %>%
  st_buffer(dist = 1) %>%
  st_transform(4269)

# --- Check EPSG (should be NAD83 / EPSG:4269) ---
epsg_ck2 <- st_crs(eco_lev4_gp_main_buf)$epsg

# --- Quick reality check (visually) ---
ggplot() +
  geom_sf(
    data = eco_lev4_gp_main_buf,
    fill = "gray80",
    color = "white"
  ) +
  geom_sf(
    data = eco_lev4_gp_main,
    fill = "gray60",
    color = "white"
  )

# ------------------------------------------------------------------------------
# 2. Download Download NHDPlusV2 (1:100k) flowlines and catchments
# ------------------------------------------------------------------------------
# --- for Great Plains (should be 144 tiles) ---
nhd_v2_gp <- get_nhdplus(
  AOI = eco_lev4_gp_main_buf,
  realization = "all", # Includes flowline, catchment, outlet
  streamorder = 3, # Or set a threshold like 3
  t_srs = 5070 # Reproject output to CONUS Albers (EPSG:5070)
)

# ------------------------------------------------------------------------------
# 3. Save Output as GeoPackage
# ------------------------------------------------------------------------------
# --- Write flowlines and catchments to GeoPackage ---
flowline_out <- file.path("data", "raw/nhdplus_v21", "nhd_flowline_v21.gpkg")
st_write(nhdV2_gp$flowline,
         flowline_out,
         delete_dsn = TRUE
)

catchment_out <- file.path("data", "raw/nhdplus_v21", "nhdv21_catchments.gpkg")
st_write(nhdV2_gp$catchment, catchment_out,
  delete_dsn = TRUE
)

# --- Quick reality check (visually) ---
ggplot() +
  geom_sf(data = nhdV2_gp$catchment, fill = "gray80", color = "white") +
  geom_sf(data = nhdV2_gp$flowline, color = "blue", alpha = 0.4) +
  labs(title = "NHDPlusV2 Flowlines and Catchments - Great Plains Subset") +
  theme_minimal()

# ------------------------------------------------------------------------------
# 4. Check Projection of Catchments and Write to processed/
# ------------------------------------------------------------------------------
# --- Load the GeoPackage ---
catchment_in <- file.path(
  here(), "data", "raw", "nhdplus_v21", "nhdv21_catchments.gpkg")
catchments <- st_read(catchment_in)

# --- Check the current CRS ---
st_crs(catchments)

# --- Project to EPSG:5070 (CONUS Albers Equal Area) ---
catchments_proj <- st_transform(catchments, crs = 5070)

st_crs(catchments_proj)

# --- Write the projected data to a new GeoPackage ---
# Define output path
file_path <- "data/processed"
dir_name <- "nhdplus_v21"
file_name <- "nhdv21_catchments.gpkg"

target_dir <- file.path(here(), target_dir, dir_name)
out_path <- file.path(here(), target_dir, file_name)

# --- Create directory and write file
dir_create(target_dir, recurse = TRUE)

st_write(catchments_proj,
  dsn = out_path,
  delete_dsn = TRUE
)

# ------------------------------------------------------------------------------
# 5. Check Projection of `flowlines` and write to `processed/`
# ------------------------------------------------------------------------------
# --- Load the GeoPackage ---

flowlines_in <- file.path("data", "raw", "nhdplus_v21", "nhd_flowline_v21.gpkg")
flowlines <- st_read(flowlines_in)

# --- Check the current CRS ---
st_crs(flowlines)

# --- Project to EPSG:5070 (CONUS Albers Equal Area)
flowlines_proj <- st_transform(flowlines, crs = 5070)

# --- Write the projected data to a new GeoPackage ---
#  --- Define output path ---
file_path <- "data/processed"
dir_name <- "nhdplus_21"
file_name <- "nhdv21_flowlines.gpkg"
target_dir <- file.path(here(), file_path, dir_name)
out_path <- file.path(target_dir, file_name)

st_write(flowlines,
  dsn = out_path,
  delete_dsn = TRUE
)
