# ==============================================================================
# Script Name:      03g_covar_macro_phzm_summary.R
# Purpose:          Calculate dominant and count of phzm climate zones at the
#                   macrozone scale
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-09-01
# Last Updated:     2025-09-22
#
# Changelog:
# - 2025-09-01     Initialize script
# - 2025-09-02     Add zonal summaries (KG, PHZM, NLCD, slope, gage elev);
#                  write CSV/GPKG.
# - 2025-09-03     Wire in assert_inputs_ok(); lazy-load rasters; minor hardening;
#                  Add first attempt at uniform code to prep and align, summarise,
#                  and add metadata to result.
# - 2025-09-15     Split original script into parts.
# - 2025-09-22     Add NLCD look-up table;
# - 2025-09-22     Make NLCD extraction more robust: 
#                  (1) pass dissolve_by_id = TRUE to carry macro_id through
#                      exact_extract() (include_cols) and sum coverage_area
#                      safely across tiles.
#                  (2) Mask when prepping (do_mask = TRUE) to skip cells outside
#                      macrozones.
#                  (3) Compute fractions + grouped columns in the same run, with
#                      a couple QA checks. The update fixes these issues:
#                  (a) ID/index mismatch: include_cols in the updated tiler
#                      carries macro_id; we never “attach” by position;
#                  (b) Tile splits are OK: duplicates across tiles get summed by
#                      (macro_id, value)
#                  (c) Area correctness: uses coverage_area (square meters in
#                      NLCD’s Albers), summed directly;
#                  (d) Speed: do_mask = TRUE and dissolving by ID reduce polygon
#                      complexity and cell reads.
#                  (e) Stability: st_make_valid() is always applied in the tiler;
#                      optional simplify retained.
# - 2025-09-22     fix(nlcd): diagnose off-legend NLCD codes; enforce categorical
#                  handling. Potential root cause: bilinear/cubic resampling
#                  created non-legend class codes. Add: rebuild NLCD subset with
#                  nearest-neighbor in EPSG:5070. Add guard. check_nlcd_levels()
#                  to stop when off-legend share > 1%



#
# Generalized Workflow:
# 1. Make NLCD lookup table.
# 2-4. Check `03f_covar_macro_koppen_summary.R`` for details.
# 5. Count NLCD class areas via robust tiler -- IDs carried through;
#    coverage_area summed; outputs  macro_id, value (NLCD class), area (m^2)
# 6. Join macro_id to grouped columns of counts and summarise NLCD class
#    fractions by macro_id


# 7. 


#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg 
#                    (layer = "macrozones_gp")
#   rasters:      data/processed/phzm/phzm.tif
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
# - NEXT STEPS add nlcd_groups
#
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
source(file.path(here(), "R", "utils", "spatial", "rast_summ_by_class.R"))

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
  52, "Shrubland", "Shrub/Scrub", "shrubs lt 5m, canopy gt 20pct, true shrubs, young trees",
  71, "Grassland", "Grassland/Herbaceous", "grass or herbs gt 80pct, can be grazed",
  81, "Cultivated", "Pasture/Hay", "planted grass and/or legumes for grazing or hay",
  82, "Crops", "Cultivated Crops", "tilled, annual corn, soybeans, veges, orchards",
  90, "Wetlands", "Woody Wetlands", "periodically saturated forest or shrubland",
  95, "Wetlands,", "Emergent Herbaceous Wetlands", "pdic saturated perranial herbs"
)

# --- Write look-up table
meta_out_path  <- here("docs", "metadata", "look_up_tables", "nlcd_metadata_lut.csv")
write_csv(nlcd_lut, meta_out_path)

# ------------------------------------------------------------------------------
# 2) Inputs
# ------------------------------------------------------------------------------
nlcd_path  <- here("data", "processed", "nlcd", "nlcd_2016_gp.tif")
zone_path  <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- sf::st_read(zone_path, layer = layer_name, quiet = TRUE)

# ------------------------------------------------------------------------------
# 3) Preflight (CRS = NAD83 / EPSG:4269; geometry name = 'geom')
# ------------------------------------------------------------------------------
# raster_paths <- c(nlcd = nlcd_path)
# 
# zones <- assert_inputs_ok(
#   raster_paths   = raster_paths,
#   zones          = zones,
#   req_cols       = "macro_id",
#   id_col         = "macro_id",
#   target_crs     = 4269,
#   enforce_unique = TRUE,
#   quiet          = FALSE
# )
# sf::st_geometry(zones) <- "geom"


# ------------------------------------------------------------------------------
# 4-new) Prep raster (crop + mask for speed)
# ------------------------------------------------------------------------------
# Rebuild clean NLCD (5070) subset in R
r0 <- terra::rast(nlcd_path)
gp <- zones
# r0 <- terra::rast(here("data/raw/nlcd/nlcd_2016_land_cover_l48_20210604.tif"))  # example
# gp <- sf::st_read(here("data/processed/us_ecoregions/macrozones_gp.gpkg"), quiet = TRUE)

# project AOI to raster CRS
gp_5070 <- sf::st_transform(gp, terra::crs(r0))

# crop + mask with nearest-neighbor (no reproject of raster!)
r_clean <- r0 %>%
  terra::crop(terra::vect(gp_5070)) %>%
  terra::mask(terra::vect(gp_5070)) %>%
  terra::as.int()

terra::writeRaster(
  r_clean,
  filename = here("data/processed/nlcd/nlcd_2016_gp_clean.tif"),
  overwrite = TRUE,
  gdal = c("COMPRESS=LZW", "TILED=YES")
)



# ------------------------------------------------------------------------------
# 4orig) Prep raster (crop + mask for speed)
# ------------------------------------------------------------------------------
nlcd_groups <- list(
  nlcd_frac_developed  = 21:24,
  nlcd_frac_forest     = 41:43,
  nlcd_frac_grassland  = 71,
  nlcd_frac_cultivated = 81:82
)

nlcd_prep <- prep_raster(
#  nlcd_path,
  r_clean,
  zones,
  do_crop = TRUE,
  do_mask = TRUE    # <- mask to macrozones to avoid reading unneeded cells
)

r_nlcd    <- nlcd_prep$r
z_nlcd_sf <- sf::st_as_sf(nlcd_prep$zones); sf::st_geometry(z_nlcd_sf) <- "geom"

# ------------------------------------------------------------------------------
# 5) NLCD class areas via robust tiler (IDs carried through; coverage_area summed)
# ------------------------------------------------------------------------------
counts <- category_counts_tiled(
  r                  = r_nlcd,
  zones              = z_nlcd_sf,
  id_col             = "macro_id",
  nx                 = 6,
  ny                 = 6,
  zones_simplify_tol = 0,
  dissolve_by_id     = TRUE,              # <- IMPORTANT
  tmp_dir            = here::here("tmp", "nlcd_partials"),
  progress           = FALSE
  )

# --- (Optional) quick sanity peek (should NOT be empty) ---
# dplyr::glimpse(counts)

# ------------------------------------------------------------------------------
# 6) Fractions per macro_id + grouped columns
# ------------------------------------------------------------------------------
fractions <- counts %>%
  dplyr::group_by(macro_id) %>%
  dplyr::mutate(total_area = sum(area, na.rm = TRUE)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(frac = area / total_area) %>%
  dplyr::select(macro_id, value, area_m2 = area, frac)

# --- map NLCD class codes to group names ---
class_map <- tibble::tibble(
    value = unlist(nlcd_groups, use.names = FALSE),
    group = rep(names(nlcd_groups), lengths(nlcd_groups))
  )

# --- summarise NLCD class fractions by macro_id ---
nlcd_grouped <- fractions %>%
  dplyr::inner_join(class_map, by = "value") %>%
  dplyr::group_by(macro_id, group) %>%
  dplyr::summarise(frac = sum(frac, na.rm = TRUE), .groups = "drop") %>%
  tidyr::pivot_wider(
    names_from  = group,
    values_from = frac,
    values_fill = 0
  ) %>%
  dplyr::right_join(
    fractions %>% dplyr::distinct(macro_id),
    by = "macro_id"
  ) %>%
  dplyr::arrange(macro_id)

# --- round the fraction of total area ---
nlcd_grouped <- nlcd_grouped %>%
  dplyr::mutate(
    dplyr::across(
      dplyr::starts_with("nlcd") & where(is.numeric),
      ~ round(.x, 3)
    )
  )
  
# ------------------------------------------------------------------------------
# 6) Perform QA checks
# ------------------------------------------------------------------------------
# Sum of grouped fractions should be <= 1
qa_sum <- nlcd_grouped %>%
  dplyr::mutate(
    sum_known = nlcd_frac_developed + nlcd_frac_forest +
      nlcd_frac_grassland + nlcd_frac_cultivated
  ) %>%
  dplyr::summarise(min = min(sum_known), max = max(sum_known))

# (Optional): flag weird totals
if (qa_sum$max > 1 + 1e-6) {
  warning("Grouped NLCD fractions exceed 1 for at least one macro_id.")
}

# (Optional): show first few rows
print(dplyr::slice_head(nlcd_grouped, n = 10))

# --- check other classes ---
grouped_codes <- unlist(nlcd_groups, use.names = FALSE)

other_by_class <- fractions %>%
  dplyr::filter(!value %in% grouped_codes) %>%
  dplyr::group_by(value) %>%
  dplyr::summarise(
    area_m2 = sum(area_m2, na.rm = TRUE),
    frac_sum = sum(frac, na.rm = TRUE),   # across all macro_ids (not a prob.)
    .groups = "drop"
  ) %>%
  dplyr::arrange(dplyr::desc(area_m2))

other_by_class <- left_join(other_by_class, nlcd_lut,
                            by = join_by(value))

other_by_class %>% dplyr::slice_head(n = 10)


top3_other_per_macro <- fractions %>%
  dplyr::filter(!value %in% grouped_codes) %>%
  dplyr::group_by(macro_id, value) %>%
  dplyr::summarise(frac = sum(frac, na.rm = TRUE), .groups = "drop") %>%
  dplyr::group_by(macro_id) %>%
  dplyr::slice_max(order_by = frac, n = 3, with_ties = FALSE) %>%
  dplyr::ungroup()

top3_other_per_macro %>% dplyr::arrange(macro_id)


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




