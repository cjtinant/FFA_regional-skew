# ==============================================================================
# Script: 01c_download_climate.R
# Purpose: Download and prepare climate data
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
# Last Updated: May 13 2025
#
# Summary:
#
# Covariates:
# -   Koppen Geiger (1 km resolution, .tif format)

## - PRISM Climate Normals (4km resolution, .bil format)
##     - Annual mean precipitation
##     - Annual mean temperature
##     - Monthly precipitation
##     - Monthly temperature
## - Site location data from sites_pk_gt_20.csv

## Outputs:
## - data/clean/data_covariates_climate.csv
## - data/meta/data_covariates_climate.csv

# Outputs:
## - data/clean/data_covariates_climate.csv
##
#
# Workflow
#
# ==============================================================================
# library(tidyverse)
# library(here)
# library(sf)

# library(terra)
# library(janitor)
library(fs)                  # file interface system
library(here)
library(glue)
library(httr)
library(prism)

# ==============================================================================
# Download Koppen Geiger 1-km data

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

# ------------------------------------------------------------------------------
# Download Prism xx data

# install.packages("devtools")
# library(devtools)
# install_github("ropensci/prism")


# Set set download directory
prism_set_dl_dir(here("data/raw/prism"))

# download average annual temp and ppt  (1991-2020)
get_prism_normals(type = "tmean", resolution = "800m", annual = TRUE)
get_prism_normals(type = "ppt", resolution = "800m", annual = TRUE)

# download the average monthly precip (1991-2020)
get_prism_normals(type="ppt", 
                  resolution = "800m", 
                  mon = 1:12,
                  keepZip = FALSE)

# download the daily average precip (1991-2020)
get_prism_normals(type="ppt", 
                  resolution = "800m", 
                  annual = TRUE,
                  day = TRUE,
                  keepZip = FALSE)

# download the daily average high temp (1991-2020)
get_prism_normals(type="tmax", 
                  resolution = "800m", 
                  annual = TRUE,
                  day = TRUE,
                  keepZip = FALSE)

# download the daily average low temp (1991-2020)
get_prism_normals(type="tmin", 
                  resolution = "800m", 
                  annual = TRUE,
                  day = TRUE,
                  keepZip = FALSE)






