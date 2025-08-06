# ==============================================================================
# Script Name:     03a_update_covariate_metadata.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-07-29
# Last Updated:    2025-08-01
# Changelog:
# - 2025-07-29     Begin initial script
# - 2025-08-01     Complete initial script
#
# Purpose:         This script cleans covariate metadata, and documents links to
#                  covariate datasets, and zonal summary datasets.
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
# 5. Join folder and zonal summary dataset names to covariate metadata.
# 6. Export results and archive prior version of covariate metadata.
#
# Dependencies:
# - dplyr, fs, here,readr, terra
#
# Related Milestone Reports, Data Dictionaries, and Notes:
# - milestone_03_prepare_covariates.pdf
# - data_dictionary_covariates.pdf
# - script-notes_and_developer-log.pdf
#
# Next Steps:
# - Develop macrozone layer for zonal summaries -- 3b_make_macrozone_layer
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

input_file_name <- "covariate_metadata_v084.csv"
input_folder <- here("docs", "metadata", "descriptions")
input_path <- here("docs", "metadata", "descriptions", input_file_name)


covar_raw <- read_csv(input_path) %>%
  clean_names()

# ------------------------------------------------------------------------------
# 2. Update variable name and covariate discriptions
# ------------------------------------------------------------------------------
# --- Update domain variable name, effective resolution, and description ---
covar_very_rare <- covar_raw %>%
  # update domain variable name and categorical type
  mutate(domain_cat = case_when(
    domain_ordinal == 1 ~ "A",
    domain_ordinal == 2 ~ "B",
    domain_ordinal == 3 ~ "C",
    domain_ordinal == 4 ~ "D",
    TRUE ~ "ERROR"
    )) %>%
  relocate(domain_cat, .after = "domain") %>%
  select(-domain_ordinal) %>%
  # update concept_group variable name and categorical type
  mutate(concept_group_cat = case_when(
    concept_group_ordinal == 1 ~ "A",
    concept_group_ordinal == 2 ~ "B",
    concept_group_ordinal == 3 ~ "C",
    concept_group_ordinal == 4 ~ "D",
    concept_group_ordinal == 5 ~ "E",
    concept_group_ordinal == 6 ~ "F",
    concept_group_ordinal == 7 ~ "G",
    TRUE ~ "ERROR"
  )) %>%
  relocate(concept_group_cat, .after = "concept_group") %>%
  select(-concept_group_ordinal) %>%
  # update analytical resolution to clarify NHDPlus type
  mutate(effective_analytical_resolution = case_when(
    effective_analytical_resolution == "~1 to 5 sq-km (catchment scale, NHD+)" ~
      "~1 to 5 sq-km (catchment scale, NHDPlusHD)",
    TRUE ~ effective_analytical_resolution
    )) %>%
  # update descriptions to clarify NHDPlus types
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
    description == "Zonal median of the sine of aspect, derived from 10 m NED data, aggregated to NHD+ catchments." ~
      "Zonal median of the sine of aspect, derived from 10 m NED elevation data, aggregated to NHDPlusHD catchments.",
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
# --- make look-up table of data locations in ~/data/processed/ ---
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

# --- locate multiples resulting in a many-to-many relationship --- 
join_rare_mults <- join_rare %>%
  group_by(variable_name) %>%
  summarise(count = n()) %>%
  arrange(desc(count)) %>%
  filter(count > 1)

# --- make lut to update variable names to develop a one-to-one relationship ---
dataset_normalization_lut <- tribble(
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
covar_med_rare <- left_join(covar_rare, dataset_normalization_lut,
                  by = join_by(variable_name)
                  ) %>%
  mutate(dataset = ifelse(
    is.na(dataset_new),
    dataset,
    dataset_new)) %>%
  select(-dataset_new)

# --- update doc_locs with  ---
data_locs_med_rare <- tribble(
  ~dataset, ~subfolder, ~file_name,
  "USGS station data", "peakflow_gages", "gage_summary_skew.gpkg",
  "Koppen Geiger", "koppen_climate", "koppen_geiger.tif",
  "Plant Hardiness Zone", "phzm", "phzm.tif",
  "NLCD 2016 Land Cover", "nlcd", "nlcd_2016_gp.tif",
  "NED elev", "ned", "elev_30m_gp.tif",         # this is updated
  "NED slope", "ned", "slope_30m_gp.tif",       # this is updated
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

# --- perform join after updating covar dataset ---
join_med_rare <- left_join(covar_med_rare, data_locs_med_rare,
                       by = join_by(dataset))

# ------------------------------------------------------------------------------
# 5. Join folder and zonal summary dataset names
# ------------------------------------------------------------------------------
# --- make look-up table of zonal summary names ---
zonal_lut <- tribble(
  ~scale, ~subfolder, ~file_name, ~layer_name,
  "Station", "NA", "NA", "NA",
  "Macroregional", "us_ecoregions", "us_eco_levels.gpkg", "NA",
  "Regional", "us_ecoregions", "us_eco_levels.gpkg", "us_eco_l2",
  "Subregional", "us_ecoregions", "us_eco_levels.gpkg", "us_eco_l3",
  "Local", "us_ecoregions", "us_eco_levels.gpkg", "us_eco_l4"
)

# --- perform join after updating covar dataset ---
join_medium <- left_join(join_med_rare, zonal_lut,
                         by = join_by(scale))

# ------------------------------------------------------------------------------
# 6. Export updated metadata
# ------------------------------------------------------------------------------
# --- Make an export path ---
output_path   <- here(
  "docs", "metadata", "descriptions", "covariate_metadata_v085.csv")

# --- write results ---
write_csv(join_medium, output_path)

# ------------------------------------------------------------------------------
# 7. Archive prior covariate metadata
# ------------------------------------------------------------------------------
# --- define path to archive ---
archive_folder <- here(input_path, "archive")
file_to_move <- here(input_path, input_file_name)

# --- create archive folder (recursively = TRUE allows nested folders) ---
dir_create(archive_folder, recurse = TRUE)

# --- move file to archive ---
file_move(file_to_move, archive_folder)
