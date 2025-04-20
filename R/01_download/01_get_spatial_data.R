# ==============================================================================
# Script Name: 01_get-spatial-data.R
# Author: Charles Jason Tinant
# Date Created: April 2025
#
# Purpose:
# This script downloads, processes, and prepares spatial data for the analysis 
# of USGS peak flow gage data within ecological regions of the continental 
# United States (CONUS). The script focuses on obtaining and standardizing 
# Level 1 through Level 4 ecoregion shapefiles from EPA/CEC sources.
#
# Workflow Summary:
# 1. Download Level 1 to Level 4 ecoregion shapefiles from EPA/CEC servers
# 2. Unzip and organize data into local directories
# 3. Clip Levels 1-3 to the extent of Level 4 (CONUS boundary)
# 4. Transform projections to match Level 4 (US Albers Equal Area)
# 5. Correct invalid geometries and standardize geometry types
# 6. Save clean, clipped shapefiles for Levels 1-3 for downstream analysis
#
# Output:
# - Clean shapefiles for Level 1, Level 2, and Level 3 ecoregions clipped to CONUS
# - Folder structure:
#     data/spatial/
#       ├── us_eco_lev01/us_eco_l1.shp
#       ├── us_eco_lev02/us_eco_l2.shp
#       ├── us_eco_lev03/us_eco_l3.shp
#       └── us_eco_lev04/ (original Level 4 data)
#
# Dependencies:
# - tidyverse: general data wrangling
# - glue: string interpolation
# - here: consistent relative paths
# - sf: handling spatial data
#
# Notes:
# - Original metadata and layer files for each level are downloaded for reference.
# - Data sources are EPA/CEC shapefiles hosted via AWS links.
# - This script assumes internet access and local write permissions.
# ============================================================================== 

# ------------------------------------------------------------------------------
# libraries
library(tidyverse)   # Load 'Tidyverse' packages: ggplot2, dplyr, tidyr, 
#                                 readr, purrr, tibble, stringr, forcats
library(glue)        # For string interpolation
library(here)        # A simpler way to find files
library(sf)          # Simple features for R

# ------------------------------------------------------------------------------
# Level 1 Ecoregion Download
# 1) Setup

file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev01"     # subfolder for level 1 ecoregions
zip_name   <- "us_eco_lev01.zip"
html_name  <- "NA_CEC_Eco_Level1.htm"
lyr_name   <- "NA_CEC_Eco_Level1.lyr"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
url_zip <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l1.zip"
url_meta <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.htm"
url_lyr  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.lyr"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")

# ------------------------------------------------------------------------------
# 2) Create directory, download + unzip shapefile, remove ZIP, download metadata + layer

target_dir %>%
  # A) Create the directory if it doesn't exist
  {
    dir.create(., showWarnings = FALSE, recursive = TRUE)
    .
  } %>%
  # B) Download shapefile ZIP
  {
    download.file(url_zip, destfile = zip_path, mode = "wb")
    .
  } %>%
  # C) Use system call to unzip
  {
    system(
      paste(
        "unzip",
        shQuote(zip_path),
        "-d",
        shQuote(.)
      )
    )
    .
  } %>%
  # E) Download the metadata (HTML)
  {
    download.file(url_meta, destfile = html_path, mode = "wb")
    .
  } %>%
  # F) Download the layer file (LYR)
  {
    download.file(url_lyr, destfile = lyr_path, mode = "wb")
    .
  }
# ------------------------------------------------------------------------------
# Level 2 Ecoregion Download
# 1) Setup

file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev02"     # subfolder for level 1 ecoregions
zip_name   <- "us_eco_lev02.zip"
html_name  <- "NA_CEC_Eco_Level2.htm"
lyr_name   <- "NA_CEC_Eco_Level2.lyr"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
url_zip <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l2.zip"
url_meta <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level2.htm"
url_lyr  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level2.lyr"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")

# ------------------------------------------------------------------------------
# 2) Create directory, download + unzip shapefile, remove ZIP, download metadata + layer

target_dir %>%
  # A) Create the directory if it doesn't exist
  {
    dir.create(., showWarnings = FALSE, recursive = TRUE)
    .
  } %>%
  # B) Download shapefile ZIP
  {
    download.file(url_zip, destfile = zip_path, mode = "wb")
    .
  } %>%
  # C) Use system call to unzip
  {
    system(
      paste(
        "unzip",
        shQuote(zip_path),
        "-d",
        shQuote(.)
      )
    )
    .
  } %>%
  # E) Download the metadata (HTML)
  {
    download.file(url_meta, destfile = html_path, mode = "wb")
    .
  } %>%
  # F) Download the layer file (LYR)
  {
    download.file(url_lyr, destfile = lyr_path, mode = "wb")
    .
  }
# ------------------------------------------------------------------------------
# Level 3 Ecoregion Download
# 1) Setup
file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name  <- "us_eco_lev03"
zip_name <- "us_eco_lev03.zip"
html_name  <- "NA_CEC_Eco_Level3.htm"
lyr_name   <- "NA_CEC_Eco_Level3.lyr"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
url_zip <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.zip"
url_meta <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.htm"
url_lyr  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.lyr"

# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")

# ------------------------------------------------------------------------------
# 2) Create directory, download + unzip shapefile, remove ZIP, download metadata + layer

target_dir %>%
  # A) Create the directory if it doesn't exist
  {
    dir.create(., showWarnings = FALSE, recursive = TRUE)
    .
  } %>%
  # B) Download shapefile ZIP
  {
    download.file(url_zip, destfile = zip_path, mode = "wb")
    .
  } %>%
  # C) Use system call to unzip
  {
    system(
      paste(
        "unzip",
        shQuote(zip_path),
        "-d",
        shQuote(.)
      )
    )
    .
  } %>%
  # E) Download the metadata (HTML)
  {
    download.file(url_meta, destfile = html_path, mode = "wb")
    .
  } %>%
  # F) Download the layer file (LYR)
  {
    download.file(url_lyr, destfile = lyr_path, mode = "wb")
    .
  }


# ------------------------------------------------------------------------------
# Level 4 Ecoregion Download
# 1) Setup
file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name  <- "us_eco_lev04"
zip_name <- "us_eco_lev04.zip"
html_name  <- "NA_CEC_Eco_Level4.htm"
lyr_name   <- "NA_CEC_Eco_Level4.lyr"

# URLs for shapefile (ZIP), metadata (HTML), and layer file (LYR)
url_zip <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/us_eco_l4.zip"
url_meta <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/Eco_Level_IV_US.html"
url_lyr  <- "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/Eco_Level_IV_US.lyr"
# Local file paths
target_dir <- glue("{here()}/{file_path}/{dir_name}")
zip_path   <- glue("{target_dir}/{zip_name}")
html_path  <- glue("{target_dir}/{html_name}")
lyr_path   <- glue("{target_dir}/{lyr_name}")

# ------------------------------------------------------------------------------
# 2) Create directory, download + unzip shapefile, remove ZIP, download metadata + layer

target_dir %>%
  # A) Create the directory if it doesn't exist
  {
    dir.create(., showWarnings = FALSE, recursive = TRUE)
    .
  } %>%
  # B) Download shapefile ZIP
  {
    download.file(url_zip, destfile = zip_path, mode = "wb")
    .
  } %>%
  # C) Use system call to unzip
  {
    system(
      paste(
        "unzip",
        shQuote(zip_path),
        "-d",
        shQuote(.)
      )
    )
    .
  } %>%
  # E) Download the metadata (HTML)
  {
    download.file(url_meta, destfile = html_path, mode = "wb")
    .
  } %>%
  # F) Download the layer file (LYR)
  {
    download.file(url_lyr, destfile = lyr_path, mode = "wb")
    .
  }

# ------------------------------------------------------------------------------
# Clip the extent of Ecoregion Level 1 to Level 3 to CONUS extent

# 1) Setup
file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev04"
file_name  <- "us_eco_l4_no_st.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

# 1) Read in the Level 4 shapefile (the "CONUS" extent/boundary)
level4 <- st_read(target_file)

# 2) Read Level 1–3 ecoregions
dir_name   <- "us_eco_lev01"
file_name  <- "NA_CEC_Eco_Level1.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

level1 <- st_read(target_file)

dir_name   <- "us_eco_lev02"
file_name  <- "NA_CEC_Eco_Level2.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

level2 <- st_read(target_file)

dir_name   <- "us_eco_lev03"
file_name  <- "NA_CEC_Eco_Level3.shp"
target_file <- glue("{here()}/{file_path}/{dir_name}/{file_name}")

level3 <- st_read(target_file)

# 3) Check the CRS to ensure they match; if not, reproject
crs_level4 <- st_crs(level4)$input
# e.g. might show EPSG:XXX or a PROJ string for Albers

crs_level1 <- st_crs(level1)$input
# e.g. might show a Lambert Azimuthal 

# Transform levels 1–3 into Level 4’s Albers, then clip.
level1_albers <- st_transform(level1, st_crs(level4))
level2_albers <- st_transform(level2, st_crs(level4))
level3_albers <- st_transform(level3, st_crs(level4))

# 4) Merge Level 4 then clip each ecoregion set by Level 4 extent
level4_merged <- st_union(level4)

level1_conus <- st_intersection(level1_albers, level4_merged)
level2_conus <- st_intersection(level2_albers, level4_merged)
level3_conus <- st_intersection(level3_albers, level4_merged)

# 5) check results
# Level 1
# (1) Fix invalid geometries if any
level1_conus <- st_make_valid(level1_conus)

# (2) Extract just the polygonal part from any geometry collections
level1_conus <- st_collection_extract(level1_conus, "POLYGON")

# (3) Cast to MULTIPOLYGON to ensure a uniform type
level1_conus <- st_cast(level1_conus, "MULTIPOLYGON")

# (4) Drop Area
level1_conus <- level1_conus %>% select(-Shape_Area)

# Level 2
# (1) Fix invalid geometries if any
level2_conus <- st_make_valid(level2_conus)

# (2) Extract just the polygonal part from any geometry collections
level2_conus <- st_collection_extract(level2_conus, "POLYGON")

# (3) Cast to MULTIPOLYGON to ensure a uniform type
level2_conus <- st_cast(level2_conus, "MULTIPOLYGON")

# (4) Drop Area
level2_conus <- level2_conus %>% select(-Shape_Area)

# Level 3
# (1) Fix invalid geometries if any
level3_conus <- st_make_valid(level3_conus)

# (2) Extract just the polygonal part from any geometry collections
level3_conus <- st_collection_extract(level3_conus, "POLYGON")

# (3) Cast to MULTIPOLYGON to ensure a uniform type
level3_conus <- st_cast(level3_conus, "MULTIPOLYGON")

# (4) Drop Area
level3_conus <- level3_conus %>% select(-Shape_Area)

# 5) Save the clipped results
# Level 1
file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev01"
file_name  <- "us_eco_l1.shp"

st_write(level1_conus,
         glue("{here()}/{file_path}/{dir_name}/{file_name}"))

# Level 2
file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev02"
file_name  <- "us_eco_l2.shp"

st_write(level2_conus,
         glue("{here()}/{file_path}/{dir_name}/{file_name}"))

# Level 3
file_path  <- "data/spatial"     # top-level folder for spatial data
dir_name   <- "us_eco_lev03"
file_name  <- "us_eco_l3.shp"

st_write(level3_conus,
         glue("{here()}/{file_path}/{dir_name}/{file_name}"))

