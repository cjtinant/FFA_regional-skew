# ==============================================================================
# Script Name: 02_get-gage-data.R
# Author: Charles Jason Tinant
# Date Created: April 2025
#
# Purpose:
# This script downloads, processes, and filters USGS peak flow gage data within 
# the Great Plains Level 1 Ecoregion. It uses spatial data to define the area 
# of interest and queries USGS National Water Information System (NWIS) services 
# for site and peak flow data.
#
# Workflow Summary:
# 1. Load Level 1 Ecoregion shapefile and isolate Great Plains extent
# 2. Generate bounding box grid tiles across Great Plains extent
# 3. Download USGS site data within each tile (siteType = "ST", parameterCd = "00060")
# 4. Filter to remove canals, ditches, and sites without peak flow records
# 5. Download peak flow records for filtered sites (service = "pk")
# 6. Convert sites to spatial format and clip to Great Plains extent
# 7. Export multiple CSV outputs for all sites, peakflow-only sites, and clipped sites
#
# Output Files:
# - data/sites_all_in_bb.csv        → All USGS sites within bounding box
# - data/sites_all_peak_in_bb.csv   → Sites with peak flow data in bounding box
# - data/sites_pk_eco_only.csv      → Peak flow sites within Great Plains ecoregion
#
# Dependencies:
# - tidyverse     → Data wrangling & visualization
# - glue          → String interpolation
# - here          → File paths
# - sf            → Spatial data (simple features)
# - dataRetrieval → Access USGS NWIS data
# - process_geometries.R → Custom helper functions for cleaning sf geometries
#
# Notes:
# - Requires internet access to download data from USGS NWIS
# - Bounding box grid helps avoid request size limitations in NWIS queries
# - Uses a batch download approach for peak flow data retrieval
# - Great Plains extent is defined using EPA Level 1 Ecoregion shapefiles
# ============================================================================== 

# ------------------------------------------------------------------------------
# libraries
library(tidyverse)      # Load 'Tidyverse' packages: ggplot2, dplyr, tidyr, 
#                                 readr, purrr, tibble, stringr, forcats
library(glue)           # For string interpolation
library(here)           # A simpler way to find files
library(sf)             # Simple features for R
library(dataRetrieval)  # Retrieval functions for USGS and EPA hydro & wq data

# scripts:
source("scripts/f_process_geometries.R")

# ------------------------------------------------------------------------------
# 1) Load ecoregion data and transform to geographic

file_path  <- "data_spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev01"     # subfolder for level 1 ecoregions
file_name <- "us_eco_l1.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

eco_lev1 <- st_read(target_file)

# set coordinate system for transform
crs_new <- 4326     # WGS 84 Geographic; Unit: degree

# transform and keep only the great plains
eco_lev1_gp_geo <- eco_lev1 %>%
  st_transform(crs = {crs_new}) %>%
  process_geometries() %>%
  janitor::clean_names() %>%
  filter(na_l1name == "GREAT PLAINS")

# ---------------------------------------------------------
# 2) Define a Bounding Box

bbox_orig <- st_bbox(eco_lev1_gp_geo)

# Set resolution for horizontal (lon) and vertical (lat) splits
max_width <- 1.0    # degrees longitude
max_height <- 2.5   # degrees latitude

# Compute bbox
bbox_orig <- st_bbox(eco_lev1_gp_geo)

# Create sequences of breakpoints
xmin_seq <- seq(bbox_orig["xmin"], bbox_orig["xmax"] - max_width, by = max_width)
xmax_seq <- pmin(xmin_seq + max_width, bbox_orig["xmax"])

ymin_seq <- seq(bbox_orig["ymin"], bbox_orig["ymax"] - max_height, by = max_height)
ymax_seq <- pmin(ymin_seq + max_height, bbox_orig["ymax"])

# Create all combinations of xmin/xmax and ymin/ymax
grid_boxes <- expand.grid(
  xmin = xmin_seq,
  ymin = ymin_seq
) %>%
  mutate(
    xmax = xmin + max_width,
    ymax = ymin + max_height,
    index = row_number()
  )

# initialize a list
sites_data_list <- vector("list", nrow(grid_boxes))

# go and get umm!!!
for (i in seq_len(nrow(grid_boxes))) {
  bbox_row <- grid_boxes[i, ]
  bbox_vector <- paste(bbox_row$xmin, bbox_row$ymin, bbox_row$xmax, bbox_row$ymax, sep = ",")
  
  message("Trying grid tile ", i, " with bbox: ", bbox_vector)
  
  sites_data <- tryCatch(
    {
      whatNWISsites(
        bBox = bbox_vector,
        siteType = "ST",
        parameterCd = "00060"
      )
    },
    error = function(e) {
      message(paste("Error in grid tile", i, ":", e$message))
      NULL
    }
  )
  
  if (!is.null(sites_data) && nrow(sites_data) > 0) {
    sites_data$tile_id <- i
    sites_data_list[[i]] <- sites_data
  }
  
  Sys.sleep(0.5)
}

# Combine all site data into a single data frame
sites_all_in_bb <- bind_rows(sites_data_list)

# Export all sites data
write_csv(sites_all_in_bb, "data/sites_all_in_bb.csv")

# ---------------------------------------------------------
# Drop canal ditch sites

sites_st_only_in_bb <- sites_all_in_bb %>%
  filter(site_tp_cd == "ST")

ck_sites_st_only <- anti_join(sites_all_in_bb, sites_st_only_in_bb)

# ---------------------------------------------------------
# Get all peakflow data in bounding box

# Set batch size
batch_size <- 1000

# Split your sites into batches
site_batches <- split(sites_st_only_in_bb$site_no, 
                      ceiling(
                        seq_along(sites_st_only_in_bb$site_no) / batch_size))

# Initialize list to store results
pk_data_list <- vector("list", length(site_batches))

# Loop over each batch and query peak flow data
for (i in seq_along(site_batches)) {
  message("Processing batch ", i, " of ", length(site_batches))
  
  pk_data_list[[i]] <- tryCatch(
    {
      whatNWISdata(
        siteNumber = site_batches[[i]],
        service = "pk"
      )
    },
    error = function(e) {
      message("Error in batch ", i, ": ", e$message)
      NULL
    }
  )
  
  # Be kind to the API
  Sys.sleep(0.5)
}

# Combine all batches into one data frame
sites_all_pk_in_bb <- bind_rows(pk_data_list)

# Export all peakflow sites
write_csv(sites_all_pk_in_bb, "data/sites_all_peak_in_bb.csv")

# ---------------------------------------------------------
# Drop canal ditch sites
sites_st_only_in_bb <- sites_all_pk_in_bb %>%
  filter(site_tp_cd == "ST")

ck_sites_st_only <- anti_join(sites_all_in_bb, sites_st_only_in_bb,
                              by = join_by(agency_cd, site_no, station_nm, 
                                           site_tp_cd, dec_lat_va, dec_long_va)
                              )

# ---------------------------------------------------------
# Get all peakflow data in the bounding box

# Set batch size
batch_size <- 1000

# Split your sites into batches
site_batches <- split(sites_st_only_data$site_no, 
                      ceiling(seq_along(
                        sites_st_only_in_bb$site_no) / batch_size))

# Initialize list to store results
pk_data_list <- vector("list", length(site_batches))

# Loop over each batch and query peak flow data
for (i in seq_along(site_batches)) {
  message("Processing batch ", i, " of ", length(site_batches))
  
  pk_data_list[[i]] <- tryCatch(
    {
      whatNWISdata(
        siteNumber = site_batches[[i]],
        service = "pk"
      )
    },
    error = function(e) {
      message("Error in batch ", i, ": ", e$message)
      NULL
    }
  )
  
  # Be kind to the API
  Sys.sleep(0.5)
}

# Combine all batches into one data frame
sites_all_pk_in_bb <- bind_rows(pk_data_list)

# Export all peakflow sites
write_csv(sites_all_pk_in_bb, "data/sites_all_peak_in_bb")

# clean up Global environment
rm(batch_size,
   site_batches,
   pk_data_list,
   sites_data_list,
   i
)

# ---------------------------------------------------------
# keep sites inside Great Plains ecoregion

# convert stations into a spatial format (sf) object
sites_all_pk_in_bb <- st_as_sf(sites_all_pk_in_bb,
                         coords = c("dec_long_va",        # note x goes first
                                    "dec_lat_va"),
                         crs = {crs_new},     # WGS 84 Geographic; Unit: degree
                         remove = FALSE)      # don't remove lat/lon cols

sites_pk_eco_only <- st_intersection(sites_all_pk_in_bb, eco_lev1_gp_geo)

# Export all peakflow sites
write_csv(sites_pk_eco_only, "data/sites_pk_eco_only.csv")

