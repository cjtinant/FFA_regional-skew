# ==============================================================================
# Script Name:      03h_covar_make_NLCD_meta.R
# Purpose:          Rebuild NLCD raster and develop metadata
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-09-22
# Last Updated:     2025-10-02
#
# Changelog:
# - 2025-09-22     Split from 03i_covar_macro_landcover_summary to try to fix an
#                  issue with summary creating non_legend NLCD class codes.
# - 2025-10-01     Found issue was in the way the raw raster was reprojected
#                  in R/01_download/01m_download_nlcd_2016.R. The refactored
#                  code in this script only makes a LUT.
# - 2025-10-02     Merged NLCD Shrub/Scrub (52) with Grassland/Herbaceous (71)
#                  and Pasture/Hay (81)) into a single Rangeland bucket.
#                  Hydrologically they behave more alike than with Forest or
#                  Crops, and it avoids a potential sparse class (Shrubland).
#
# Generalized Workflow:
# 1. Make NLCD lookup table.
# 2. Save LUT
#
# Inputs (relative to project root):
#
# Outputs:
#
# - Documentation files to check/update
#   - notes/script-notes_and_developer-log.pdf
#   - data/log_README.pdf
#   - R/log_README.pdf
#   - R/README.pdf
#   - CHANGELOG.md
#   - milestone_03_prepare_covariates.pdf
#
# Notes:
#
# ==============================================================================
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
})

# ------------------------------------------------------------------------------
# 1) Make NLCD look-up table
# ------------------------------------------------------------------------------
nlcd_lut <- tribble(
  ~value, ~class, ~classification, ~description,
  11, "Water", "Open Water", "open water with lt 25pct vege or soil cover",
  12, "Water", "Perennial Ice/Snow", "perennial ice or snow cover gt 25pct",
  21, "Developed", "Open Space", "mostly lawn grass, impervious lt 20pct",
  22, "Developed", "Low Intensity", "construct and vege mix, imperv 20-49pct",
  23, "Developed", "Med Intensity", "construct and vege mix, imperv 50-79pct",
  24, "Developed", "High Intensity", "highly developed, imperv 80-100pct",
  31, "Barren", "Barren Land", "bedrock, desert pavement, sand dunes, vege lt 15pct",
  41, "Forest", "Deciduous Forest", "trees gt 20pct, decid gt 75pct, ht gt 5m",
  42, "Forest", "Evergreen Forest", "trees gt 20pct, evergreen gt 75pct, ht gt 5m",
  43, "Forest", "Mixed Forest", "trees gt 20pct, decid and evergrn lt 75pct, ht gt 5m",
  52, "Rangeland", "Shrub/Scrub", "shrubs lt 5m, canopy gt 20pct, true shrubs, young trees",
  71, "Rangeland", "Grassland/Herbaceous", "grass or herbs gt 80pct, can be grazed",
  81, "Rangeland", "Pasture/Hay", "planted grass and/or legumes for grazing or hay",
  82, "Cultivated", "Cultivated Crops", "tilled, annual corn, soybeans, veges, orchards",
  90, "Wetlands", "Woody Wetlands", "periodically saturated forest or shrubland",
  95, "Wetlands", "Emergent Herbaceous Wetlands", "periodically saturated perrannual herbs"
)

# ------------------------------------------------------------------------------
# 2) Write results
# ------------------------------------------------------------------------------
# --- Write look-up table ---
meta_out_path  <- here("docs", "metadata", "look_up_tables", "nlcd_metadata_lut.csv")
write_csv(nlcd_lut, meta_out_path)
