# ==============================================================================
# Script Name:     02g_recrop_ned_make_slope.R
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-10
# Last Updated:    2025-10-10
#
# Change Log:
# - 2025-10-10     Initial script.
#
# Purpose:         Re-crop/mask 3DEP/NED elevation raster to updated outline.
#

#                  EPSG:5070 at 90m, compute slope (degrees), clip/mask, save.
#
# Workflow Summary:
#  1. Get study area outline (EPSG:5070).


# Notes:
#
# ==============================================================================
# --- Load libraries ---
suppressPackageStartupMessages({
  library(here);
  library(sf);
  library(terra);
  library(tidyverse)
})

# ------------------------------------------------------------------------------
# 1. Setup
# ------------------------------------------------------------------------------
# --- inputs ---
dem_path   <- here("data","processed","ned","ned_gp_5070_90m.tif")
outline_gpkg <- here("data","processed","study_area","great_plains_outline.gpkg")
outline_lyr  <- "gp_outline_5070"   # your updated, coastal-plain-dropped outline

r_dem <- terra::rast(dem_path)

gp <- sf::st_read(outline_gpkg, layer = outline_lyr, quiet = TRUE)
sf::st_geometry(gp) <- "geom"
if (sf::st_crs(gp)$wkt != terra::crs(r_dem, proj = TRUE)) {
  gp <- sf::st_transform(gp, terra::crs(r_dem, proj = TRUE))
  sf::st_geometry(gp) <- "geom"
}






r_dem_gp <- r_dem %>%
  terra::crop(gp) %>%
  terra::mask(terra::vect(gp))

# optional: clamp any residual negatives to NA (belt-and-suspenders)
r_dem_gp <- terra::ifel(r_dem_gp < 0, NA, r_dem_gp)

terra::writeRaster(
  r_dem_gp,
  here("data","processed","ned","ned_gp_5070_90m_trimmed.tif"),
  overwrite = TRUE
)

terra::hist(r_dem_gp, main = "Elevation (trimmed study area)")
terra::minmax(r_dem_gp)



# ------------------------------------------------------------------------------
# 8. Check Results
# ------------------------------------------------------------------------------

# --- Optional: read in a prior saved NED raster ---
rast_path <- here("data", "processed", "ned", "ned_gp_5070_90m.tif")

# --- read -> SpatRaster ---
r <- terra::rast(rast_path)

# --- Quick audit ---
stopifnot(inherits(r, "SpatRaster"))
print(r)                  # summary header
terra::minmax(r)          # range per layer
terra::res(r)             # cell size
terra::crs(r)             # CRS (WKT)
terra::ext(r)             # extent
terra::nlyr(r)            # band count
terra::names(r)           # layer names
terra::global(is.na(r), "mean")  # NA fraction

# --- Optional: visualize a small window to confirm values look sane ---
#plot(r, main = "Raster preview (full extent)")  # light, but useful



# ---------- 1) Fast histogram (terra) ----------
# terra::hist(r, main = "Elevation histogram (all cells)", xlab = "Elevation (m)")

# ---------- 2) Tidy histogram (sampled) ----------
set.seed(42)
# sample up to 200k non-NA cells for a smooth ggplot histogram
vals <- terra::spatSample(r, size = 2e5, method = "random", na.rm = TRUE) %>%
  as.data.frame()
names(vals) <- "elev_m"

vals %>%
  ggplot(aes(elev_m)) +
  geom_histogram(bins = 120) +
  labs(
    title = "Elevation histogram (sampled)",
    x = "Elevation (m)", y = "Count"
  )

# zoom near zero to inspect negatives
vals %>%
  filter(elev_m > -300, elev_m < 300) %>%
  ggplot(aes(elev_m)) +
  geom_histogram(bins = 120) +
  labs(
    title = "Elevation near sea level (−300 to 300 m)",
    x = "Elevation (m)", y = "Count"
  )

# ---------- 3) How many negatives? ----------
neg_stats <- terra::global(r < 0, "sum", na.rm = TRUE)  # count of <0 cells
tot_cells <- prod(terra::ncol(r), terra::nrow(r)) - terra::global(is.na(r), "sum", na.rm = TRUE)[[1]]

neg_n   <- neg_stats[[1]]
neg_pct <- 100 * neg_n / tot_cells

cat(sprintf("Cells < 0 m: %s (%.4f%% of non-NA cells)\n", format(neg_n, big.mark=","), neg_pct))

# also show min & a few quantiles to sanity-check the tail
print(terra::global(r, fun = quantile, probs = c(0, 0.001, 0.01, 0.1, 0.5), na.rm = TRUE))

# ---------- 4) Where are negative cells? ----------
r_neg <- r < 0
plot(r_neg, main = "Locations of negative elevation (< 0 m)")






# ------------------------------------------------------------------------------
# 8. Make slope raster
# ------------------------------------------------------------------------------
message("Computing rook-case slope in degrees…")
slope_5070 <- terra::terrain(
  elev_5070,
  v = "slope",
  neighbors = 4,
  unit = "degrees"
)


r_slope_deg <- terra::terrain(r_dem_gp, v = "slope", unit = "degrees", neighbors = 8)




terra::writeRaster(
  r_slope_deg,
  here("data","processed","ned","slope_gp_5070_90m.tif"),
  overwrite = TRUE
)
