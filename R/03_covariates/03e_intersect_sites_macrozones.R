# ==============================================================================
# Script Name:      03e_calculate_macrozone_stats.R
# Purpose:          Calculate covariate stats at the macrozone scale.
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-09-01
# Last Updated:     2025-09-03
#
# Changelog:
# - 2025-09-01  Initialize script
# - 2025-09-02  Add zonal summaries (KG, PHZM, NLCD, slope, gage elev);
#               write CSV/GPKG.
# - 2025-09-03  Wire in assert_inputs_ok(); lazy-load rasters; minor hardening;
#               Add first attempt at uniform code to prep and align, summarise,
#               and add metadata to result.
#
# Generalized Workflow:
# 1. Load rasters and zones.
# 2. Run preflight check:                   utils/spatial/assert_inputs_ok.R.
#    - Verify that rasters can be opened.
#    - Enforce CRS and polygonal geometry.
#    - Standardize the geometry column as `geom`.
#    - Guarantees unique, non-NA IDs.
#    - Optionally reproject to the project CRS: NAD83 / EPSG:4269.
#
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
#
# 4. Summarise rasters:                     utils/spatial/rast_summ_by class or
#                                           utils/spatial/rast_summ_continuous
#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg 
#                    (layer = "macrozones_gp")
#   rasters:      data/processed/koppen_climate/koppen_geiger.tif
#                 data/processed/phzm/phzm.tif
#                 data/processed/nlcd/nlcd_2016_gp.tif
#                 data/processed/ned/slope_30m_gp.tif
#   gages:        data/processed/peakflow_gages/gage_covars.gpkg
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
#
# - Documentation files to check/update
#   - CHANGELOG.md
#   - 03d_make_macrozone_layer.R
#   - output/figs/macrozones_map.png
#   - data/log_README.pdf
#   - R/log_README.pdf
#   - R/README.pdf
#   - notes/script-notes_and_developer-log.pdf
#   - milestone_03_prepare_covariates.pdf
#   - 
#
# Notes:
#   - NLCD class sets: developed 21–24; cultivated 81–82; forest 41–43;
#     grassland 71.
#   - If gage attribute 'elev_m' is missing, falls back to sampling NED at gage
#     points.

#                  - Count of Plant Hardiness Zones
#                  - Dominant Plant Hardiness Zone
#                  - Mean slope of NED
#                  - Median slope of NED
#                  - Mean elevation of USGS station data
#                  - Fraction of NLCD:
#                    - Cultivated lands
#                    - Forested lands
#                    - Grasslands
#                    - Developed Fraction
#
# NEXT STEPS -- 
# - circle back on adding the fraction of the dominant class to the helper
#   function to flag any potential issues.
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
source(file.path(here(), "R", "utils", "spatial", "rast_summ_continuous.R"))

# ------------------------------------------------------------------------------
# 1) Load inputs -- fix zones join key
# ------------------------------------------------------------------------------
# --- rasters ---
koppen_path <- here("data", "processed", "koppen_climate", "koppen_geiger.tif")
phzm_path <- here("data", "processed", "phzm", "phzm.tif")
nlcd_path <- here("data", "processed", "nlcd", "nlcd_2016_gp.tif")
slope_path <- here("data", "processed", "ned", "slope_30m_gp.tif")
gage_path   <- here("data", "processed", "peakflow_gages", "gage_covars.gpkg")

# --- metadata ---
meta_koppen_path <- here("docs", "metadata", "look_up_tables",
                    "koppen-geiger_class_lut.csv"
)

meta_koppen <- read_csv(koppen_meta_path)

# --- gages ---
gages <- st_read(gage_path, quiet = TRUE)

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

# --- correct join key ---
zones <- st_read(zone_path, layer = layer_name, quiet = TRUE) %>%
  mutate(macro_id = case_when(
    region_name == "Shortgrass-Steppe" ~ 1,
    region_name == "Northern Mixed-Grass Prairie" ~ 2,
    region_name == "Central Mixed-Grass Prairie" ~ 3,
    region_name == "Southern Mixed-Grass Prairie" ~ 4,
    region_name == "Prairie Tallgrass Prairie" ~ 5,
    region_name == "Tallgrass Prairie" ~ 5,
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

# ------------------------------------------------------------------------------
# 2) Run a Preflight Check -- using assert_inputs_ok()
# ------------------------------------------------------------------------------
raster_paths <- c(
  koppen = koppen_path,
  phzm   = phzm_path,
  nlcd   = nlcd_path,
  slope  = slope_path
)

zones <- assert_inputs_ok(
  raster_paths   = raster_paths,
  zones          = zones,
  req_cols       = "macro_id",
  id_col         = "macro_id",
  target_crs     = 4269,
  enforce_unique = TRUE,
  quiet          = FALSE
)

# ------------------------------------------------------------------------------
# 3) Prep + summarize (uniform pattern; mask=FALSE since exactextractr weights)
# ------------------------------------------------------------------------------
# --- Koppen–Geiger (dominant) ---
prep_koppen <- prep_raster(koppen_path, zones,
                           do_crop = TRUE,
                           do_mask = FALSE)

r_koppen    <- prep_koppen$r
z_koppen_sf <- sf::st_as_sf(
  prep_koppen$zones); sf::st_geometry(z_koppen_sf) <- "geom"

tbl_koppen <- dominant_category(r_koppen, z_koppen_sf, id_col = "macro_id") %>%
  dplyr::rename(koppen_dominant = .dominant)

tbl_koppen <- left_join(tbl_koppen, meta_koppen,
                        join_by(koppen_dominant == code)
)

tbl_koppen <- left_join(zones, tbl_koppen,
                        join_by(macro_id))

# START HERE AFTER UPDATING TO ADD DOMINANT FRACTION TO OUTPUT

# --- PHZM (dominant + count) ---
phzm_prep <- prep_raster(phzm_path, zones, do_crop = TRUE, do_mask = FALSE)
r_phzm    <- phzm_prep$r
z_phzm_sf <- sf::st_as_sf(phzm_prep$zones); sf::st_geometry(z_phzm_sf) <- "geom"

# ph_counts <- category_counts(r_phzm, z_phzm_sf, id_col = "macro_id")    # id_col, value, area
# ph_totals <- ph_counts %>%
#   dplyr::group_by(macro_id) %>%
#   dplyr::summarise(phzm_class_count = dplyr::n(), .groups = "drop")
# 
# ph_dom <- dominant_category(r_phzm, z_phzm_sf, id_col = "macro_id") %>%
#   dplyr::rename(phzm_dominant = .dominant)
# 
# phzm_tbl <- ph_dom %>%
#   dplyr::left_join(ph_totals, by = "macro_id")
# 
# # --- NLCD fractions (one pass, multi-groups) ---
# nlcd_groups <- list(
#   nlcd_frac_developed  = 21:24,
#   nlcd_frac_forest     = 41:43,
#   nlcd_frac_grassland  = 71,
#   nlcd_frac_cultivated = 81:82
# )
# 
# nlcd_prep <- prep_raster(nlcd_path, zones, do_crop = TRUE, do_mask = FALSE)
# r_nlcd    <- nlcd_prep$r
# z_nlcd_sf <- sf::st_as_sf(nlcd_prep$zones); sf::st_geometry(z_nlcd_sf) <- "geom"
# 
# # Use category_counts() once, then derive fractions
# nlcd_counts <- category_counts(r_nlcd, z_nlcd_sf, id_col = "macro_id")
# nlcd_totals <- nlcd_counts %>%
#   dplyr::group_by(macro_id) %>%
#   dplyr::summarise(area_tot = sum(area), .groups = "drop")
# 
# nlcd_tbl <- purrr::imap_dfr(nlcd_groups, function(classes, nm) {
#   nlcd_counts %>%
#     dplyr::filter(value %in% classes) %>%
#     dplyr::group_by(macro_id) %>%
#     dplyr::summarise(area_grp = sum(area), .groups = "drop") %>%
#     dplyr::right_join(nlcd_totals, by = "macro_id") %>%
#     dplyr::mutate("{nm}" := dplyr::if_else(area_tot > 0, area_grp / area_tot, NA_real_)) %>%
#     dplyr::select(macro_id, dplyr::all_of(nm))
# }) %>%
#   purrr::reduce(~ dplyr::full_join(.x, .y, by = "macro_id"))
# 
# # --- Slope mean/median (continuous) ---
# slope_prep <- prep_raster(slope_path, zones, do_crop = TRUE, do_mask = FALSE)
# r_slope    <- slope_prep$r
# z_slope_sf <- sf::st_as_sf(slope_prep$zones); sf::st_geometry(z_slope_sf) <- "geom"
# 
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
# 

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




