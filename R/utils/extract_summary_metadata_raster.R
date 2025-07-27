# ==============================================================================
# Script Name:    extract_summary_metadata_raster.R

# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-07-19
# Last Updated:   2025-07-25
# Change Log:
# - 2025-07-19: Initial version to summarize CRS, resolution, and dimensions
# - 2025-07-25     Update header information;
#                  move notes to `script-notes_and_developer-log`
#
# Purpose: Extract summary metadata from raster.
#
# Workflow Summary:
# 1. Load raster
# 2. Extract properties to tibble
# 3. Write summary as CSV for documentation
#
# Input/Data URLs:
# - xml data in a user-defined folder.
# Outputs:         data/meta/<name>_attributes.csv
#                 data/meta/<name>_spatial_metadata.csv
#
# Dependencies:
# - dplyr, readr   General data wrangling, import and export.
# - here           Consistent relative paths.
# - terra          Vector and raster data functions.
#
# Helper Functions:
#
# Related Milestone Reports:
# ==============================================================================
# --- load libraries ---
library(here)
library(dplyr)
library(readr)
library(terra)
library(tibble)

input_path  <- here("data", "processed", "koppen-climate")
output_path <- here("docs", "metadata", "raster-data-summaries")
if (!dir.exists(output_path)) dir.create(output_path, recursive = TRUE)

input_file   <- "koppen-geiger.tif"
output_summ_meta <- "koppen-geiger_summary_metadata_v01.csv"
output_band_meta <- "koppen-geiger_band_metadata_v01.csv"

# --- Combine into full file path ---
raster_path <- file.path(input_path, input_file)

if (!file.exists(raster_path)) {
  stop("Raster file not found: ", raster_path)
}

# --- Load the raster
in_raster <- rast(raster_path)

# --- Inspect number of layers (bands) ---
num_bands <- nlyr(in_raster)

band_info <- tibble(
  band = names(in_raster),
  data_type = sapply(1:nlyr(in_raster), function(i) datatype(in_raster[[i]]))
)

# --- View layer names ---
var_names <- names(in_raster)

# --- Create tibble with atomic columns ---
raster_info <- tibble(
  file = input_file,
  crs = as.character(crs(in_raster, describe = TRUE)),       # <- FIXED
  extent = as.character(ext(in_raster)),
  resolution = paste(res(in_raster), collapse = " x "),       # <- FIXED
  ncols = ncol(in_raster),
  nrows = nrow(in_raster),
  nbands = nlyr(in_raster),
  names = list(names(in_raster))  # Store as list-column if needed
)

# --- Add timestamp ---
raster_info <- raster_info %>%
  mutate(timestamp = Sys.time())

# --- Export results ---
write_csv(band_info, file.path(output_path, output_band_meta))
write_csv(raster_info, file.path(output_path, output_summ_meta))
