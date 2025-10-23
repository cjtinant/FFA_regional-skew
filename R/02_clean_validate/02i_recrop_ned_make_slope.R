# ==============================================================================
# Script Name:     02f_recrop_ned_make_slope.R
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-10
# Last Updated:    2025-10-12
# Change Log:
#  2025-10-10      Initial script.
#  2025-10-11      Bug fixes.
#  2025-10-12      Header metadata creation.

# Purpose:         Re-crop/mask 3DEP/NED elevation raster to updated outline.

#
# Workflow Summary:
#  1. Load GP outline and NED raster. Make QA checks on CRS and layers
#  2. Mask and crop NED raster.
#  3. Make slope raster
#  4. Export results.
#
# Inputs:          data/processed/study_area/gp_outline_5070.gpkg
#                    layers = gp_outline, gp_outline_simple)
# Outputs:         data/processed/study_area/great_plains_outline.gpkg
#
# Notes: Info on masking and cropping rasters here:
# https://datacarpentry.github.io/semester-biology/materials/spatial-data-cropping-R/
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
# --- path ---
ned_path   <- here("data","processed","ned","ned_gp_5070_90m.tif")
outline_gpkg <- here("data","processed","study_area","gp_outline_5070.gpkg")
st_layers(outline_gpkg)

outline_lyr    <- "gp_outline"
simple_outline <- "gp_outline_simple"

# --- get vector files ---
gp_outline_5070 <- sf::st_read(outline_gpkg,
                               layer = outline_lyr,
                               quiet = TRUE
)

gp_simple_5070 <- sf::st_read(outline_gpkg,
                               layer = simple_outline,
                               quiet = TRUE
)

# --- get raster files ---
ned_5070 <- terra::rast(ned_path)

# make comparable sf::crs objects
crs_r <- sf::st_crs(terra::crs(ned_5070, proj = TRUE))
crs_v <- sf::st_crs(gp_outline_5070)

# robust equality check
crs_v == crs_r        # TRUE means same CRS definition
crs_v$epsg            # should be 5070 (may be NA and still equal by WKT)

# --- make bounding box ---
gp_bbox_5070 <- gp_outline_5070 %>%
  sf::st_buffer(50e3) %>%       # 50 km
  sf::st_bbox() %>%
  sf::st_as_sfc(crs = 5070) %>%
  sf::st_sf()
sf::st_geometry(gp_bbox_5070) <- "geom"

# --- Visual QA check ---
states_5070 <- maps::map("state", plot = FALSE, fill = TRUE) %>%
  sf::st_as_sf() %>%
  sf::st_transform(5070)
sf::st_geometry(states_5070) <- "geom"

ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = gp_bbox_5070,
          aes(geometry = geom),
          fill = "red",
          color = "red",
          alpha = 0.5,
          linewidth = 0.2) +
  geom_sf(data = gp_simple_5070,
          aes(geometry = geom),
          alpha = 0.5,
          fill = "blue",
          color = "grey35",
          linewidth = 0.2) +
  geom_sf(data = gp_outline_5070,
          aes(geometry = geom),
          alpha = 0.5,
          fill = "gray70",
          color = "grey35",
          linewidth = 0.2) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "GP Merged Outline and Simplified Outline"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(), axis.title = element_blank())

# ------------------------------------------------------------------------------
# 2. Mask and crop NED elevation raster
# ------------------------------------------------------------------------------
# --- mask and crop raster ---
ned_5070_gp <- ned_5070 %>%
  terra::crop(gp_bbox_5070) %>%
  terra::mask(terra::vect(gp_bbox_5070))

# --- clamp any residual negatives to NA (belt-and-suspenders) ---
ned_5070_gp <- terra::ifel(ned_5070_gp < 0, NA, ned_5070_gp)

# --- Quick audit ---
terra::minmax(ned_5070_gp)          # range per layer
terra::res(ned_5070_gp)             # cell size
terra::crs(ned_5070_gp)             # CRS (WKT)
terra::ext(ned_5070_gp)             # extent
terra::nlyr(ned_5070_gp)            # band count
terra::global(is.na(ned_5070_gp), "mean")  # NA fraction

# --- Quick histogram ---
terra::hist(ned_5070_gp, main = "Elevation (trimmed study area)")

# --- show min & a few quantiles to sanity-check the tail ---
print(terra::global(ned_5070_gp,
                    fun = quantile,
                    probs = c(0, 0.001, 0.01, 0.1, 0.5),
                    na.rm = TRUE))

# unsure here of what happened here...
ned_fixed <- ned_5070_gp
# --- fix issue with writing raster --
# ned_fixed <- writeRaster(
#   ned_5070_gp,
#   here::here("data/processed/ned","ned_gp_5070_90m_fixed.tif"),
#   gdal = c("TILED=YES","COMPRESS=LZW","BIGTIFF=YES"),
#   overwrite = TRUE
# )

# --- check results ---
ncol(ned_fixed); nrow(ned_fixed); res(ned_fixed); ext(ned_fixed)
terra::hasRotate(ned_fixed)       # should be FALSE
sources(ned_fixed)                # where/how it’s stored

# ------------------------------------------------------------------------------
# 3. Make slope raster
# ------------------------------------------------------------------------------
# --- clip to AOI (faster & avoids reading unneeded tiles) ---
ned_clip <- ned_fixed %>%
  crop(gp_outline_5070) %>%
  mask(gp_outline_5070)

# --- make slope raster ---
slope_5070 <- terra::terrain(
  ned_clip,
  v = "slope",
  neighbors = 4,       # Rook’s case
  unit = "degrees"
)

# --- Sanity Check: Geometry/alignment sanity ---
stopifnot(terra::compareGeom(ned_clip, slope_5070, stopOnError = FALSE))
print(slope_5070)        # dims, res, crs
print(ext(slope_5070))   # extent

# --- Sanity Check: Basic stats + distribution ---
terra::minmax(slope_5070)
terra::global(slope_5070, c("min","max","mean","sd"), na.rm = TRUE)

qs <- terra::global(
  slope_5070,
  fun   = function(x, na.rm) stats::quantile(
    x, probs = c(0, .5, .9, .99, .999, 1), na.rm = na.rm),
  na.rm = TRUE
)

print(qs)

# ------------------------------------------------------------------------------
# 4. Export results
# ------------------------------------------------------------------------------
# --- final write ---
writeRaster(
  slope_5070,
  here("data/processed/ned","ned_gp_5070_90m_slope_deg.tif"),
  gdal = c("TILED=YES","COMPRESS=LZW","BIGTIFF=YES"),
  overwrite = TRUE
)

writeRaster(
  ned_fixed,
  here("data/processed/ned","ned_gp_5070_90m_fixed.tif"),
  gdal = c("TILED=YES","COMPRESS=LZW","BIGTIFF=YES"),
  overwrite = TRUE
)
