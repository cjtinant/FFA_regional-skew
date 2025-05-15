# ==============================================================================
# Script Name:    01c_download_climate.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-04-15
# Last Updated:   2025-05-15      # update script header
#
#
# Purpose: Download, processes, and prepare the following climate data
# -   Köppen Geiger climate raster, 
# -   gridded USDA Plant Hardiness Zone Map (PHZM) raster, and 
# -   PRISM 30-year normals at 800m resolution
#       -  annual tmax
#       - annual tmean
#       -  annual tmin
#       -  annual ppt
#       - monthly ppt
#       -   daily tmax
#       -   daily tmin
#       -   daily ppt
#
#
# Data URLs:
# -   Köppen Geiger climate -- gewww.gloh2o.org/koppen/
# -   Plant Hardiness Zones -- https://prism.oregonstate.edu/projects/plant_hardiness_zones.php
# -   PRISM climate normals -- https://prism.oregonstate.edu/
#
#
# Workflow Summary:
# 1.   Download zipped archives, extract data and organize raster data
# 2.   Reproject rasters to a common CRS (US Albers Equal Area – EPSG:5070) 
#        for spatial analysis.
# 3.   Stack PRISM rasters (where appropriate)
# 4.   Export reprojected, stacked rasters to ~data/processed.
#
#
# Output:
# Validated climate rasters projected to a common CRS
#
# Folder structure:
#    data/raw/
#      ├── epa_ecoregions/
#            ├── NA_CEC_Eco_Level1.shp
#            ├── NA_CEC_Eco_Level2.shp
#            ├── NA_CEC_Eco_Level3.shp
#            └── us_eco_l4_no_st.shp/
#
#      ├── koppen_climate/
#                ├── 1901_1930/
#                ├── 1931_1960/
#                ├── 1961_1990/
#                ├── 1991_2020/
#                ├── 2041_2070/
#                └── 2071_2099/

#      ├── phzm/
#      ├── prism/

#    data/intermediate/

#
# data/processed/
#      ├── us_eco_levels.gpkg
#      └── prism/
#
#
# Dependencies:
# -   tidyverse::dplyr
# -   here
# -   fs                  # file interface system
# -   glue
# -   httr
# -   prism
# -   terra
#
# ==============================================================================
# Load Libraries
library(tidyverse)
library(here)
library(fs)                  # file interface system
library(here)
library(glue)
library(httr)
library(prism)
library(terra)

# library(sf)
# library(janitor)

# Load function definitions
source(here("R/utils/download_data/verify_prism_archive.R"))

# Functions to move----

# Check CRS for each raster
crs_summary <- purrr::map_dfr(bil_files, function(file) {
  r <- rast(file)
  tibble(
    file = basename(file),
    crs = crs(r, describe = TRUE)
  )
})

# ------------------------------------------------------------------------------
# Utility: Build SpatRaster from prism_archive_ls() results

build_prism_rasters <- function(prism_dirs) {
  bil_paths <- file.path(
    prism_get_dl_dir(),
    prism_dirs,
    paste0(basename(prism_dirs), ".bil")
  )
  terra::rast(bil_paths)
}

# ------------------------------------------------------------------------------
# Utility: reproject to EPSG5070
reproject_to_epsg5070_batch <- function(bil_files,
                                        out_dir = here::here("data/intermediate/prism_epsg5070"),
                                        log_path = here::here("data/log/prism_crs_log.csv")) {
  library(terra)
  library(fs)
  library(dplyr)
  
  dir_create(out_dir, recurse = TRUE)
  
  crs_log <- purrr::map_dfr(bil_files, function(f) {
    r <- rast(f)
    crs_original <- crs(r)
    
    # Check if it's already in EPSG:5070
    is_proj_5070 <- grepl("5070", crs_original) || grepl("Conus Albers", crs_original)
    
    # Output path
    fname_out <- path_file(f)
    fname_out <- path_ext_set(fname_out, "tif")
    out_path <- file.path(out_dir, fname_out)
    
    # Reproject if needed
    if (!is_proj_5070) {
      cat("Reprojecting:", fname_out, "\n")
      r_proj <- project(r, "EPSG:5070", method = "bilinear")
      writeRaster(r_proj, filename = out_path, overwrite = TRUE)
      crs_new <- crs(r_proj)
    } else {
      cat("Already EPSG:5070:", fname_out, "\n")
      file_copy(f, out_path, overwrite = TRUE)
      crs_new <- crs(r)
    }
    
    tibble(
      file = f,
      output = out_path,
      original_crs = crs_original,
      new_crs = crs_new
    )
  })
  
  # Save log
  readr::write_csv(crs_log, log_path)
  
  invisible(crs_log)
}
#-------------------------------------------------------------------------------
# Create rename table from bil_files
rename_tbl <- tibble(
  path_raw = bil_files,
  fname_raw = path_file(bil_files)
) %>%
  mutate(
    theme = case_when(
      str_detect(fname_raw, "ppt")   ~ "ppt",
      str_detect(fname_raw, "tmean") ~ "tmean",
      str_detect(fname_raw, "tmax")  ~ "tmax",
      str_detect(fname_raw, "tmin")  ~ "tmin",
      TRUE ~ NA_character_
    ),
    # period = case_when(
    #   str_detect(fname_raw, "annual") ~ "ann",
    #   str_detect(fname_raw, "0[1-9]_bil|10_bil|11_bil|12_bil") ~ str_extract(fname_raw, "(?<=_)[0-9]{2}(?=_bil)"),
    #   str_detect(fname_raw, "_[0-9]{4}_bil") ~ str_extract(fname_raw, "[0-9]{4}"),
    #   TRUE ~ NA_character_
    # ),
    period = case_when(
      str_detect(fname_raw, "annual") ~ "ann",
      
      # Daily: 4-digit DOY-like codes (e.g., _0101_)
      str_detect(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") ~ str_extract(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") %>%
        str_remove_all("_bil") %>%
        str_remove("^_"),
      
      # Monthly: _01_ to _12_, prefix with 'm' for clarity
      str_detect(fname_raw, "_(0[1-9]|1[0-2])_bil") ~ paste0("m", str_extract(fname_raw, "(0[1-9]|1[0-2])"))
    ),
    # period = case_when(
    #   str_detect(fname_raw, "annual") ~ "ann",
    #   str_detect(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") ~ str_extract(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") %>%
    #     str_remove_all("_bil") %>%
    #     str_remove("^_"),
    #   str_detect(fname_raw, "_(0[1-9]|1[0-2])_bil") ~ str_extract(fname_raw, "_(0[1-9]|1[0-2])_bil") %>%
    #     str_remove_all("_bil") %>%
    #     str_remove("^_"),
    #   TRUE ~ NA_character_
    # ),
    unit = case_when(
      theme == "ppt" ~ "mm",
      theme %in% c("tmean", "tmax", "tmin") ~ "C",
      TRUE ~ "unk"
    ),
    fname_clean = paste0(theme, "_", period, "_", unit, ".tif")
  )

# ==============================================================================
# Download Koppen Geiger data
# 1a) Setup
 
file_path  <- "data/raw"                  # top-level folder for spatial data
dir_name   <- "koppen_climate"            # subfolder for koppen data
zip_name   <- "koppen_geiger.zip"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://figshare.com/ndownloader/files/45057352"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")

# 1b) Create target directory if it doesn't exist
dir_create(target_dir, recurse = TRUE)

# 1c) Download ZIP if it doesn't already exist
if (!file_exists(zip_path)) {
  message("Downloading Köppen-Geiger data...")
  GET(zip_url, write_disk(zip_path, overwrite = TRUE))
} else {
  message("ZIP file already exists: ", zip_path)
}

# 1d) Unzip the contents
koppen_geiger <- unzip(zip_path, exdir = target_dir)
message("Unzipped to: ", target_dir)

# ==============================================================================
# Download PHZ data
# 2a) Setup

file_path  <- "data/raw"
dir_name   <- "phzm"
zip_name   <- "phzm.zip"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://prism.oregonstate.edu/projects/phm_data/phzm_us_grid_2023.zip"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")

# 2b) Create target directory if it doesn't exist
dir_create(target_dir, recurse = TRUE)

# 2c) Download ZIP if it doesn't already exist
if (!file_exists(zip_path)) {
  message("Downloading PHZM data...")
  GET(zip_url, write_disk(zip_path, overwrite = TRUE))
} else {
  message("ZIP file already exists: ", zip_path)
}

# 2d) Unzip the contents
phzm <- unzip(zip_path, exdir = target_dir)
message("Unzipped to: ", target_dir)

# ==============================================================================
# Download PRISM normals
# 3a) Set download directory using {prism}
prism_set_dl_dir(here("data/raw/prism"))

# 3b) download data  using {prism}
#       download annual normal mean temp (1991-2020; tmean = tmax - tmin)
get_prism_normals(type = "tmean",
                  resolution = "800m", 
                  annual = TRUE)

#       download annual normal precip  (1991-2020; ppt)
get_prism_normals(type = "ppt", 
                  resolution = "800m",
                  annual = TRUE)

#       download the monthly average normal precip  (1991-2020; ppt)
get_prism_normals(type="ppt", 
                  resolution = "800m", 
                  mon = 1:12,
                  keepZip = FALSE)

#       download the daily average precip (1991-2020; ppt)
get_prism_dailies(type="ppt", 
                  resolution = "800m", 
                  mon = 1:12,
                  keepZip = FALSE)

#       download the daily max temperature (1991-2020; tmax)
get_prism_dailies(type="ppt", 
                  resolution = "800m", 
                  mon = 1:12,
                  keepZip = FALSE)

#       download the daily average precip (1991-2020; tmin)
get_prism_dailies(type="ppt", 
                  resolution = "800m", 
                  mon = 1:12,
                  keepZip = FALSE)

# 3c) log download results
prism_files <- tibble(raw_files = prism_archive_ls())

write_csv(prism_files, here("data/log/prism_files.csv"))

# ------------------------------------------------------------------------------
# Project PRISM files into a common CRS

# verify expected files were downloaded -- 
#   note {prism} v0.2.3.9000 prism_archive_verify() is not working
 verify_prism_archive("data/raw/prism", 
                        output_csv = "data/log/prism_qc.csv"
                      )

# check CRS
# Ensure path to PRISM rasters
prism_dir <- here("data/raw/prism")

# List all .bil files
bil_files <- list.files(
  path = "data/raw/prism",
  pattern = "\\.bil$", 
  recursive = TRUE, 
  full.names = TRUE
)

# Show unique CRS strings
crs_summary %>% distinct(crs)

# Load a raster and check current CRS (should be GCS NAD83)
r <- rast("data/raw/prism/PRISM_tmax_30yr_normal_800mM5_annual_bil/PRISM_tmax_30yr_normal_800mM5_annual_bil.bil")

# Run the batch reprojector
#reproject_to_epsg5070_batch(bil_files)

#-------------------------------------------------------------------------------
# Rename the reprojected rasters
# make the rename values -- see rename_tbl$fname_clean
rename_tbl()

# add the `from` and `to` paths
rename_tbl <- rename_tbl %>%
  mutate(
    path_proj = path("data/intermediate/prism_epsg5070", 
                     path_ext_set(fname_raw, "tif")),
    path_renamed = path("data/intermediate/prism_epsg5070", fname_clean)
  )

# rename the files
walk2(rename_tbl$path_proj, rename_tbl$path_renamed, file_move)

# summarise results
rename_summary <- rename_tbl %>%
  mutate(
    # Parse temporal scale
    temporal_scale = case_when(
      str_detect(fname_clean, "_ann_") ~ "annual",
      str_detect(fname_clean, "_m[0-9]{2}_") ~ "monthly",
      str_detect(fname_clean, "_[0-9]{4}_") ~ "daily",
      TRUE ~ "unknown"
    )
  ) %>%
  count(theme, temporal_scale, name = "n_files") %>%
  arrange(theme, temporal_scale)
print(rename_summary)

#-------------------------------------------------------------------------------
# Stack and export annual temp rasters
temp_ann_files <- c("tmax_ann_C.tif", "tmean_ann_C.tif", "tmin_ann_C.tif")
file_path  <- "data/intermediate/prism_epsg5070"
output_path <- "data/processed/prism/"

prism_dir <- glue("{here()}/{file_path}")
output_dir <- glue("{here()}/{output_path}")

# Full path
temp_ann_paths <- file.path(prism_dir, temp_ann_files)

# Load and stack
temp_ann_C <- rast(temp_ann_paths)
names(temp_ann_C) <- c("tmax_ann_C", "tmean_ann_C", "tmin_ann_C")

# Inspect
print(temp_ann_C)

# Save stack to disk
writeRaster(temp_ann_C, 
            paste0(output_dir,"temp_ann_C_stack.tif"),
            overwrite = TRUE
            )

#-------------------------------------------------------------------------------
# Stack and export monthly and annual ppt rasters
# Paths
prism_dir <- here("data/intermediate/prism_epsg5070")
output_dir <- here("data/processed/prism")

# Stack 1: Annual Precipitation
ppt_ann_file <- file.path(prism_dir, "ppt_ann_mm.tif")
ppt_ann <- rast(ppt_ann_file)
names(ppt_ann) <- "ppt_ann_mm"

writeRaster(ppt_ann,
            filename = file.path(output_dir, "ppt_ann_mm_stack.tif"),
            overwrite = TRUE)

# Stack 2: Monthly Precipitation
ppt_month_files <- file.path(prism_dir, sprintf("ppt_m%02d_mm.tif", 1:12))
ppt_month <- rast(ppt_month_files)
names(ppt_month) <- sprintf("ppt_m%02d_mm", 1:12)

writeRaster(ppt_month,
            filename = file.path(output_dir, "ppt_monthly_stack.tif"),
            overwrite = TRUE)

#-------------------------------------------------------------------------------
# Stack and export daily temp rasters

# Define paths
src_dir <- here("data/intermediate/prism_epsg5070")
dst_dir <- here("data/processed/prism")


# List daily tmin/tmax files
daily_files <- dir_ls(src_dir) %>%
  keep(~ str_detect(path_file(.x), "^(tmin|tmax)_[0-9]{4}_C\\.tif$"))

# Copy to processed directory
file_copy(daily_files, dst_dir, overwrite = TRUE)

# List daily ppt files
daily_files <- dir_ls(src_dir) %>%
  keep(~ str_detect(path_file(.x), "^(ppt)_[0-9]{4}_mm\\.tif$"))

# Copy to processed directory
file_copy(daily_files, dst_dir, overwrite = TRUE)

#-------------------------------------------------------------------------------
# Remove prism_epsg5070 folder

# Source and destination folders
intermediate_dir <- here::here("data/intermediate/prism_epsg5070")
processed_dir <- here::here("data/processed/prism")

# List all .tif files
intermediate_files <- dir_ls(intermediate_dir, glob = "*.tif") %>% path_file()
processed_files <- dir_ls(processed_dir, glob = "*.tif") %>% path_file()

# Find any files in intermediate that are missing in processed
missing_files <- setdiff(intermediate_files, processed_files)

# Show result
if (length(missing_files) == 0) {
  message("All files have been safely copied. Ready to delete.")
} else {
  warning("Some files may be  missing in processed directory, check _stack:")
  print(missing_files)
}

# delete intermediate prism files
fs::dir_delete(here::here("data/intermediate/prism_epsg5070"))

# ==============================================================================
