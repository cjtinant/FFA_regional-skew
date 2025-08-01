# ==============================================================================
# Script Name:     03a_update_covariate_metadata.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-07-29
# Last Updated:    NA
# Changelog:
# - 2025-07-29     Initial script
#
# Purpose:         This script cleans covariate metadata, prepares links to
#                  datasets, and identifies next steps towards calculating
#                  zonal statistics on datasets --> developing the macrozone
#                  level of aggregation.
#
# Workflow Summary:
# 1. Load covariate data. Variable names used during the cleaning steps are
#    analogous to cooking a steak, i.e. the tibble being cleaned begins at raw
#    and proceeds to very rare, rare, medium rare, etc.
# 2. Update variable name and covariate metadata. Variable name is updated from
#    domain_ordinal to domain_cat to reflect a categorical data type. Effective
#    analytical resolution and description fields are updated from NHD+ to
#    to distinguish between NHDPlus v2.1 and NHDPlusHD and between catchments
#    and flowlines data.
# 3. Check and clean syntax errors.
# 4. Join folder and dataset names to covariate metadata. This step requires
#    updating dataset names from NED to NED slope and NED elevation to create
#    a one-to-one relationship between covariate dataset names and file names
# 5. Export results

# if the data are clean this should result in a one-to-one join with n = 63 obs
# However, the initial join results in a many-to-many relationship

# - Archive or remove prior version of covariate metadata

# - Load raster files matching covariate short names
# - Reproject to common CRS (NAD83)
# - Align resolution and extent
# - Stack into a single SpatRaster object
# - Export for downstream use
#
# Dependencies:
# - dplyr, fs, here,readr, terra
#
# Related Milestone Reports and Data Dictionaries:
# - milestone_03_prepare_covariates.pdf
# - data_dictionary_covariates.pdf
# THAT NOTE FILE CHECK FOR THE NAME
#
# Notes on project data structure:
# - Project datasets consist of feature data, vector data, and raster data
#   stored in `~/data/processed/`
# - The response variable is station skew, which can be represented as vector
#   point data.
# - The 63 initial explanatory variables, i.e. covariates or 'covar' in the
#   script below, are structured by hierarchical scale (ordinal data) and domain
#   (categorical data)
# - The covariate data are aggregated at each scale:
#     Hierarchical Scale   Aggregated by:
#     0 - Station          NA
#     1 - Macroregional    Macrozone
#     2 - Regional         Level II Ecoregion
#     3 - Subregional      Level III Ecoregion
#     4 - Local            NHDPlusHD catchment
#
#     Domain Category
#     A - Climate
#     B - Land Cover
#     C - Topography
#     D - Watershed Metrics
# ==============================================================================
# --- load libraries ---
library(dplyr)
library(fs)
library(here)
library(janitor)
library(readr)
library(terra)

# ------------------------------------------------------------------------------
# 1. Load covariate metadata
# ------------------------------------------------------------------------------
# --- Load most recent version of covariate metadata ---
covar_path   <- here(
  "docs", "metadata", "descriptions", "covariate_metadata_v084.csv")

covar_raw <- read_csv(covar_path) %>%
  clean_names()

# ------------------------------------------------------------------------------
# 2. Update variable name and covariate metadata 
# ------------------------------------------------------------------------------
# Update data to reflect data type for domain and scale description

# --- update descriptions 
covar_very_rare <- covar_raw %>%
  mutate(domain_cat = case_when(
    domain_ordinal == 1 ~ "A",
    domain_ordinal == 2 ~ "B",
    domain_ordinal == 3 ~ "C",
    domain_ordinal == 4 ~ "D",
    TRUE ~ "ERROR"
    )) %>%
  relocate(domain_cat, .after = "domain") %>%
  select(-domain_ordinal) %>%
  mutate(effective_analytical_resolution = case_when(
    effective_analytical_resolution == "~1 to 5 sq-km (catchment scale, NHD+)" ~
      "~1 to 5 sq-km (catchment scale, NHDPlusHD)",
    TRUE ~ effective_analytical_resolution
    )) %>%
  mutate(description = case_when(
    # Land Cover %
    description ==  "Zonal median percent cover by dominant NLCD class aggegated to NHD+ catchments." ~
      "Zonal median percent cover by dominant NLCD class aggegated to NHDPlusHD catchments.",
    # Land Use Diversity
    description ==  "Normalized Shannon Weiner Diversity Index of NLCD land cover classes, aggregated to NHD+ catchments." ~
      "Normalized Shannon Weiner Diversity Index of NLCD land cover classes, aggregated to NHDPlusHD catchments.",
    # Slope Skewness
    description == "Zonal skewness NED slope values, aggregated to Level II ecoregions." ~
      "Zonal skewness of NED slope values, aggregated to Level II ecoregions.",
    # Elevation range
    description == "Zonal median elevation range (max minus min elevation) from 10 m NED data, aggregated to NHD+ catchments." ~
      "Zonal median elevation range (max minus min elevation) from 10 m NED elevation data, aggregated to NHDPlusHD catchments.",
    # cosine
    description == "Zonal median of the cosine of aspect, derived from 10 m NED data, aggregated to NHD+ catchments." ~
      "Zonal median of the cosine of aspect, derived from 10 m NED elevation data, aggregated to NHDPlusHD catchments.",
    # sine
    description == "Zonal median of the cosine of aspect, derived from 10 m NED data, aggregated to NHD+ catchments." ~
      "Zonal median of the cosine of aspect, derived from 10 m NED elevation data, aggregated to NHDPlusHD catchments.",
    # Curvature IQR
    description == "IQR of combined curvature types, derived from 10 m NED data, aggregated to NHD+ catchments" ~
      "IQR of combined curvature types, derived from 10 m NED elevation data, aggregated to NHDPlusHD catchments",
    # Planform Curvature
    description == "Zonal median of planform (horizontal) curvature, derived from 10 m NED data, aggregated to NHD+ catchments." ~
      "Zonal median of planform (horizontal) curvature, derived from 10 m NED data, aggregated to NHDPlusHD catchments.",
    # Profile Curvature
    description == "Zonal median of profile (vertical) curvature, derived from 10 m NED data, aggregated to NHD+ catchments." ~
      "Zonal median of profile (vertical) curvature, derived from 10 m NED elevation data, aggregated to NHDPlusHD catchments.",
    # Watershed Elongation
    description == "Watershed elongation ratio, calculated from catchment geometry, aggregated to NHD+ catchments." ~
      "Watershed elongation ratio, calculated from catchment geometry, aggregated to NHDPlusHD catchments.",
    # Watershed Circularity
    description == "Watershed circularity ratio, calculated from catchment geometry, aggregated to NHD+ catchments" ~
      "Watershed circularity ratio, calculated from catchment geometry, aggregated to NHDPlusHD catchments",
    # Surface Roughness
    description == "Zonal median of surface roughness, derived from 10 m NED, aggegated to Level III ecoregions." ~
      "Zonal median of surface roughness, derived from 10 m NED elevation, aggegated to Level III ecoregions.",
    # Relief ratio
    description == "Relief ratio (elevation range divided by stream length) from 10 m NED data, aggregated to NHD+ catchments." ~
      "Relief ratio (elevation range divided by stream length) from 10 m NED elevation data, aggregated to NHDPlusHD catchments.",
    # Stream Density
    description == "Zonal median of average flow path length, derived from NHD+ data." ~
      "Zonal median of average flow path length, derived from NHDPlusHD flowlines, aggregated to NHDPlusHD catchments",
    # Mean Flow Length
    description == "Zonal median of stream length per catchment area, derived from NHD+ data." ~
      "Zonal mean of stream length per catchment area, derived from NHDPlusHD flowlines, aggregated to NHDPlusHD catchments.",
    # Stream Slope
    description == "Zonal median of stream slope (elevation drop per unit flow length), derived from NHD+ data." ~
      "Zonal median of stream slope (elevation drop per unit flow length), derived from NED and NHDPlus data, aggregated to NHDPlusHD catchments.",
    # Median Stream Order
    description == "Zonal median of Strahler stream order, aggregated to Level II ecoregions." ~
      "Zonal median of Strahler stream order derived from NHDPlus v2.1 flowlines, aggregated to Level II ecoregions.",
    # Max Stream Order
    description == "Zonal maximum stream order in the network, aggregated to Level II ecoregions." ~
      "Zonal maximum stream order in the network derived from NHDPlus v2.1 flowlines, aggregated to Level II ecoregions.",
    # TWI Class
    description == "Zonal assignment of ordinal NED Topographic Wetness Index (TWI) classes, derived from 10 m NED, aggegated to Level III ecoregions." ~
      "Zonal assignment of ordinal NED Topographic Wetness Index (TWI) classes, derived from 10 m NED elevations, aggegated to Level III ecoregions.",
    # TWI Modal
    description == "Zonal mode of NED Topographic Wetness Index (TWI) values aggegated to Level III ecoregions." ~
      "Zonal mode of 10 m NED Topographic Wetness Index (TWI) values, derived from 10 m NED elevations, aggegated to Level III ecoregions.",
        TRUE ~ description
    ))

# ------------------------------------------------------------------------------
# 3. Check and clean syntax errors
# ------------------------------------------------------------------------------
# --- summarise covariate structure ---
covar_struct <- covar_very_rare %>%
  group_by(scale_ordinal, domain_cat, scale, domain) %>%
  summarise(count = n()) %>%
  ungroup()

# --- check for syntax errors ---
covar_very_rare_summ <- covar_very_rare %>%
  group_by(scale_ordinal, dataset) %>%
  summarise(count = n())

# --- clean syntax errors ---
covar_rare <- covar_very_rare %>%
  mutate(dataset = case_when(
    dataset == "NLCD 2016  Land Cover" ~ "NLCD 2016 Land Cover",
    dataset == "NHD" ~ "NHDPlusHD",
    TRUE ~ dataset
  ))

# --- check initial results ---
covar_rare_summ <- covar_rare %>%
  group_by(scale_ordinal, dataset) %>%
  summarise(count = n())

# ------------------------------------------------------------------------------
# 4. Join folder and dataset names to covariate metadata
# ------------------------------------------------------------------------------
# --- create a look-up table of data locations in ~/data/processed/ ---
data_locs_rare <- tribble(
~dataset, ~subfolder, ~file_name,
"USGS station data", "peakflow_gages", "gage_summary_skew.gpkg",
"Koppen Geiger", "koppen_climate", "koppen_geiger.tif",
"Plant Hardiness Zone", "phzm", "phzm.tif",
"NLCD 2016 Land Cover", "nlcd", "nlcd_2016_gp.tif",
"NED", "ned", "elev_30m_gp.tif",
"NED", "ned", "slope_30m_gp.tif",
"PRISM annual pct", "prism", "ppt_ann_mm_stack.tif",
"PRISM monthly pct", "prism", "ppt_monthly_mm_stack.tif",
"PRISM annual temp", "prism", "temp_ann_C_stack.tif",
"MODIS 2016 NVDI", "modis/mod13a1_ndvi_timeseries", "nvdi_2016_stack",
"STATSGO2", "statsgo2", "statsgo2_mupolygon.gpkg",
"NHDPlusV2.1", "nhdplus_v21", "nhdv21_catchments.gpkg",
"NHDPlusV2.1", "nhdplus_v21", "nhdv21_flowlines.gpkg",
"PRISM daily pct", "prism", "FILES NEED PROCESSING",
"PRISM daily temp", "prism", "FILES NEED PROCESSING",
"NHDPlusHD", "nhdphr", "nhdphr_catchments_combined.gpkg",
"NHDPlusHD", "nhdphr", "nhdphr_flowlines_combined.gpkg"
)

# --- perform initial join ---
join_rare <- left_join(covar_rare, data_locs_rare,
                       by = join_by(dataset))

# --- locate multiples --- 
join_rare_mults <- join_rare %>%
  group_by(variable_name) %>%
  summarise(count = n()) %>%
  arrange(desc(count)) %>%
  filter(count > 1)

# --- fix issue with NED slope and elevation ---
data_locs_med_rare <- tribble(
  ~dataset, ~subfolder, ~file_name,
  "USGS station data", "peakflow_gages", "gage_summary_skew.gpkg",
  "Koppen Geiger", "koppen_climate", "koppen_geiger.tif",
  "Plant Hardiness Zone", "phzm", "phzm.tif",
  "NLCD 2016 Land Cover", "nlcd", "nlcd_2016_gp.tif",
  "NED elev", "ned", "elev_30m_gp.tif",
  "NED slope", "ned", "slope_30m_gp.tif",
  "PRISM annual pct", "prism", "ppt_ann_mm_stack.tif",
  "PRISM monthly pct", "prism", "ppt_monthly_mm_stack.tif",
  "PRISM annual temp", "prism", "temp_ann_C_stack.tif",
  "MODIS 2016 NVDI", "modis/mod13a1_ndvi_timeseries", "nvdi_2016_stack",
  "STATSGO2", "statsgo2", "statsgo2_mupolygon.gpkg",
  "NHDPlusV2.1", "nhdplus_v21", "nhdv21_catchments.gpkg",
  "NHDPlusV2.1", "nhdplus_v21", "nhdv21_flowlines.gpkg",
  "PRISM daily pct", "prism", "FILES NEED PROCESSING",
  "PRISM daily temp", "prism", "FILES NEED PROCESSING",
  "NHDPlusHD catchments", "nhdphr", "nhdphr_catchments_combined.gpkg",
  "NHDPlusHD flowlines", "nhdphr", "nhdphr_flowlines_combined.gpkg"
)

# --- make lut to update multiples ---
mult_lut <- tribble(
~variable_name, ~dataset_new,
"aspect_cos", "NED elev",
"aspect_sin", "NED elev",
"curvature_iqr", "NED elev",
"curvature_planiform", "NED elev",
"curvature_profile", "NED elev",
"elev_range_m", "NED elev",
"flow_accum", "NHDPlusHD flowlines",
"roughness_index", "NED elev",
"slope_dist_mean", "NED slope",
"slope_dist_skew", "NED slope",
"slope_mean", "NED slope",
"slope_median", "NED slope",
"slope_variability_iqr", "NED slope",
"slope_variability_sd", "NED slope",
"str_density", "NHDPlusHD flowlines",
"str_flow_len_ave", "NHDPlusHD flowlines",
"str_order_max", "NHDPlus V21 flowlines",
"str_order_med", "NHDPlus V21 flowlines",
"str_slope", "NED elev",
"twi_class", "NED elev",
"twi_index_mean", "NED elev",
"twi_index_modal", "NED elev",
"wtsd_circ_ratio", "NHDPlusHD catchments",
"wtsd_elong_ratio", "NHDPlusHD catchments",
"wtsd_relief_ratio", "NHDPlusHD catchments"
)

# --- update covar dataset ---
covar_med_rare <- left_join(covar_rare, mult_lut,
                  by = join_by(variable_name)
                  ) %>%
  mutate(dataset = ifelse(
    is.na(dataset_new),
    dataset,
    dataset_new)) %>%
  select(-dataset_new)

# --- perform another join ---
join_med_rare <- left_join(covar_med_rare, data_locs_med_rare,
                       by = join_by(dataset))

# ------------------------------------------------------------------------------
# 5. Export results
# ------------------------------------------------------------------------------




# # ------------------------------------------------------------------------------
# # 1. Define paths and parameters
# # ------------------------------------------------------------------------------
# 
# # input_dir   <- here("data", "processed")
# # output_path <- here("data", "derived", "covariate_stack.tif")
# # 
# # target_crs  <- "EPSG:4269"  # NAD83
# 
# 
# 
# 
# 
# 
# # ------------------------------------------------------------------------------
# # 3. Add file name, existence, and raster metadata
# # ------------------------------------------------------------------------------
# # --- Assumes raster filenames match variable_name with .tif extension ---
# raster_check <- meta %>%
#   mutate(
#     file_name = paste0(variable_name, ".tif"),
#     file_path = file.path(input_dir, file_name),
#     exists = file_exists(file_path),
#     crs = NA_character_,
#     resolution = NA_character_
#   )
# 
# # Loop over files that exist and extract metadata
# for (i in seq_len(nrow(raster_check))) {
#   if (raster_check$exists[i]) {
#     r <- try(rast(raster_check$file_path[i]), silent = TRUE)
#     if (!inherits(r, "try-error")) {
#       raster_check$crs[i] <- as.character(crs(r))
#       res_vals <- res(r)
#       raster_check$resolution[i] <- paste(res_vals[1], "x", res_vals[2], "m")
#     }
#   }
# }
# 
# # Select key summary fields
# raster_inventory <- raster_check %>%
#   select(scale_ordinal, scale, dataset, variable_name,
#          file_name, exists, crs, resolution)
# 
# # Optionally: write to CSV or print for inspection
# write_csv(raster_inventory, here("docs", "metadata", "raster_inventory_v01.csv"))
# 
# 
# 
# 
# 
# 
# # rasters_to_stack <- meta %>%
# #   filter(Scale %in% c("Grid", "Subregional"),
# #          Domain %in% c("Climate", "Topography", "Land Cover")) %>%
# #   pull(`Short Name`)
# # 
# # # ------------------------------------------------------------------------------
# # # 3. Load and clean rasters
# # # ------------------------------------------------------------------------------
# # 
# # # Function to read, reproject, and name raster
# # load_and_clean <- function(short_name) {
# #   file_path <- file.path(input_dir, paste0(short_name, ".tif"))
# #   if (!file.exists(file_path)) {
# #     warning("Missing file: ", short_name)
# #     return(NULL)
# #   }
# #   r <- rast(file_path)
# #   r <- project(r, target_crs)
# #   names(r) <- short_name
# #   return(r)
# # }
# # 
# # # Load all rasters and filter out NULLs
# # raster_list <- purrr::map(rasters_to_stack, load_and_clean) %>%
# #   purrr::compact()
# # 
# # # ------------------------------------------------------------------------------
# # # 4. Align resolution and extent (assuming all rasters are already pre-clipped)
# # # ------------------------------------------------------------------------------
# # 
# # cov_stack <- do.call(c, raster_list)
# # 
# # # ------------------------------------------------------------------------------
# # # 5. Export stacked raster
# # # ------------------------------------------------------------------------------
# # 
# # writeRaster(cov_stack, output_path, overwrite = TRUE)
# # message("✅ Covariate stack written to: ", output_path)
