# ==============================================================================
# Script Name:      03h_covar_macro_NLCD_summary.R
# Purpose:          Compute NLCD class fractions by tiling the AOI 
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-09-22
# Last Updated:     2025-10-02
#
# Changelog:
# - 2025-09-22     Split original script: 03h_covar_macro_landcover_summary to
#                  try to fix an issue with summary creating non_legend NLCD
#                  class codes.
# - 2025-10-01     Refactor code to calculate land-cover fractions by zone
#                  (categorical-safe, no raster reprojection)
# - 2025-10-01     Update metadata, move function code to 
#                  \utils\rast_summ_by_class.R
#
# Generalized Workflow:
# 1. Load inputs
# 2. Get NLCD fractions list
# 3. QA and munge results
# 4. Group results for model inputs
# 5. Output results
#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg 
#                    (layer = "macrozones_gp")
#   rasters:       data/processed/nlcd/nlcd_2016_gp_nn.tif")
#                  where `gp` stands for Great Plains and 
#                        `nn` stands for nearest neighbor (resampling)
# Outputs:
#                  data/covars/macro_nlcd_detail.csv
#                  data/covars/macro_nlcd.csv
#
# Dependencies: exactextractr, here, sf, terra, tidyverse
# Related Files:
# - Documentation files to check/update
#   - notes/script-notes_and_developer-log.pdf
#   - data/log_README.pdf
#   - R/log_README.pdf
#   - R/README.pdf
#   - CHANGELOG.md
#   - milestone_03_prepare_covariates.pdf
#
# Notes:
# ==============================================================================
# --- Load libraries ---
suppressPackageStartupMessages({
  library(exactextractr)
  library(here)
  library(sf)
  library(terra)
  library(tidyverse)
})

# --- Load custom functions ---
source(file.path(here(), "R", "utils", "spatial", "rast_summ_by_class.R"))

# ------------------------------------------------------------------------------
# 1. Load inputs
# ------------------------------------------------------------------------------
# --- rasters ---
rast_path <- here("data", "processed", "nlcd", "nlcd_2016_gp_nn.tif")

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- st_read(zone_path, layer = layer_name, quiet = TRUE)

# --- metadata ---
meta_path <- here("docs", "metadata", "look_up_tables", "nlcd_metadata_lut.csv")

nlcd_meta <- read_csv(meta_path, show_col_types = FALSE)

# ------------------------------------------------------------------------------
# 2. Get NLCD fractions list
# ------------------------------------------------------------------------------

res <- nlcd_fractions_tiled(
  r      = rast_path,
  zones  = zone_path,
  layer  = layer_name,
  id_col = "macro_id",
  nx = 10, ny = 10,            # bump if memory is tight
  simplify_tol = 0             # or e.g., 5 (meters) for very detailed borders
)

# ------------------------------------------------------------------------------
# 3. QA and Munge results
# ------------------------------------------------------------------------------
# --- check results ---
qa <- res$qa

# --- pull the dataframe ---
nlcd_long_df <- res$long              # macro_id, code, prop (long)

# --- add metadata ---
nlcd_long <- left_join(nlcd_long_df, zones,
                       by = join_by(macro_id)
)

nlcd <- left_join(nlcd_long, nlcd_meta,
                  by = join_by(code == value)
                  ) %>%
  mutate(prop = round(prop,
                      digits =3)
         ) %>%
  relocate(geom, .after = everything()) %>%
  relocate(class, .after = region_name) %>%
  relocate(classification, .after = class) %>%
  relocate(description, .after = classification) %>%
  arrange(macro_id, desc(prop)
)

------------------------------------------------------------------------------
# 4. Group results for model inputs
# ------------------------------------------------------------------------------
nlcd_grouped_long <-  nlcd %>%
  dplyr::filter(class %in% c(
    "Cultivated", "Developed", "Forest", "Rangeland")) %>%
  dplyr::group_by(macro_id, region_name, macrozone, class) %>%
  dplyr::summarise(prop = sum(prop, na.rm = TRUE), .groups = "drop") %>%
  dplyr::arrange(macro_id, class)

# wide (one row per macrozone, cols per grouped class)
nlcd_grouped_wide <- nlcd_grouped_long %>%
  tidyr::pivot_wider(
    names_from   = class,
    values_from  = prop,
    values_fill  = 0,
    names_prefix = "prop_"
  )

# --- double-check results ---
qa_sum <- nlcd_grouped_long %>%
  dplyr::group_by(macro_id) %>%
  dplyr::summarise(sum_four = sum(prop), .groups = "drop")

# ------------------------------------------------------------------------------
# 5. Output results
# ------------------------------------------------------------------------------
out_path_nlcd_detail <- here("data", "covars", "macro_nlcd_detail.csv")
write_csv(nlcd, out_path_nlcd_detail)

out_path_nlcd<- here("data", "covars", "macro_nlcd.csv")
write_csv(nlcd_grouped_wide, out_path_nlcd)
