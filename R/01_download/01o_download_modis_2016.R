# ==============================================================================
# Script Name:     01o_download_modis_ndvi_2016.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-06-26
# Last Updated:    2025-07-25
# Change Log:
# - 2025-06-28     Stack rasters, add index csv
# - 2025-07-25     Update header information; 
#                  move notes to `script-notes_and_developer-log`.
#
# Purpose:         Document the process for downloading MODIS MOD13Q1 (NDVI/EVI)
#                  raster data for the year 2016, clipped to the Great Plains
#                  Level I Ecoregion.
#
# Workflow Summary
# 0.0  This script documents workflow but does NOT download rasters directly. 
# 0.2. Create a NASA Earthdata Login account:
#      https://urs.earthdata.nasa.gov/users/new
# 0.4. Install Earthdata Download Manager:
#      https://wiki.earthdata.nasa.gov/display/ED/Earthdata+Download+Client
# 0.6. Search and download via browser (Requires Earthdata Download Manager).
# 0.8  Move .hdf files from the download folder:
#      `~/Downloads/MOD13Q1_061-YYYYMMDD_HHMMSS/` to `data/raw/modis/mod13q1_hdf`
#      after download completes.
# 1.0. Make bounding box.
# 2.0  Build rasters from HDF files.
# 3.0  Mosaic rasters by time step.
# 4.0  Reproject, clip, and write output
#
# Input/Data URLs:
# - https://search.earthdata.nasa.gov/
# Outputs:
# - stacked raster in a geo-tif format projected to EPSG:5070, and stored in
#   `/data/processed/`.
#
# Dependencies:
# - dplyr:         Data manipulation
# - fs             File system operations
# - glue           Formats strings
# - here:          Consistent relative paths: locate files relative to proj root
# - purrr          Functional programming toolkit
# - readr          Reads rectangular data
# - sf             Support for simple feature access, a standardized way to
#                  encode and analyze spatial vector data. Binds to 'GDAL'
# - terra:         Spatial data analysis-- wector and raster data operations
#
# Helper Functions:
#
# Related Milestone Reports: 
# - milestone_01_download_prepare_covariates.Rmd
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# ---- Load packages ----
library(dplyr)
library(fs)
library(glue)
library(here)
library(purrr)
library(readr)
library(sf)
library(terra)

# ---- Setup folders ----
dir_raw <- here("data", "raw", "modis", "mod13q1_hdf")
dir_processed <- here("data", "processed", "modis", "mod13a1_ndvi_timeseries")
dir_create(dir_raw)
dir_create(dir_processed)

# ----  Manually download MOD13Q1 HDFs ---
# Go to: https://search.earthdata.nasa.gov/
# Search for: MOD13Q1
# Filter by Temporal
# -   Start: 2016-01-01
# -   End:   2016-12-31
# Click: MODIS/Terra Vegetation Indices 16-Day L3 Global 250m SIN Grid V061

# -----------------------------------------------------------------------------
# 1. Make bounding box
# -----------------------------------------------------------------------------
# ---- Load Bounding Box and Output SW/NW Corners ----
gp_bbox_wgs84 <- st_read("data/processed/us_ecoregions/us-eco-levels.gpkg",
                         layer = "us_eco_l1") %>%
  filter(NA_L1NAME == "GREAT PLAINS") %>%
  st_transform(5070) %>%            # Project to meters
  st_buffer(50000) %>%              # Apply buffer
  st_transform(4326) %>%            # Back to WGS84 for Earthdata Search
  st_bbox()

sw <- glue("{gp_bbox_wgs84['ymin']}, {gp_bbox_wgs84['xmin']}")
ne <- glue("{gp_bbox_wgs84['ymax']}, {gp_bbox_wgs84['xmax']}")

cat("\nPaste this into Earthdata Search bounding box:")
cat(glue("\nSW (lower left): {sw}"))
cat(glue("\nNE (upper right): {ne}\n"))

# -----------------------------------------------------------------------------
# 2. Build rasters from HDF files
# -----------------------------------------------------------------------------
# ---- List and describe .hdf files ----
hdf_files <- dir_ls(dir_raw, regexp = "\\.hdf$")

if (length(hdf_files) == 0) {
  stop("No .hdf files found in ", dir_raw)
} else {
  cat(glue("\nFound {length(hdf_files)} HDF files."))
}

# Describe first file to identify SDS structure
cat("\nExample SDS from first HDF:")
terra::describe(hdf_files[1])

# ---- Extract NDVI SDS and build raster list ----
cat("\nReading NDVI SDS from all HDFs...")

ndvi_list <- lapply(hdf_files, function(hdf) {
  sds_path <- glue('HDF4_EOS:EOS_GRID:"{hdf}":MODIS_Grid_16DAY_250m_500m_VI:"250m 16 days NDVI"')
  rast(sds_path)
})

# -----------------------------------------------------------------------------
# 3. Mosaic rasters by time step
# -----------------------------------------------------------------------------
# ---- Confirm CRS and extent match ----
crs_vals <- sapply(ndvi_list, crs)
if (length(unique(crs_vals)) > 1) {
  warning("Some NDVI rasters have differing CRS. Check alignment.")
}

unique(crs_vals)

# ---- Mosaic by time step (23 scenes for 2016) ----
cat("\nGrouping tiles by date...")
dates <- gsub(".*A(\\d{7})\\..*", "\\1", basename(hdf_files))
tile_index <- gsub(".*\\.h(\\d{2}v\\d{2})\\..*", "\\1", basename(hdf_files))

ndvi_tbl <- tibble(
  file = hdf_files,
  date = dates,
  tile = tile_index,
  raster = ndvi_list
)

# Group by date
ndvi_stacks <- ndvi_tbl %>%
  group_by(date) %>%
  summarize(mosaic = list(reduce(raster, mosaic)))

# -----------------------------------------------------------------------------
# 4. Reproject, clip, and write output
# -----------------------------------------------------------------------------
cat("\nReprojecting, clipping, and writing rasters...")

# Read and buffer AOI again for cropping
aoi_proj <- st_read("data/processed/us_ecoregions/us-eco-levels.gpkg",
  layer = "us_eco_l1",
  quiet = TRUE
) %>%
  filter(NA_L1NAME == "GREAT PLAINS") %>%
  st_transform(5070) %>%
  st_buffer(50000)

for (i in seq_len(nrow(ndvi_stacks))) {
  d <- ndvi_stacks$date[i]
  r <- ndvi_stacks$mosaic[[i]] %>%
    project("EPSG:5070") %>%
    crop(vect(aoi_proj))

  r <- classify(r, cbind(0, NA)) * 0.0001        # scale the NDVI values
  # and set fill values to NA

  out_path <- here(dir_processed, glue("ndvi_{d}.tif"))
  writeRaster(r,
              out_path,
              overwrite = TRUE)
}

# ---- After export: Stack all rasters and write summary CSV ----

# List all output rasters
ndvi_paths <- dir_ls(dir_processed, regexp = "ndvi_\\d+\\.tif$")
ndvi_stack <- rast(ndvi_paths)

# Save as multi-layer raster
out_stack <- here(dir_processed, "ndvi_2016_stack.tif")
writeRaster(ndvi_stack, out_stack, overwrite = TRUE)

# Build index of outputs
ndvi_index <- tibble(
  file = ndvi_paths,
  date = gsub(".*ndvi_(\\d+)\\.tif$", "\\1", basename(ndvi_paths)),
  layer = seq_along(ndvi_paths),
  tiles_used = NA  # Optionally populate manually
)

write_csv(ndvi_index, here(dir_processed, "ndvi_2016_index.csv"))

# [Optional] Add quality filter integration using QA layers here if needed.
