# ==============================================================================
# Script Name:    01l_download_prism_climate.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-04-15
# Last Updated:   2025-07-22
#
# Purpose:
# Download and process PRISM 30-year climate normals (1991–2020) at 800m resolution:
# - Temperature: annual (tmax, tmean, tmin), daily (tmax, tmin)
# - Precipitation: annual, monthly, daily
#
# Changelog:
# 2025-07-22 - updated to conform with other scripts. Archived prior version
#
# Workflow Summary:
# 1. Download climate rasters using {prism}
# 2. Log raw files and verify download inventory
# 3. Reproject to EPSG:5070 and rename
# 4. Stack rasters by theme and temporal scale
# 5. Export stacked or individual rasters to data/processed/prism
# 6. Optionally delete intermediate files
#
# Output:
# - Climate rasters in:       data/processed/prism/
# - Download logs in:         data/log/prism_*.csv
#
# Dependencies:
# - dplyr, fs, glue, here, httr, prism, terra, sf, stringr
# ==============================================================================

# Load Libraries
library(tidyverse)
library(here)
library(fs)
library(glue)
library(httr)
library(prism)
library(terra)
library(sf)
library(stringr)

# Load custom function
source(here("R/utils/qaqc/verify_prism_archive.R"))

# ------------------------------------------------------------------------------
# 1. Download PRISM climate data
# ------------------------------------------------------------------------------
prism_set_dl_dir(here("data/raw/prism"))

# Annual normals
get_prism_normals("tmean", resolution = "800m", annual = TRUE)
get_prism_normals("ppt",   resolution = "800m", annual = TRUE)

# Monthly normals
get_prism_normals("ppt", resolution = "800m", mon = 1:12)

# Daily (climatology by month)
get_prism_dailies("ppt",  resolution = "800m", mon = 1:12)
get_prism_dailies("tmax", resolution = "800m", mon = 1:12)
get_prism_dailies("tmin", resolution = "800m", mon = 1:12)

# ------------------------------------------------------------------------------
# 2. Log inventory of raw PRISM files
# ------------------------------------------------------------------------------
prism_files <- tibble(raw_files = prism_archive_ls())
write_csv(prism_files, here("data/log/prism_file_inventory.csv"))

# ------------------------------------------------------------------------------
# 3. Reproject and rename rasters
# ------------------------------------------------------------------------------
verify_prism_archive("data/raw/prism", output_csv = "data/log/prism_qc.csv")

# This assumes rename_tbl() and summarise_raster_crs() are defined elsewhere
rename_tbl <- rename_tbl() %>%
  mutate(
    path_proj    = path("data/intermediate/prism_epsg5070", path_ext_set(fname_raw, "tif")),
    path_renamed = path("data/intermediate/prism_epsg5070", fname_clean)
  )

walk2(rename_tbl$path_proj, rename_tbl$path_renamed, file_move)

# ------------------------------------------------------------------------------
# 4. Stack and export climate rasters
# ------------------------------------------------------------------------------
intermediate_dir <- here("data/intermediate/prism_epsg5070")
output_dir <- here("data/processed/prism")

# 4a. Stack annual temperature
temp_ann_paths <- file.path(intermediate_dir, c("tmax_ann_C.tif", "tmean_ann_C.tif", "tmin_ann_C.tif"))
temp_stack <- rast(temp_ann_paths)
names(temp_stack) <- c("tmax_ann_C", "tmean_ann_C", "tmin_ann_C")
writeRaster(temp_stack, file.path(output_dir, "temp_ann_C_stack.tif"), overwrite = TRUE)

# 4b. Stack monthly precipitation
ppt_month_paths <- file.path(intermediate_dir, sprintf("ppt_m%02d_mm.tif", 1:12))
ppt_month_stack <- rast(ppt_month_paths)
names(ppt_month_stack) <- sprintf("ppt_m%02d_mm", 1:12)
writeRaster(ppt_month_stack, file.path(output_dir, "ppt_monthly_stack.tif"), overwrite = TRUE)

# 4c. Export annual precipitation
ppt_ann <- rast(file.path(intermediate_dir, "ppt_ann_mm.tif"))
names(ppt_ann) <- "ppt_ann_mm"
writeRaster(ppt_ann, file.path(output_dir, "ppt_ann_mm_stack.tif"), overwrite = TRUE)

# 4d. Copy daily rasters individually
walk(
  dir_ls(intermediate_dir, glob = "*.tif") %>% keep(~ str_detect(path_file(.x), "^(t(min|max)|ppt)_[0-9]{4}_")),
  ~ file_copy(.x, output_dir, overwrite = TRUE)
)

# ------------------------------------------------------------------------------
# 5. Optional: Delete intermediate reprojected files
# ------------------------------------------------------------------------------
inter_files <- dir_ls(intermediate_dir, glob = "*.tif") %>% path_file()
proc_files <- dir_ls(output_dir, glob = "*.tif") %>% path_file()

missing <- setdiff(inter_files, proc_files)

if (length(missing) == 0) {
  message("All files copied. Removing intermediate files...")
  dir_delete(intermediate_dir)
} else {
  warning("Some files may not have been copied:", paste(missing, collapse = ", "))
}
