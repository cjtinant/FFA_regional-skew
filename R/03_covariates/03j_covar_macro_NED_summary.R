# ==============================================================================
# Script Name:      03j_covar_macro_slope_stats.R
# Purpose:          Calculate mean and median slope from NED
# Author:           Charles Jason Tinant with ChatGPT 5 thinking
# Date Created:     2025-10-02
# Last Updated:     2025-10-12
#
# Changelog:
#  2025-10-02      Initial script
#  2025-10-03      Fix error in calculating slope stats:
#                    Error in fun(arg_df, ...) : 
#                      argument "cov_frac" is missing, with no default; create
#                  header metadata.
#  2025-10-10      Fixed issue with incorrect project CRS.
#  2025-10-12      Reran with fixed slope raster. Update metadata.
#                  Results look reasonable after making upstream corrections in
#                  the NED preprocessing, clipping, and reprojection pipeline.
#
# Generalized Workflow:
#  1. Load and check rasters and zones.
#  2. Run preflight checks:
#     - Verify that rasters can be opened.
#     - Enforce CRS and polygonal geometry.
#     - Standardize the geometry column as `geom`.
#     - Guarantees unique, non-NA IDs.
#     - Lots of other QA checks that were put in because of prior issues with
#       output.
#  3. Calculate zonal statistics, join macro_id to results.
#  4. QA: NED slope raster (quantiles, summary, histogram)

#
# Inputs (relative to project root):
#   zones:         data/processed/us_ecoregions/macrozones_gp.gpkg
#                    (layer = "macrozones_gp")
#   rasters:      data/processed/ned/ned_gp_5070_90m_slope_deg.tif
#
# Outputs:


# Outputs:   data/qa/ned/slope_quantiles.csv
#            data/qa/ned/slope_summary.csv
#            figs/qa/ned/slope_histogram.png

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





# Notes:     Assumes `slope_5070` and `ned_fixed` exist earlier in the script.
# ==============================================================================




# ==============================================================================
suppressPackageStartupMessages({
  library(exactextractr)
  library(here)
  library(glue)
  library(sf)
  library(terra)
  library(tidyverse)
})

# --- Load custom functions ---
source(file.path(here(), "R", "utils", "spatial", "assert_inputs_ok.R"))
source(file.path(here(), "R", "utils", "spatial", "prep_and_align.R"))
source(file.path(here(), "R", "utils", "spatial", "rast_summ_continuous.R"))

# --- set seed for sampling ---
set.seed(42)

# ------------------------------------------------------------------------------
# 1. Load and check inputs
# ------------------------------------------------------------------------------
# --- rasters ---
rast_path <- here("data", "processed", "ned", "ned_gp_5070_90m_slope_deg.tif")

# --- zones ---
zone_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")
layer_name <- "macrozones_gp"

zones <- st_read(zone_path, layer = layer_name, quiet = TRUE)

# --- QA setup ---
qa_dir     <- here("data", "log")
fig_dir    <- here("output", "qa_checks")
#target_crs <- "EPSG:5070"   # project CRS for rasters in this step

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

# --- QA: ensure raster and zone are prepped and aligned ---

slope_prep <- prep_raster(rast_path, zones, do_crop = TRUE, do_mask = FALSE)
r_slope    <- slope_prep$r
z_slope_sf <- sf::st_as_sf(slope_prep$zones); sf::st_geometry(z_slope_sf) <- "geom"

# --- QA: additional checks ---
terra::summary(r_slope)
terra::minmax(r_slope)
terra::crs(r_slope)
terra::units(r_slope)

# --- Added sanity checks ------------------------------------------------------
# --- Raster: class + single band ---
stopifnot(inherits(r_slope, "SpatRaster"))
stopifnot(terra::nlyr(r_slope) == 1L)

# --- Zones: sf polygons + id present + not all NA ---
stopifnot(inherits(z_slope_sf, "sf"))
geom_type <- unique(sf::st_geometry_type(z_slope_sf, by_geometry = TRUE))
stopifnot(all(geom_type %in% c("POLYGON", "MULTIPOLYGON")))
stopifnot("macro_id" %in% names(z_slope_sf))
stopifnot(!all(is.na(z_slope_sf$macro_id)))

# --- CRS alignment: identical proj4/WKT (exactextractr expects same CRS) ---
r_crs  <- terra::crs(r_slope, proj = TRUE)
z_crs  <- sf::st_crs(z_slope_sf)$wkt
if (!identical(r_crs, z_crs)) {
  # prefer transforming polygons to raster CRS to avoid resampling slope
  z_slope_sf <- sf::st_transform(z_slope_sf, r_crs)
  sf::st_geometry(z_slope_sf) <- "geom"  # keep project convention
}

# --- Valid geometries + not empty ---
stopifnot(all(sf::st_is_valid(z_slope_sf)))
stopifnot(nrow(z_slope_sf) > 0)

# --- duplicates and NA coverage checks ---
stopifnot(!anyDuplicated(z_slope_sf$macro_id))

na_frac <- terra::global(is.na(r_slope), "mean", na.rm = TRUE)[[1]]
message(sprintf("Raster NA fraction: %.3f", na_frac))

# ---  spot-check resolution looks sane --- 
res_xy <- terra::res(r_slope)
message(sprintf("Raster resolution: %g x %g (in raster CRS units)",
                res_xy[1],
                res_xy[2]
                )
)

# --- check cell coverage for each of the five zones ---
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
# 3. Calculate zonal statistics
# ------------------------------------------------------------------------------
# --- area-weighted mean + median using pixel coverage_fraction ---
# --- note: returns a matrix ---
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

# --- turn slope table matrix into a df ---
macro_ids <- z_slope_sf$macro_id

colnames(slope_tbl) <- macro_ids
slope_tbl <- as_tibble(slope_tbl, rownames = "stat")

slope_tbl_tidy <- slope_tbl %>%
  pivot_longer(-stat, names_to = "macro_id", values_to = "value") %>%
  pivot_wider(names_from = stat, values_from = value) %>%
  mutate(macro_id = as.integer(macro_id)) %>%
  mutate(across(where(is.numeric), \(x) round(x, digits = 2)))

# --- join macrozone metadata to slope results ---
slope_tbl_joined <- zones %>%
  left_join(., slope_tbl_tidy,
            by = join_by(macro_id)
            ) %>%
  st_drop_geometry()

# ------------------------------------------------------------------------------
# 4. QA results
# ------------------------------------------------------------------------------
# --- Sanity checks ---
stopifnot(
  inherits(r_slope, "SpatRaster"),
  terra::nlyr(r_slope) == 1
)

if (!grepl("5070|CONUS Albers", terra::crs(r_slope), ignore.case = TRUE)) {
  warning("Slope raster CRS is not EPSG:5070; got: ", terra::crs(r_slope))
}

# --- Quantiles (robust tails) ---
qs <- terra::global(
    x     = r_slope,
    fun   = function(x, na.rm)
      stats::quantile(
        x,
        probs  = c(0, .5, .9, .99, .999, 1),
        na.rm  = na.rm,
        names  = FALSE
      ),
    na.rm = TRUE
  ) %>%
  as_tibble() %>%
  setNames(c("q0", "q50", "q90", "q99", "q999", "q100")) %>%
  mutate(raster = "slope_deg")

readr::write_csv(qs, file = file.path(qa_dir, "slope_quantiles.csv"))

# --- Summary stats ---
n_rows <- terra::nrow(r_slope)
n_cols <- terra::ncol(r_slope)
n_cells <- n_rows * n_cols
n_na <- sum(is.na(terra::values(r_slope)))

rng <- terra::minmax(r_slope, compute = TRUE)

summ <- tibble(
    raster  = "slope_deg",
    n_rows  = n_rows,
    n_cols  = n_cols,
    n_cells = n_cells,
    n_NA    = n_na,
    min     = rng[1, 1],
    max     = rng[2, 1],
    mean    = as.numeric(terra::global(r_slope, "mean", na.rm = TRUE)),
    sd      = as.numeric(terra::global(r_slope, "sd",   na.rm = TRUE)),
    crs     = terra::crs(r_slope)
  )

readr::write_csv(summ, file.path(qa_dir, "slope_summary.csv"))

# --- Console preview ----------------------------------------------------------
message("\nNED Slope QA — quick look:")
print(qs)
print(summ)

# --- Histogram PNG (sample to keep memory reasonable) ---
# sample up to ~1e6 non-NA cells for plotting (fast & representative)
vals <- terra::values(r_slope, mat = FALSE) %>%
  as.vector()

vals <- vals[!is.na(vals)]

n_plot <- min(length(vals), 1e6)
if (length(vals) > n_plot) {
  vals <- sample(vals, n_plot)
}

# --- build a tidy tibble for ggplot ---
df_plot <- tibble(slope_deg = vals)

# --- choose bins adaptively (Freedman–Diaconis) ---
binw <- 2 * IQR(df_plot$slope_deg) / (length(df_plot$slope_deg)^(1/3))
bins <- max(30, min(120, ceiling(
  (max(df_plot$slope_deg) - min(df_plot$slope_deg)) / binw))
)

# --- make a plot ---
p_hist <- ggplot(df_plot, aes(slope_deg)) +
  geom_histogram(bins = bins) +
  geom_vline(xintercept = qs$q99,  linetype = "dashed") +
  geom_vline(xintercept = qs$q999, linetype = "dotted") +
  labs(
    title = "Slope (degrees) — NED-derived, EPSG:5070",
    subtitle = glue("q99 = {round(qs$q99, 2)}°, q99.9 = {round(qs$q999, 2)}°"),
    x = "Slope (degrees)",
    y = "Frequency",
    caption = "Dashed: 99th percentile; Dotted: 99.9th percentile"
  ) +
  theme_minimal(base_size = 12)

p_hist

# --- save plot ---
ggplot2::ggsave(
  filename = file.path(fig_dir, "slope_histogram.png"),
  plot     = p_hist,
  width    = 8,
  height   = 5,
  dpi      = 150
)

# ------------------------------------------------------------------------------
# 5. Output results
# ------------------------------------------------------------------------------
out_path <- here("data", "covars", "macro_slope.csv")
write_csv(slope_tbl_joined, out_path)
