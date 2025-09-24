# ==============================================================================
# Script Name:      03f_covar_macro_koppen_summary.R
# Purpose:          Calculate dominant Koppen climate zones at macrozone scale
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-09-01
# Last Updated:     2025-09-14
#
# Changelog:
# - 2025-09-01     Initialize script -- as a composite
# - 2025-09-02     Add zonal summaries (KG, PHZM, NLCD, slope, gage elev);
#                  write CSV/GPKG.
# - 2025-09-03     Wire in assert_inputs_ok(); lazy-load rasters; minor hardening;
#                  Add first attempt at uniform code to prep and align, summarise,
#                  and add metadata to result.
# - 2025-09-04     Rename script; update Koppen zonal summary to top n classes
# - 2025-09-14     Split original script into parts.
# - 2025-09-15     Update metadata
# - 2025-09-22     Add QA check on CRS
#
# Generalized Workflow:
# 1. Load rasters and zones.
# 2. Run preflight check:                   utils/spatial/assert_inputs_ok.R.
#    - Verify that rasters can be opened.
#    - Enforce CRS and polygonal geometry.
#    - Standardize the geometry column as `geom`.
#    - Guarantees unique, non-NA IDs.
#    - Reproject to the project CRS: NAD83 / EPSG:4269 if needed.
# 3. Prep and align raster and zone:        utils/spatial/prep_and_align
#     - align_zones_to(zones, rst, ...)
#       - Ensures zones are valid (optional), converts to SpatVector, and
#          reprojects zones to the raster’s CRS (no raster warping).
#        - Returns a SpatVector (polygons) in the same CRS as the raster.
#     - prep_raster(rst, zones, do_crop = TRUE, do_mask = TRUE, ...)
#       - Opens the raster (or path) as a SpatRaster.
#       - Calls align_zones_to() to get zones in the raster CRS.
#       - Optionally crops the raster to the zones bbox and masks it to the
#         polygon shapes.
#     - Returns list(r = <SpatRaster>, zones = <SpatVector>).
# Note: prior to summarising the raster with {exactextractor}, the raster needs
#       to be converted from a SpatVector to an sf object.
# 4. Summarise raster:                     utils/spatial/rast_summ_by class
#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg 
#                    (layer = "macrozones_gp")
#   raster:      data/processed/koppen_climate/koppen_geiger.tif
#
# Outputs:
#   data/covars/macro_koppen.csv -- table of dominant classes in each macrozone.
#
# Conventions: 
# - Common CRS for spatial analysis -- US Albers Equal Area = EPSG:5070
# - Active geometry = 'geom'
# - Join key = macro_id
#
# Dependencies: here, sf, terra, tidyverse, exactextractr
#
# Related Files:
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
source(file.path(here(), "R", "utils", "spatial", "assert_inputs_ok.R"))
source(file.path(here(), "R", "utils", "spatial", "prep_and_align.R"))
source(file.path(here(), "R", "utils", "spatial", "rast_summ_by_class.R"))

# ------------------------------------------------------------------------------
# 1. Load raster and zone
# ------------------------------------------------------------------------------
# --- rasters ---
koppen_path <- here("data", "processed", "koppen_climate", "koppen_geiger.tif")

# --- metadata ---
meta_koppen_path <- here("docs", "metadata", "look_up_tables",
                         "koppen-geiger_class_lut.csv"
)

meta_koppen <- read_csv(meta_koppen_path)

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- st_read(zone_path, layer = layer_name, quiet = TRUE)

# ------------------------------------------------------------------------------
# 2. Run a Preflight Check -- using assert_inputs_ok()
# ------------------------------------------------------------------------------
raster_path <- c(koppen = koppen_path)

zones <- assert_inputs_ok(
  raster_paths   = raster_path,
  zones          = zones,
  req_cols       = "macro_id",
  id_col         = "macro_id",
  target_crs     = 4269,               # <-- double-check thru outputs 
  enforce_unique = TRUE,
  quiet          = FALSE
)

# ------------------------------------------------------------------------------
# 3. Koppen–Geiger n-dominant classes
# ------------------------------------------------------------------------------
# --- Prep + summarize (mask=FALSE since exactextractr weights) ---
prep_koppen <- prep_raster(koppen_path, zones,
                           do_crop = TRUE,
                           do_mask = FALSE)

# --- pull raster and zones ---
r_koppen    <- prep_koppen$r

z_koppen_sf <- sf::st_as_sf(
  prep_koppen$zones); sf::st_geometry(z_koppen_sf) <- "geom"

# --- perform QA ---
qa_crs_r <- tibble(crs(r_koppen))

qa_crs_z <- tibble(crs(r_koppen))


# --- make a table of explained and unexplained ---
#       note: check n, should be 3
tbl_koppen <- top_n_categories(r_koppen,
                               z_koppen_sf,
                               n = 3,
                               id_col = "macro_id"
                               ) %>%
  # --- round area and proportion ---
  mutate(area = round(area, digits = 0)) %>%
  mutate(prop = round(prop, digits = 3)) %>%
  # --- calculate unexplained frac ---
  group_by(macro_id) %>%
  mutate(tot_unexpl = 1 - sum(prop)) %>%
  ungroup() %>%
  # --- clean up table ---
  mutate(num_cat = 3) %>%
  relocate(num_cat, .before = everything()) %>%
  rename(prop_expl = prop) %>%
  arrange(desc(prop_expl)) %>%
  arrange(macro_id)

# ------------------------------------------------------------------------------
# 5. Simplify results to maximize information gain
# ------------------------------------------------------------------------------
# Apply a minimum fraction threshold
min_frac <- .14

tbl_koppen_filtered <- tbl_koppen %>%
  filter(prop_expl >= min_frac) %>%
  group_by(macro_id) %>%
  mutate(tot_unexpl = 1 - sum(prop_expl)) %>%
  ungroup() %>%
  arrange(desc(tot_unexpl))

tbl_koppen_filtered <- left_join(tbl_koppen_filtered, meta_koppen,
                        join_by(value == code)
)

tbl_koppen_filtered <- left_join(zones, tbl_koppen_filtered,
                        join_by(macro_id)
)

# ------------------------------------------------------------------------------
# 5. Export results
# ------------------------------------------------------------------------------
out_path <- here("data", "covars", "macro_koppen.csv")
write_csv(tbl_koppen_filtered, out_path)
