# ==============================================================================
# Script Name:      03g_covar_macro_phzm_summary.R
# Purpose:          Calculate dominant and count of phzm climate zones at the
#                   macrozone scale
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-09-01
# Last Updated:     2025-09-24
#
# Changelog:
# - 2025-09-01     Initialize script
# - 2025-09-02     Add zonal summaries (KG, PHZM, NLCD, slope, gage elev);
#                  write CSV/GPKG.
# - 2025-09-03     Wire in assert_inputs_ok(); lazy-load rasters; minor hardening;
#                  Add first attempt at uniform code to prep and align, summarise,
#                  and add metadata to result.
# - 2025-09-15     Split original script into parts; add qa check.
# - 2025-09-15     Drop original QA check, add summary and visual QA as a
#                  sanity check.
# - 2025-09-18     Continue QA check; output results; update header metadata.
# - 2025-09-24     Add QA safety check for CRS.
#
# Generalized Workflow:
# Steps 1-3 check `03f_covar_macro_koppen_summary.R`` for details.
# Step 4. Run a Quality Assurance (QA) as a sanity check of results
# Step 5. Output the results and the QA plots.
#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg
#                    (layer = "macrozones_gp")
#   rasters:      data/processed/phzm/phzm.tif
#
# Outputs:
#                  data/covars/macro_phzm.csv
#                  output/qa_checks/macro_phzm_vs_area_qa.png
#                  output/qa_checks/macro_phzm_vs_lat_qa.png
#
# Conventions: EPSG:4269, 'geom' active geometry, join key = macro_id
#
# Dependencies: here, sf, terra, tidyverse, exactextractr
#
# Related Files:
#   - 03f_covar_macro_koppen_summary.R
#
# - Documentation files to check/update
#   - notes/script-notes_and_developer-log.pdf
#   - data/log_README.pdf
#   - R/log_README.pdf
#   - R/README.pdf
#   - CHANGELOG.md
#   - milestone_03_prepare_covariates.pdf
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
#source(file.path(here(), "R", "utils", "qa", "phzm_eval_quality.R"))

# ------------------------------------------------------------------------------
# 1. Load inputs
# ------------------------------------------------------------------------------
# --- rasters ---
phzm_path <- here("data", "processed", "phzm", "phzm.tif")

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- st_read(zone_path, layer = layer_name, quiet = TRUE)

# ------------------------------------------------------------------------------
# 2. Run a Preflight Check -- using assert_inputs_ok()
# ------------------------------------------------------------------------------
raster_paths <- c(phzm  = phzm_path)

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
# 3. Summarise PHZM by dominant class and count
# ------------------------------------------------------------------------------
phzm_prep <- prep_raster(phzm_path, zones, do_crop = TRUE, do_mask = FALSE)
r_phzm    <- phzm_prep$r
z_phzm_sf <- sf::st_as_sf(phzm_prep$zones); sf::st_geometry(z_phzm_sf) <- "geom"

phzm_tbl <- phzm_summary(r_phzm, z_phzm_sf,
                         id_col = "macro_id",
                         min_prop = 0.05,
                         force_recode = TRUE,
                         return_halfzones = TRUE,
                         label_cols = TRUE,
                         label_style = "short",
                         drop_minor = TRUE,
                         drop_thresh = 0.05
                         ) %>%
  mutate(
    across(
      c(phzm_dom_frac, phzm_top1_prop, phzm_top2_prop, phzm_top3_prop),
      ~ round(.x, digits = 3)
    )
  ) %>%
  relocate(phzm_top2, .after = phzm_top1) %>%
  relocate(phzm_top3, .after = phzm_top2) %>%
  mutate(phzm_prop_sum = phzm_top1_prop + phzm_top2_prop + phzm_top3_prop)

phzm_tbl <- left_join(zones, phzm_tbl,
                      join_by(macro_id
                              )) %>%
  relocate(phzm_dominant, .after = phzm_top3_label) %>%
  relocate(phzm_dom_frac, .after = phzm_dominant) %>%
  relocate(phzm_prop_sum, .after = n_gages)

# --- check crs one more time ---
qa_crs_r <- crs(r_phzm)
qa_crs_z <- crs(z_phzm_sf)

# ------------------------------------------------------------------------------
# 4. Make a visual QA check on PHZM by dominant class and count results
# ------------------------------------------------------------------------------
# ---- Calculate centroids to get latitude ----
regions <- phzm_tbl %>% group_by(region_name) %>%
  mutate(
    centroid   = st_centroid(geom),
    lat_center = st_coordinates(centroid)[, "Y"],
    lon_center = st_coordinates(centroid)[, "X"]
  )

qa_lat <- regions %>%
  ggplot(aes(x = lat_center,
             y = phzm_class_count
             )) +
  geom_point(
    aes(size = area_km2,
        color = macrozone),
    alpha = 0.7) +
  geom_smooth(
    method = "lm",
    se = FALSE,
    linetype = "dashed",
    color = "black"
    ) +
  geom_text(
    aes(label = region_name),
    vjust = -0.7,
    size = 3
    ) +
  scale_size_continuous(name = "Area (km²)") +
  labs(
    x = "Region centroid latitude (°N)",
    y = "PHZM class count",
    title = "Variation in PHZM class count vs latitude"
  ) +
  theme_minimal()

print(qa_lat)

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "macro_phzm_vs_lat_qa.png")
ggsave(out_path_qa_lat,
       bg = "white")

# ---- Plot: class count vs area ----
# Interpretation: Area drives a baseline trend, but latitude explains the
# deviations around that trend.
# The regression line (dashed) shows a clear positive relationship:
# bigger regions have more PHZM classes.
# But the scatter tells the nuance:
# Tallgrass Prairie lies above the line, meaning more classes than expected for
#   its size (its latitudinal span is helping).
# Northern Mixed Grass Prairie lies below the line, meaning fewer classes than
#   expected given its area (its latitude range is narrower).
# Southern Mixed Grass Prairie is both small and low-lat, meaning few classes,
#   right where you’d expect.

qa_area <- regions %>%
  ggplot(aes(x = area_km2/1000,
             y = phzm_class_count
             )) +
  geom_point(
    aes(color = macrozone),
    alpha = 0.7,
    size = 3) +
  geom_text(
    aes(label = region_name),
    vjust = -0.7,
    size = 3
  ) +
  geom_smooth(
    method = "lm",
    se = FALSE,
    linetype = "dashed",
    color = "black"
    ) +
  labs(
    x = "Region area (×1,000 km²)",
    y = "PHZM class count",
    title = "Variation in PHZM class count vs area"
  ) +
  theme_minimal()

print(qa_area)

# --- save plot ---
out_path_qa_area <- here("output", "qa_checks", "macro_phzm_vs_area_qa.png")
ggsave(out_path_qa_area,
       bg = "white")

# ------------------------------------------------------------------------------
# 5. Output results
# ------------------------------------------------------------------------------
out_path_covars <- here("data", "covars", "macro_phzm.csv")
write_csv(phzm_tbl, out_path_covars)
