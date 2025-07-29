# ==============================================================================
## Script Name:    03a_clean_stack_covariate_rasters.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-07-29
# Last Updated:    NA
# Changelog:
# - 2025-07-29:    Initial script to clean, align, and stack raster covariates
#
# Purpose:         Clean and stack raster covariates for modeling
#
# Workflow Summary:
# - Load raster files matching covariate short names
# - Reproject to common CRS (NAD83)
# - Align resolution and extent
# - Stack into a single SpatRaster object
# - Export for downstream use
#
# Dependencies:
# - dplyr, fs, here,readr, terra
#
# Related Milestone Reports:
# - milestone_03_prepare_covariates.pdf
# ==============================================================================
# --- load libraries ---
library(dplyr)
library(fs)
library(here)
library(janitor)
library(readr)
library(terra)

# ------------------------------------------------------------------------------
# 1. Load and clean metadata
# ------------------------------------------------------------------------------
meta_path   <- here(
  "docs", "metadata", "descriptions", "covariate_metadata_v084.csv")

meta <- read_csv(meta_path) %>%
  clean_names() %>%
  arrange(scale_ordinal, domain_ordinal, variable_name)

meta <- meta %>%
  mutate(dataset = case_when(
    dataset == "NLCD 2016  Land Cover" ~ "NLCD 2016 Land Cover",
    dataset == "NHD" ~ "NHDPlusHD",
    TRUE ~ dataset
  ))

datasets <- meta %>%
  select(dataset) %>%
  unique() %>%
  arrange()


~dataset, ~folder, ~file

"USGS station data", "peakflow_gages"

"Koppen Geiger"

"Plant Hardiness Zone"

"NLCD 2016 Land Cover"

"NED"

"PRISM annual pct"

"PRISM monthly pct"

"PRISM annual temp"

"MODIS 2016 NVDI"

"STATSGO2"

"NHDPlusV2.1"

"PRISM daily pct"

"PRISM daily temp"

"NHDPlusHD"


# ------------------------------------------------------------------------------
# 1. Define paths and parameters
# ------------------------------------------------------------------------------

# input_dir   <- here("data", "processed")
# output_path <- here("data", "derived", "covariate_stack.tif")
# 
# target_crs  <- "EPSG:4269"  # NAD83






# ------------------------------------------------------------------------------
# 3. Add file name, existence, and raster metadata
# ------------------------------------------------------------------------------
# --- Assumes raster filenames match variable_name with .tif extension ---
raster_check <- meta %>%
  mutate(
    file_name = paste0(variable_name, ".tif"),
    file_path = file.path(input_dir, file_name),
    exists = file_exists(file_path),
    crs = NA_character_,
    resolution = NA_character_
  )

# Loop over files that exist and extract metadata
for (i in seq_len(nrow(raster_check))) {
  if (raster_check$exists[i]) {
    r <- try(rast(raster_check$file_path[i]), silent = TRUE)
    if (!inherits(r, "try-error")) {
      raster_check$crs[i] <- as.character(crs(r))
      res_vals <- res(r)
      raster_check$resolution[i] <- paste(res_vals[1], "x", res_vals[2], "m")
    }
  }
}

# Select key summary fields
raster_inventory <- raster_check %>%
  select(scale_ordinal, scale, dataset, variable_name,
         file_name, exists, crs, resolution)

# Optionally: write to CSV or print for inspection
write_csv(raster_inventory, here("docs", "metadata", "raster_inventory_v01.csv"))






# rasters_to_stack <- meta %>%
#   filter(Scale %in% c("Grid", "Subregional"),
#          Domain %in% c("Climate", "Topography", "Land Cover")) %>%
#   pull(`Short Name`)
# 
# # ------------------------------------------------------------------------------
# # 3. Load and clean rasters
# # ------------------------------------------------------------------------------
# 
# # Function to read, reproject, and name raster
# load_and_clean <- function(short_name) {
#   file_path <- file.path(input_dir, paste0(short_name, ".tif"))
#   if (!file.exists(file_path)) {
#     warning("Missing file: ", short_name)
#     return(NULL)
#   }
#   r <- rast(file_path)
#   r <- project(r, target_crs)
#   names(r) <- short_name
#   return(r)
# }
# 
# # Load all rasters and filter out NULLs
# raster_list <- purrr::map(rasters_to_stack, load_and_clean) %>%
#   purrr::compact()
# 
# # ------------------------------------------------------------------------------
# # 4. Align resolution and extent (assuming all rasters are already pre-clipped)
# # ------------------------------------------------------------------------------
# 
# cov_stack <- do.call(c, raster_list)
# 
# # ------------------------------------------------------------------------------
# # 5. Export stacked raster
# # ------------------------------------------------------------------------------
# 
# writeRaster(cov_stack, output_path, overwrite = TRUE)
# message("✅ Covariate stack written to: ", output_path)
