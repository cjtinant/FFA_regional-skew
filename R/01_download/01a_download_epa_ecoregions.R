# ==============================================================================
# Script Name:    01a_download_epa_regions.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-04-15
# Last Updated:   2025-06-20      # update script header / output location
#
# Purpose:        This script downloads, processes, and prepares EPA/CEC
#                 Level I-IV Ecoregion data.
#
# Data URLs:
# -   https://www.epa.gov/eco-research/ecoregions
# -   https://www.epa.gov/eco-research/level-iii-and-iv-ecoregions-continental-united-states # nolint: line_length_linter.
# -   https://www.epa.gov/eco-research/ecoregions-north-america
#
# Workflow Summary:
# 1.   Download zipped archives, extract and organize data.
# 2.   Reproject shapefiles to a common CRS (US Albers Equal Area – EPSG:5070) 
# 3.   Clip Levels I–III to the spatial extent of Level IV (CONUS boundary) 
# 4.   Validate and repair geometries and coerce to consistent geometry type.
# 5.   Recalculate area in sq-km using a common CRS
# 6.   Export reprojected, clipped, cleaned data as a gpkg for downstream use.
#
# Output:
# -    Clean Ecoregion Level I - Level IV clipped to CONUS and in a common CRS.
#
# Dependencies:
# -    tidyverse: general data wrangling
# -    glue:      string interpolation
# -    here:      consistent relative paths
# -    sf:        handling spatial data
# -    units      unit conversion

# Notes:
# - Original metadata & layer files for each level are downloaded for reference.
# - Data sources are EPA/CEC shapefiles hosted via AWS links.
# - This script assumes internet access and local write permissions.
# =============================================================================

# load libraries
library(tidyverse)
library(glue)
library(here)
library(sf)
library(units)       # to convert from m² to km²

# Load function definitions
source(here("R/utils/download_data/download_ecoregion_resources.R"))

# ==============================================================================
# Level 1 Ecoregion Download
# 1a) Setup

file_path  <- "data/raw"     # top-level folder for spatial data
dir_name   <- "us_ecoregions"            # subfolder for ecoregions
zip_name   <- "na_eco_lev01.zip"
html_name  <- "NA_CEC_Eco_Level1.html"
lyr_name   <- "NA_CEC_Eco_Level1.lyr"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l1.zip" # nolint: line_length_linter.
meta_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.htm" # nolint: line_length_linter.
lyr_url  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.lyr" # nolint: line_length_linter.

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")
meta_path  <- glue("{target_dir}/{html_name}")

# 1b) Create directory, download unzip sf, remove ZIP, download metadata + layer

log_summary <- download_ecoregion_resources(
  target_dir = here::here("data/raw/us_ecoregions"),
  zip_url    = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l1.zip",
  zip_path   = here::here("data/raw/us_ecoregions/na_eco_lev01.zip"),
  meta_url   = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.htm",
  meta_path  = here::here("data/raw/epa_ecoregions/NA_CEC_Eco_Level1.htm"),
  lyr_url    = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.lyr",
  lyr_path   = here::here("data/raw/epa_ecoregions/NA_CEC_Eco_Level1.lyr"),
  remove_zip = TRUE
)

# 1c) check summary
log_summary

# ------------------------------------------------------------------------------
# Level 2 Ecoregion Download
# 1d) Setup

file_path  <- "data/raw"     # top-level folder for spatial data
dir_name   <- "us_ecoregions"            # subfolder for ecoregions
zip_name   <- "na_eco_lev02.zip"
html_name  <- "NA_CEC_Eco_Level2.html"
lyr_name   <- "NA_CEC_Eco_Level2.lyr"
meta_name  <- "NA_CEC_Eco_Level2.html"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l2.zip"
meta_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level2.htm"
lyr_url  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level2.lyr"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")
meta_path  <- glue("{target_dir}/{zip_name}")

# 1e) Create directory, download + unzip sf, remove ZIP, dl metadata + layer
download_ecoregion_resources(target_dir, 
                             zip_url, zip_path,
                             meta_url, meta_path,
                             lyr_url, lyr_path,
                             remove_zip = FALSE,
                             log_csv = here::here("data/log/download_log.csv")) 

# 2c) check summary
log_summary <- download_ecoregion_resources(
  target_dir = here::here("data/raw/us_ecoregions"),
  zip_url    = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l1.zip",
  zip_path   = here::here("data/raw/us_ecoregions/na_eco_lev01.zip"),
  meta_url   = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.htm",
  meta_path  = here::here("data/raw/us_ecoregions/NA_CEC_Eco_Level1.htm"),
  lyr_url    = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.lyr",
  lyr_path   = here::here("data/raw/us_ecoregions/NA_CEC_Eco_Level1.lyr"),
  remove_zip = TRUE
)

# 1f) check summary
log_summary

# ------------------------------------------------------------------------------
# Level 3 Ecoregion Download

# 1g) Setup
file_path  <- "data/raw"     # top-level folder for spatial data
dir_name   <- "us_ecoregions"            # subfolder for ecoregions
zip_name   <- "na_eco_lev03.zip"
html_name  <- "NA_CEC_Eco_Level3.html"
lyr_name   <- "NA_CEC_Eco_Level3.lyr"
meta_name  <- "NA_CEC_Eco_Level3.html"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.zip"
meta_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.htm"
lyr_url  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.lyr"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")
meta_path  <- glue("{target_dir}/{zip_name}")

# 1h) Create directory, download + unzip sf, remove ZIP, dl metadata + layer
log_summary <- download_ecoregion_resources(target_dir, 
                             zip_url, zip_path,
                             meta_url, meta_path,
                             lyr_url, lyr_path,
                             remove_zip = FALSE,
                             log_csv = here::here("data/log/download_log.csv")) 

# 1i) check summary
log_summary

# ------------------------------------------------------------------------------
# Level 4 Ecoregion Download

# 1j) Setup
file_path  <- "data/raw"     # top-level folder for spatial data
dir_name   <- "us_ecoregions"            # subfolder for ecoregions
zip_name <- "us_eco_lev04.zip"
html_name  <- "us_epa_Eco_Level4.htm"
lyr_name   <- "us_epa_Eco_Level4.lyr"
meta_name  <- "us_epa_Eco_Level4.html"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
zip_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/us_eco_l4.zip"
meta_url <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/Eco_Level_IV_US.html"
lyr_url  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/Eco_Level_IV_US.lyr"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")
meta_path  <- glue("{target_dir}/{zip_name}")

# 1k) Create directory, download + unzip sf, remove ZIP, dl metadata + layer
log_summary <- download_ecoregion_resources(target_dir, 
                                            zip_url, zip_path,
                                            meta_url, meta_path,
                                            lyr_url, lyr_path,
                                            remove_zip = FALSE,
                                            log_csv = here::here("data/log/download_log.csv"))  # nolint: line_length_linter.

# 1l) check summary
log_summary

# =============================================================================
# 2. Clip the extent of Ecoregion Level 1 to Level 3 to CONUS extent

# 2a) Setup
file_path  <- "data/raw"     # top-level folder for spatial data
dir_name   <- "us_ecoregions"
file_name  <- "us_eco_l4_no_st.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

# 2b) Read in ecoregions
# Read in the Level 4 shapefile (the "CONUS" extent/boundary)
level4_usgs_albers <- st_read(target_file)

terra::crs(level4_usgs_albers)
level4_albers <- st_transform(level4_usgs_albers, 5070)

# Read Level 1–3 ecoregions
file_name  <- "NA_CEC_Eco_Level1.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")
level1 <- st_read(target_file)

file_name  <- "NA_CEC_Eco_Level2.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")
level2 <- st_read(target_file)

file_name  <- "NA_CEC_Eco_Level3.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")
level3 <- st_read(target_file)

# 2c) Check the CRS to ensure they match; if not, reproject
crs_level4 <- st_crs(level4_albers)$input
# e.g. might show EPSG:5070

crs_level1 <- st_crs(level1)$input
# e.g. might show a Lambert Azimuthal 

# 2d) Transform levels 1–3 into Level 4’s Albers
level1_albers <- st_transform(level1, st_crs(level4_albers))
level2_albers <- st_transform(level2, st_crs(level4_albers))
level3_albers <- st_transform(level3, st_crs(level4_albers))

# =============================================================================
# 3. Clip Levels I–III to the spatial extent of Level IV (CONUS boundary)

# 3a) Merge Level 4 to prepare for clip
level4_merged <- st_union(level4_albers)

# 3b) Clip Level 1 to 3 ecoregions by Level 4 extent
level1_conus <- st_intersection(level1_albers, level4_merged)
level2_conus <- st_intersection(level2_albers, level4_merged)
level3_conus <- st_intersection(level3_albers, level4_merged)

# ==============================================================================
# 4. Validate and repair geometries using sf::st_make_valid() and coerce to
#      consistent geometry types (MULTIPOLYGON).

# Fix any invalid geometries
level1_conus <- st_make_valid(level1_conus)
level2_conus <- st_make_valid(level2_conus)
level3_conus <- st_make_valid(level3_conus)

# Extract just the polygonal part from any geometry collections
level1_conus <- st_collection_extract(level1_conus, "POLYGON")
level2_conus <- st_collection_extract(level2_conus, "POLYGON")
level3_conus <- st_collection_extract(level3_conus, "POLYGON")

# Cast to MULTIPOLYGON to ensure a uniform type
level1_conus <- st_cast(level1_conus, "MULTIPOLYGON")
level2_conus <- st_cast(level2_conus, "MULTIPOLYGON")
level3_conus <- st_cast(level3_conus, "MULTIPOLYGON")

# ==============================================================================
# 5.   Recalculate area in sq-km using a common CRS

# Drop length and area
level1_conus <- level1_conus  %>% select(-c(Shape_Leng, Shape_Area))
level2_conus <- level2_conus  %>% select(-c(Shape_Leng, Shape_Area))
level3_conus <- level3_conus  %>% select(-c(Shape_Leng, Shape_Area))
level4_conus <- level4_albers %>% select(-c(Shape_Leng, Shape_Area))

# recalculate area
level1_conus <- level1_conus %>%
  mutate(area_km2 = set_units(st_area(.), "km^2") %>% drop_units())

level2_conus <- level2_conus %>%
  mutate(area_km2 = set_units(st_area(.), "km^2") %>% drop_units())

level3_conus <- level3_conus %>%
  mutate(area_km2 = set_units(st_area(.), "km^2") %>% drop_units())

level4_conus <- level4_conus %>%
  mutate(area_km2 = set_units(st_area(.), "km^2") %>% drop_units())

# ==============================================================================
# 6.   Export reprojected, clipped, cleaned data as a gpkg for downstream use.

# Directory to store data as a geopackage
output_dir <- here("data/processed/ecoregions")


# Write as GeoPackage (UTF-8, clean field names)
st_write(level1_conus,
         dsn = file.path(output_dir, "us_eco_levels.gpkg"),
         layer = "us_eco_l1",
         delete_layer = FALSE)

st_write(level2_conus,
         dsn = file.path(output_dir, "us_eco_levels.gpkg"),
         layer = "us_eco_l2",
         delete_layer = FALSE)

st_write(level3_conus,
         dsn = file.path(output_dir, "us_eco_levels.gpkg"),
         layer = "us_eco_l3",
         delete_layer = FALSE)

st_write(level4_conus,
         dsn = file.path(output_dir, "us_eco_levels.gpkg"),
         layer = "us_eco_l4",
         delete_layer = FALSE)

st_write(level4_merged,
         dsn = file.path(output_dir, "us_eco_levels.gpkg"),
         layer = "us_eco_l4_merged",
         delete_layer = FALSE)
