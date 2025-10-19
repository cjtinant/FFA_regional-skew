# ==============================================================================
# Script Name:     03e_macrozone_fix_join_key.R
# Purpose:         Fix a join key issue
# Author:          Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:    2025-09-12
# Last Updated:    2025-09-12
#
# Changelog:
# - 2025-09-12     Split script from 03e_covar_macro_zonal_summary.R
#
# ==============================================================================
# --- Load libraries ---
suppressPackageStartupMessages({
  library(here)
  library(sf)
  library(tidyverse)
})

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

# --- correct join key ---
zones <- st_read(zone_path, layer = layer_name, quiet = TRUE) %>%
  mutate(macro_id = case_when(
    region_name == "Prairie Tallgrass Prairie" ~ 5,
    region_name == "Tallgrass Prairie" ~ 5,
    region_name == "Northern Mixed-Grass Prairie" ~ 4,
    region_name == "Central Mixed-Grass Prairie" ~ 3,
    region_name == "Southern Mixed-Grass Prairie" ~ 2,
    region_name == "Shortgrass-Steppe" ~ 1,
    TRUE ~ -9999
  )) %>%
  mutate(region_name = case_when(
    macro_id == 5 ~ "Tallgrass Prairie",
    TRUE ~ region_name
    )) %>%
  arrange(macro_id)

# --- save corrected macrozones ---
out_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")

st_write(zones,
         dsn = out_path,
         layer = "macrozones_gp",
         delete_layer = TRUE)
