# ==============================================================================
# Script: 07_download_climate_covariates.R
# Purpose: Download and prepare covariate data to support regional skew modeling
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Covariates:
# - PRISM Climate Normals (4km resolution, .bil format)
#     - Annual mean precipitation
#     - Annual mean temperature
#     - Monthly precipitation
#     - Monthly temperature
# - Site location data from sites_pk_gt_20.csv

# Outputs:
# - data/clean/data_covariates_climate.csv
# - data/meta/data_covariates_climate.csv

# Outputs:
# - data/clean/data_covariates_climate.csv
#
# ==============================================================================

library(tidyverse)
library(here)
library(sf)
library(prism)
library(terra)
library(janitor)

# ------------------------------------------------------------------------------
# Make PRISM metadata 
#    accessed from https://prism.oregonstate.edu/fetchData.php
#    and fed into ChatGPT

prism_metadata <- tribble(
  ~variable, ~time_period, ~resolution, ~units, ~description, ~source,
  
  "Precipitation", "1991-2020 Annual", "4km", "Millimeters", 
  "Average annual total precipitation derived from monthly grids.", 
  "https://prism.oregonstate.edu/normals/",
  
  "Precipitation", "1991-2020 Monthly", "4km", "Millimeters", 
  "Monthly total precipitation normals.", 
  "https://prism.oregonstate.edu/normals/",
  
  "Temperature (Mean)", "1991-2020 Annual", "4km", "Degrees C", 
  "Average annual mean temperature derived from monthly grids.", 
  "https://prism.oregonstate.edu/normals/",
  
  "Temperature (Mean)", "1991-2020 Monthly", "4km", "Degrees C", 
  "Monthly mean temperature normals.", 
  "https://prism.oregonstate.edu/normals/"
)


prism_metadata_spatial <- tribble(
  ~attribute, ~value,
  
  "Variable", "Precipitation & Temperature",
  "Time Period", "1991-2020 Normals",
  "Resolution", "4km (~0.04166667 degrees)",
  "Projection", "Geographic Coordinate System (Lat/Long)",
  "Datum", "North American Datum 1983 (NAD83)",
  "Ellipsoid", "Geodetic Reference System 80 (GRS80)",
  "Cell Size", "0.04166667 degrees",
  "Extent West", "-125.0208333",
  "Extent East", "-66.4791667",
  "Extent North", "49.9375",
  "Extent South", "24.0625",
  "Units Precipitation", "Millimeters",
  "Units Temperature", "Degrees Celsius",
  "Source", "https://prism.oregonstate.edu/normals/",
  "Method", "PRISM model - Parameter-elevation Regressions on Independent Slopes Model (Daly et al. 2008, 2015)"
)

# ------------------------------------------------------------------------------
# Set PRISM Download Directory
prism_set_dl_dir(here("data/raw/prism"))

# ------------------------------------------------------------------------------
# Load Site Locations
sites <- read_csv(here("data/clean/sites_pk_gt_20.csv")) %>%
  distinct(site_no, dec_lat_va, dec_long_va) %>%
  drop_na(dec_lat_va, dec_long_va)

sites_sf <- sites %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4326)

# ------------------------------------------------------------------------------
# Download PRISM Normals (run once to download)

get_prism_normals(type = "ppt", resolution = "4km", annual = TRUE)
get_prism_normals(type = "tmean", resolution = "4km", annual = TRUE)

# get_prism_normals(type = "ppt", mon = 1:12, resolution = "4km")
# get_prism_normals(type = "tmean", mon = 1:12, resolution = "4km")


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
# Load & Extract PRISM Rasters to Site Locations

prism_files <- prism_archive_ls()

ppt_dirs   <- prism_files[str_detect(prism_files, "ppt_30yr_normal_4kmM")]
tmean_dirs <- prism_files[str_detect(prism_files, "tmean_30yr_normal_4kmM")]

ppt_rast   <- build_prism_rasters(ppt_dirs)
tmean_rast <- build_prism_rasters(tmean_dirs)

ppt_cov   <- terra::extract(ppt_rast, vect(sites_sf))
tmean_cov <- terra::extract(tmean_rast, vect(sites_sf))

# ------------------------------------------------------------------------------
# Clean & Rename Covariate Data for Modeling

ppt_cov_clean <- ppt_cov %>%
  rename_with(
    ~ str_replace_all(., c(
      "PRISM_ppt_30yr_normal_4kmM4_0" = "ppt_M0",
      "PRISM_ppt_30yr_normal_4kmM4_"  = "ppt_M",
      "_bil" = "_mm"
    )),
    .cols = starts_with("PRISM_ppt")
  ) %>%
  clean_names() %>%
  rename(ppt_ann_mm = ppt_mannual_mm)

tmean_cov_clean <- tmean_cov %>%
  rename_with(
    ~ str_replace_all(., c(
      "PRISM_tmean_30yr_normal_4kmM5_0" = "tmean_M0",
      "PRISM_tmean_30yr_normal_4kmM5_"  = "tmean_M",
      "_bil" = "_C"
    )),
    .cols = starts_with("PRISM_tmean")
  ) %>%
  clean_names() %>%
  rename(tmean_ann_C = tmean_mannual_c)

# ------------------------------------------------------------------------------
# Join Climate Covariates + Site Info

covariates_climate <- sites %>%
  bind_cols(
    ppt_cov_clean %>% select(-id),
    tmean_cov_clean %>% select(-id)
  ) %>%
  relocate(site_no, dec_lat_va, dec_long_va, .before = everything())

# ------------------------------------------------------------------------------
# Export Final Climate Covariates

write_csv(covariates_climate, here("data/clean/data_covariates_climate.csv"))

write_csv(prism_metadata, here("data/meta/data_covariates_climate_metadata.csv"))
write_csv(prism_metadata_spatial, here("data/meta/data_covariates_climate_spatial.csv"))

message("Finished downloading, extracting, and cleaning PRISM climate covariates.")
