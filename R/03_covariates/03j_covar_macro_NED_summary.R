# ==============================================================================
# Script Name:      03j_covar_macro_slope_stats.R
# Purpose:          Calculate mean and median slope from NED
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-10-02
# Last Updated:     2025-10-10
#
# Changelog:
#  2025-10-02      Initial script
#  2025-10-03      Fix error in calculating slope stats:
#                    Error in fun(arg_df, ...) : 
#                      argument "cov_frac" is missing, with no default; create
#                  header metadata.
#  2025-10-10      Fixed issue with incorrect project CRS.
#
# Generalized Workflow:
# 1. Load and check rasters and zones.
# 2. Run a preflight check:
#    - Verify that rasters can be opened.
#    - Enforce CRS and polygonal geometry.
#    - Standardize the geometry column as `geom`.
#    - Guarantees unique, non-NA IDs.
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
# Conventions: EPSG:5070, 'geom' active geometry, join key = macro_id
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
rast_path <- here("data", "processed", "ned", "slope_gp_5070_90m.tif")

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- st_read(zone_path, layer = layer_name, quiet = TRUE)

# ------------------------------------------------------------------------------
# 2. Run a Preflight Check
# ------------------------------------------------------------------------------
zones <- assert_inputs_ok(
  raster_paths   = rast_path,
  zones          = zones,
  req_cols       = "macro_id",
  id_col         = "macro_id",
  target_crs     = 5070,
  enforce_unique = TRUE,
  quiet          = FALSE
)

# --- ensure raster and zone are prepped and aligned ---

slope_prep <- prep_raster(rast_path, zones, do_crop = TRUE, do_mask = FALSE)
r_slope    <- slope_prep$r
z_slope_sf <- sf::st_as_sf(slope_prep$zones); sf::st_geometry(z_slope_sf) <- "geom"




terra::summary(r_slope)
terra::minmax(r_slope)
terra::crs(r_slope)
terra::units(r_slope)



# ------------------------------------------------------------------------------
# 3. Sanity checks (run once before cont_summary)
# ------------------------------------------------------------------------------

# 1) Raster: class + single band
stopifnot(inherits(r_slope, "SpatRaster"))
stopifnot(terra::nlyr(r_slope) == 1L)

# 2) Zones: sf polygons + id present + not all NA
stopifnot(inherits(z_slope_sf, "sf"))
geom_type <- unique(sf::st_geometry_type(z_slope_sf, by_geometry = TRUE))
stopifnot(all(geom_type %in% c("POLYGON", "MULTIPOLYGON")))
stopifnot("macro_id" %in% names(z_slope_sf))
stopifnot(!all(is.na(z_slope_sf$macro_id)))

# 3) CRS alignment: identical proj4/WKT (exactextractr expects same CRS)
r_crs  <- terra::crs(r_slope, proj = TRUE)
z_crs  <- sf::st_crs(z_slope_sf)$wkt
if (!identical(r_crs, z_crs)) {
  # prefer transforming polygons to raster CRS to avoid resampling slope
  z_slope_sf <- sf::st_transform(z_slope_sf, r_crs)
  sf::st_geometry(z_slope_sf) <- "geom"  # keep project convention
}

# 4) Valid geometries + not empty
stopifnot(all(sf::st_is_valid(z_slope_sf)))
stopifnot(nrow(z_slope_sf) > 0)

# 5) Optional: duplicates and NA coverage checks
stopifnot(!anyDuplicated(z_slope_sf$macro_id))

na_frac <- terra::global(is.na(r_slope), "mean", na.rm = TRUE)[[1]]
message(sprintf("Raster NA fraction: %.3f", na_frac))

# 6) Optional: spot-check resolution looks sane 
res_xy <- terra::res(r_slope)
message(sprintf("Raster resolution: %g x %g (in raster CRS units)", res_xy[1], res_xy[2]))





cov_ok <-exactextractr::exact_extract(
    r_slope,
    z_slope_sf,
    fun = function(df) c(n_cells_covered = sum(!is.na(df[[1]]) & df$coverage_fraction > 0)),
    summarize_df = TRUE,
    include_cols = "macro_id",
    progress = TRUE
  )


z_zero_cov <- z_slope_sf[ cov_ok[[1]] == 0, ]
if (nrow(z_zero_cov)) {
  cli::cli_warn("{nrow(z_zero_cov)} zones have zero valid slope coverage.")
}

# ------------------------------------------------------------------------------
# 3. Calculate summary stats
# ------------------------------------------------------------------------------







# area-weighted mean + median using pixel coverage_fraction
slope_tbl <- exactextractr::exact_extract(
    r_slope,
    z_slope_sf,
    fun = function(df) {
      
      x <- df[[1]]
      w <- df$coverage_fraction
      
      keep <- !is.na(x) & !is.na(w) & (w > 0)
      x <- x[keep]
      w <- w[keep]
      
      # weighted median helper
      w_median <- function(x, w) {
        o  <- order(x)
        x  <- x[o]
        w  <- w[o]
        w  <- w / sum(w)
        cw <- cumsum(w)
        x[which(cw >= 0.5)[1]]
      }
      
      c(
        mean   = stats::weighted.mean(x, w, na.rm = TRUE),
        median = w_median(x, w)
      )
    },
    summarize_df = TRUE,
    include_cols = "macro_id",
    progress     = TRUE
  )


macro_ids <- z_slope_sf$macro_id

colnames(slope_tbl) <- macro_ids
slope_tbl <- as_tibble(slope_tbl, rownames = "stat")


slope_tbl_tidy <- slope_tbl %>%
#  rownames_to_column("stat") %>%
  pivot_longer(-stat, names_to = "macro_id", values_to = "value") %>%
  pivot_wider(names_from = stat, values_from = value)


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




