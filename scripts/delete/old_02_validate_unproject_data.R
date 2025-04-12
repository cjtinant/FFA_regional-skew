# =======================
# Purpose: Validates and projects ecoregion data to  WGS 84 Geographic
# =======================

#------------------------------------------------------------------------------
# library
library(tidyverse)        # Load the 'Tidyverse' packages: ggplot2, dplyr, 
#   tidyr, readr, purrr, tibble, stringr, and forcats
library(here)             # A simpler way to find files
library(glue)             # Format and interpolate a string
library(sf)               # Simple features for R
library(janitor)          # Simple tools for cleaning dirty data

# scripts:
source("f_scripts/process_geometries.R")

# set file path for the spatial data folder
file_path <- "data_spatial"
folder_name <- "ecoregions_orig"

# set coordinate system for transform
crs_new <- 4326     # WGS 84 Geographic; Unit: degree

#------------------------------------------------------------------------------
# load ecoregions -- local path and reproject ecoregions to WGS Geographic 

# Level 1 Ecoregion:
file_name <- "NA_CEC_Eco_Level1_GreatPlains.shp"
eco_lev1 <- st_read(
  glue({file_path},{folder_name},{file_name}, .sep = "/"
  )) %>%
  clean_names() %>%
  process_geometries()

eco_lev1 <- eco_lev1 %>%
  st_transform(crs = {crs_new}) %>%
  process_geometries()

# Level 2 Ecoregion:
file_name <- "NA_CEC_Eco_Level2_GreatPlains.shp"

eco_lev2 <- st_read(
  glue({file_path},{folder_name},{file_name}, .sep = "/"
  )) %>%
  clean_names() %>%
  process_geometries()

eco_lev2 <- eco_lev2 %>%
  st_transform(crs = {crs_new}) %>%
  process_geometries()

# Level 3 Ecoregion:
file_name  <- "us_eco_l3_GreatPlains.shp"

eco_lev3 <- st_read(
  glue({file_path},{folder_name},{file_name}, .sep = "/"
  )) %>%
  clean_names() %>%
  process_geometries()

eco_lev3 <- eco_lev3 %>%
  st_transform(crs = {crs_new}) %>%
  process_geometries()

# Level 4 Ecoregion:
file_name  <- "us_eco_l4_no_st_GreatPlains.shp"

eco_lev4 <- st_read(
  glue({file_path},{folder_name},{file_name}, .sep = "/"
  )) %>%
  clean_names() %>%
  process_geometries()

# reproject ecoregions to WGS Geographic 
eco_lev4 <- eco_lev4 %>%
  st_transform(crs = {crs_new}) %>%
  process_geometries()

#------------------------------------------------------------------------------
# Clip Level 1 & 2 Ecoregions to CONUS extent
#   Note: The Level 1 & 2 Ecoregions were downloaded at the North America extent

# Merge all polygons into one for a clip
eco_lev3_merged <- st_sf(geometry = st_union(eco_lev3))

# clip ecoregion level 1 and level 2 based on ecoregion level 3 extent
eco_lev1_us <- st_intersection(eco_lev1, eco_lev3_merged) %>%
  process_geometries()

eco_lev2_us <- st_intersection(eco_lev2, eco_lev3_merged) %>%
  process_geometries()

ggplot() +
  geom_sf(data = eco_lev1_us)

#------------------------------------------------------------------------------
# Write ecoregion data to a newer spatial format
#   Note: Shapefiles have limits on the number of digits -- which causes
#     spatial uncertainty for unprojected -- Decimal Lat Lon data 
#   Writing to a geopackage -- .gpkg avoids distortion

folder_name_out <- "ecoregions_unprojected"
file_name_out <- "us_eco_lev1_GreatPlains_geographic.gpkg"

st_write(eco_lev1_us, glue({file_path},{folder_name_out},{file_name_out}, .sep = "/"
))

file_name_out <- "us_eco_lev2_GreatPlains_geographic.gpkg"
st_write(eco_lev2, glue({file_path},{folder_name_out},{file_name_out}, .sep = "/"
))

file_name_out <- "us_eco_lev3_GreatPlains_geographic.gpkg"
st_write(eco_lev3,
         glue({file_path},{folder_name_out},{file_name_out}, .sep = "/"
         ))

file_name_out <- "us_eco_lev4_GreatPlains_geographic.gpkg"

st_write(eco_lev3,
         glue({file_path},{folder_name_out},{file_name_out}, .sep = "/"
         ))
