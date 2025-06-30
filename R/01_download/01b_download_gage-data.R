# ==============================================================================
# Script Name: 01b_download-gage-data.R
# Author: Charles Jason Tinant
# Date Created: April 2025
# Last update: June 21, 2025           # update script to fit with folder struct
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
# 3. Download USGS site data within each tile
(siteType = "ST" parameterCd = "00060")
# 4. Filter to remove canals, ditches, and sites without peak flow records
# 5. Download peak flow records for filtered sites (service = "pk")
# 6. Convert sites to spatial format and clip to Great Plains extent
# 7. Export CSV outputs for all sites, peakflow-only sites, and clipped sites
#
# Output Files:
# - data/sites_all_in_bb.csv        → All USGS sites within bounding box
# - data/sites_all_peak_in_bb.csv   → Sites with peak flow data in bounding box
# - data/sites_pk_eco_only.csv      → Peak flow sites within GP Ecoregion
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
library(dataRetrieval)  # Retrieval functions for USGS and EPA hydro & wq data
library(dplyr)
library(glue)           # For string interpolation
library(here)           # A simpler way to find files
library(purrr)
library(sf)             # Simple features for R

# ------------------------------------------------------------------------------
# 1) Load Level 1 Ecoregion

file_path  <- "data/processed"     # top-level folder for spatial data
dir_name   <- "us_ecoregions"     # subfolder for level 1 ecoregions
file_name <- "us_eco_levels.gpkg"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

# make a check of layers in us_eco_levels
st_layers(target_file)

message("Reading Level 1 ecoregions from: ", target_file)
eco_lev1 <- st_read(target_file, layer = "us_eco_l1")

# (optional) check the file -- which shows the CONUS
# head(eco_lev1)

# set coordinate system for transform
crs_new <- 4326     # WGS 84 Geographic; Unit: degree

# Transform projection to geographic
eco_lev1_geo <- st_transform(eco_lev1, crs = crs_new)

# Filter to just GREAT PLAINS before processing geometry
eco_lev1_gp_only <- eco_lev1_geo %>%
  janitor::clean_names() %>%
  filter(na_l1name == "GREAT PLAINS")

# (optional) check results
# glimpse(eco_lev1_gp_only)

# -----------------------------------------------------------------------------
# 2) Download peakflow data
# -----------------------------------------------------------------------------

# -- Define a Bounding Box ----------------------------------------------------
bbox_gp <- st_bbox(eco_lev1_gp_only)

# --- Set resolution for horizontal (lon) and vertical (lat) splits -----------
max_width <- 1.0    # degrees longitude
max_height <- 2.5   # degrees latitude

# --- Create sequences of breakpoints -----------------------------------------
xmin_seq <- seq(bbox_gp["xmin"], bbox_gp["xmax"] - max_width, by = max_width)
xmax_seq <- pmin(xmin_seq + max_width, bbox_gp["xmax"])

ymin_seq <- seq(bbox_gp["ymin"], bbox_gp["ymax"] - max_height, by = max_height)
ymax_seq <- pmin(ymin_seq + max_height, bbox_gp["ymax"])

# --- Create all combinations of xmin/xmax and ymin/ymax ----------------------
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
  bbox_vector <- paste(
    bbox_row$xmin, bbox_row$ymin, bbox_row$xmax, bbox_row$ymax, sep = ","
    )
  
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

# --- Combine all site data into a single data frame --------------------------
sites_all_in_bb <- bind_rows(sites_data_list)

# --- Export all sites data ---------------------------------------------------
# Ensure output folder exists
output_dir <- here("data", "raw", "peakflow_gages")
fs::dir_create(output_dir)

write_csv(sites_all_in_bb, here("data",
                                "raw",
                                "peakflow_gages",
                                "sites_all_in_bb.csv"))

# (optional) read in saved data
# sites_all_in_bb <- read_csv(here("data",
#                                  "raw",
#                                  "peakflow_gages",
#                                  "sites_all_in_bb.csv"))

# -----------------------------------------------------------------------------
# 3) Filter peakflow data
# -----------------------------------------------------------------------------

# --- Drop canal ditch sites --------------------------------------------------
sites_st_only_in_bb <- sites_all_in_bb %>%
  filter(site_tp_cd == "ST")

ck_sites_st_only <- anti_join(sites_all_in_bb, sites_st_only_in_bb)

# ---------------------------------------------------------
# keep sites inside Great Plains Ecoregion

# convert stations into a spatial format (sf) object
sites_all_in_bb_geo <- st_as_sf(sites_all_in_bb,
                         coords = c("dec_long_va",        # note x goes first
                                    "dec_lat_va"),
                         crs = {crs_new},     # WGS 84 Geographic; Unit: degree
                         remove = FALSE)      # don't remove lat/lon cols

sites_pk_eco_only <- st_intersection(sites_all_in_bb_geo, eco_lev1_gp_only)

# ------------------------------------------------------------------------------
# EXPORT — Great Plains Peakflow Sites (filtered spatial + tabular)
# ------------------------------------------------------------------------------

# 2. Drop geometry and write tabular CSV
write_csv(
  st_drop_geometry(sites_pk_eco_only),
  file.path(output_dir, "sites_pk_eco_only.csv")
)

# 3. Write spatial version to GeoPackage
st_write(
  sites_pk_eco_only,
  dsn = file.path(output_dir, "sites_pk_eco_only.gpkg"),
  layer = "sites_pk_eco_only",
  delete_layer = TRUE,    # overwrite if rerun
  quiet = TRUE
)

# 4. QA Messages
message("✅ Export complete:")
message(" - Tabular:   ", file.path(output_dir, "sites_pk_eco_only.csv"))
message(" - Spatial:   ", file.path(output_dir, "sites_pk_eco_only.gpkg"))
message(" - Count of sites inside Great Plains: ", nrow(sites_pk_eco_only))

# Optional: check for missing coordinates (shouldn’t happen, but just in case)
n_missing_coords <- sites_pk_eco_only %>%
  filter(is.na(dec_lat_va) | is.na(dec_long_va)) %>%
  nrow()

if (n_missing_coords > 0) {
  warning("⚠️  Missing lat/lon coordinates in ", n_missing_coords, " rows.")
}
