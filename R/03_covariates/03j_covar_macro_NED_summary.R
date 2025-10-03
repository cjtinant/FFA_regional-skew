# ==============================================================================
# Script Name:      03j_covar_macro_slope_stats.R
# Purpose:          Calculate mean and median slope from NED
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-10_02
# Last Updated:     2025-10_03
#
# Changelog:
# - 2025-10-02     Initial script
# - 2025-10-03     Fix error in calculating slope stats:
#                    Error in fun(arg_df, ...) : 
#                      argument "cov_frac" is missing, with no default; create
#                  header metadata.
#
# Generalized Workflow:
# 1. Load and check rasters and zones.
# 2. 
# 2-4. Check `03f_covar_macro_koppen_summary.R`` for details.
# 5. Count NLCD class areas via robust tiler -- IDs carried through;
#    coverage_area summed; outputs  macro_id, value (NLCD class), area (m^2)
# 6. Join macro_id to grouped columns of counts and summarise NLCD class
#    fractions by macro_id

#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg 
#                    (layer = "macrozones_gp")
#   rasters:      data/processed/ned/slope_30m_gp.tif
#
# Outputs:
#                  data/processed/us_ecoregions/macrozones_covars.csv
#                  data/processed/us_ecoregions/macrozones_gp_with_covars.gpkg 
#                    (layer "macrozones_gp")
#
# Conventions: EPSG:4269, 'geom' active geometry, join key = macro_id
#
# Dependencies: here, sf, terra, tidyverse, exactextractr
#
# Related Files:
# - Metadata to join from /docs/metadata:
#   - Koppen-Geiger class lut: /look_up_tables/koppen-geiger_class_lut.csv
#   - 03d_make_macrozone_layer.R
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
# # --- Slope mean/median (continuous) ---
# ==============================================================================
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
source(file.path(here(), "R", "utils", "spatial", "rast_summ_continuous.R"))

# ------------------------------------------------------------------------------
# 1. Load and check inputs
# ------------------------------------------------------------------------------
# --- rasters ---
rast_path <- here("data", "processed", "ned", "slope_30m_gp.tif")

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- st_read(zone_path, layer = layer_name, quiet = TRUE)

# --- ensure raster and zone are prepped and aligned ---
slope_prep <- prep_raster(rast_path, zones, do_crop = TRUE, do_mask = FALSE)
r_slope    <- slope_prep$r
z_slope_sf <- sf::st_as_sf(slope_prep$zones); sf::st_geometry(z_slope_sf) <- "geom"

# ------------------------------------------------------------------------------
# 2. Calculate summary stats
# ------------------------------------------------------------------------------











# # --- Slope mean/median (continuous) ---
# # Error in fun(arg_df, ...) : 
# # argument "cov_frac" is missing, with no default
# slope_stats <- exactextractr::exact_extract(
#   r_slope, z_slope_sf,
#   fun = function(df, cov_frac) {
#     v <- df[[1]]; w <- cov_frac
#     ok <- !is.na(v) & !is.na(w)
#     if (!any(ok)) return(c(wmean = NA_real_, wmedian = NA_real_))
#     wmean <- sum(v[ok] * w[ok]) / sum(w[ok])
#     ord <- order(v[ok]); v2 <- v[ok][ord]; w2 <- w[ok][ord]
#     csum <- cumsum(w2) / sum(w2)
#     wmedian <- v2[which(csum >= 0.5)][1]
#     c(wmean = wmean, wmedian = wmedian)
#   },
#   summarize_df = TRUE, progress = FALSE
# )
# 
# slope_tbl <- tibble::tibble(
#   macro_id         = z_slope_sf$macro_id,
#   slope_mean_pct   = slope_stats[[1]],
#   slope_median_pct = slope_stats[[2]]
# )
# 
# # --- Mean gage elevation by macrozone ---
# if (!"macro_id" %in% names(gages)) {
#   gages <- st_join(st_transform(gages, st_crs(zones)), zones %>% dplyr::select(macro_id))
# }
# elev_field <- c("elev_m","elevation_m","elev","elev_m_navd88")[
#   c("elev_m","elevation_m","elev","elev_m_navd88") %in% names(gages)
# ][1]
# 
# gage_elev_tbl <- gages %>%
#   sf::st_drop_geometry() %>%
#   dplyr::filter(!is.na(macro_id)) %>%
#   dplyr::group_by(macro_id) %>%
#   dplyr::summarise(
#     mean_gage_elev_m = if (!is.na(elev_field)) mean(.data[[elev_field]], na.rm = TRUE) else NA_real_,
#     .groups = "drop"
#   )
# 
# # ------------------------------------------------------------------------------
# # 3) Assemble + write
# # ------------------------------------------------------------------------------
# out_tbl <- zones %>%
#   sf::st_drop_geometry() %>%
#   dplyr::select(macro_id) %>%
#   dplyr::distinct() %>%
#   dplyr::left_join(tbl_koppen,        by = "macro_id") %>%
#   dplyr::left_join(phzm_tbl,      by = "macro_id") %>%
#   dplyr::left_join(nlcd_tbl,      by = "macro_id") %>%
#   dplyr::left_join(slope_tbl,     by = "macro_id") %>%
#   dplyr::left_join(gage_elev_tbl, by = "macro_id") %>%
#   dplyr::arrange(macro_id)
# 
# out_csv  <- here("data", "processed", "us_ecoregions", "macrozones_covars.csv")
# out_gpkg <- here("data", "processed", "us_ecoregions", "macrozones_gp_with_covars.gpkg")
# 
# fs::dir_create(dirname(out_csv))
# readr::write_csv(out_tbl, out_csv)
# 
# zones_out <- zones %>% dplyr::left_join(out_tbl, by = "macro_id")
# if (file.exists(out_gpkg)) file.remove(out_gpkg)
# sf::st_write(zones_out, out_gpkg, layer = layer_name, quiet = TRUE)
# 
# message("Wrote: ", out_csv)
# message("Wrote: ", out_gpkg)


# # --- Prepare Koppen Geiger ---
# prep_koppen <- prep_raster(koppen_path,
#                            zones,
#                            do_crop = TRUE,
#                            do_mask = FALSE
# )
# 
# # --- Pull raster (r_) and zone (z_) ---
# r_koppen <- kg_prep$r
# 
# z_koppen_sf  <- sf::st_as_sf(kg_prep$zones); sf::st_geometry(z_kg_sf) <- "geom"
# 

# --- Make raster paths --- 

# 
# # --- Build raster path vector for the helper ---
# raster_paths <- c(
#   koppen = koppen_path,
#   phzm   = phzm_path,
#   nlcd   = nlcd_path,
#   slope  = ned_path
# )
# 
# # --- Run preflight: enforces EPSG:4269 and 'geom' geometry col, checks files ---
# zones <- assert_inputs_ok(
#   raster_paths = raster_paths,
#   zones        = zones,
#   req_cols     = "macro_id",
#   id_col       = "macro_id",
#   target_crs   = 4269,
#   enforce_unique = TRUE,
#   quiet        = FALSE
# )
# 
# # --- sanity checks ---
# stopifnot(file.exists(koppen_path), file.exists(phzm_path),
#           file.exists(nlcd_path),   file.exists(ned_path))
# 
# z_test <- assert_inputs_ok(
#   raster_paths = c(koppen_path, phzm_path, nlcd_path, ned_path),
#   zones        = zones,
#   req_cols     = "macro_id",
#   id_col       = "macro_id",
#   target_crs   = 4269
# )
# 
# # geometry column & CRS checks
# stopifnot(attr(z_test, "sf_column") == "geom")
# stopifnot(sf::st_crs(z_test)$epsg == 4269)
# stopifnot(anyDuplicated(z_test$macro_id) == 0)
# 
# 
# 


# # --- Load rasters ---
# # rasters
# r_koppen <- rast(here("data", "processed", "koppen_climate", "koppen_geiger.tif"))
# r_phzm   <- rast(here("data", "processed", "phzm", "phzm.tif"))
# r_nlcd   <- rast(here("data", "processed", "nlcd", "nlcd_2016_gp.tif"))
# r_slope  <- rast(here("data", "processed", "ned", "slope_30m_gp.tif"))
# 
# 
# 
# # --- Load gages ---
# gage_path <- here("data", "processed", "peakflow_gages", "gage_covars.gpkg")
# gages <- st_read(gage_path, quiet = TRUE)
# st_geometry(gages) <- "geom"
# 
# # ------------------------------------------------------------------------------
# # 2) Preflight checks & alignment
# # ------------------------------------------------------------------------------
# assert_inputs_ok(
#   zones      = zones,
#   rasters    = list(r_koppen, r_phzm, r_nlcd, r_slope),
#   id_field   = "macro_id",
#   expect_poly= TRUE
# )




