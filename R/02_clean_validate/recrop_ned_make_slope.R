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
ned_path   <- here("data","processed","ned","ned_gp_5070_90m.tif")
outline_gpkg <- here("data","processed","study_area","great_plains_outline.gpkg")
outline_lyr  <- "gp_outline_5070"   # your updated, coastal-plain-dropped outline

ecoreg_gpkg <- here("data","processed","study_area","gp_ecoreg_5070.gpkg")
eco_lyr  <- "gp_l2_ecoreg"   # your updated, coastal-plain-dropped outline

# --- outputs ---
meta_path <- here("docs", "metadata", "QAQC", "2025-10-11_extent-5070.pdf")

# --- get raster and vector files ---
ned_5070 <- terra::rast(ned_path)

gp_outline_5070 <- sf::st_read(outline_gpkg,
                               layer = outline_lyr,
                               quiet = TRUE
)

gp_l2_5070 <- sf::st_read(ecoreg_gpkg,
                               layer = eco_lyr,
                               quiet = TRUE
)

# make comparable sf::crs objects
crs_r <- sf::st_crs(terra::crs(ned_5070, proj = TRUE))
crs_v <- sf::st_crs(gp_outline_5070)

# robust equality check
crs_v == crs_r        # TRUE means same CRS definition
crs_v$epsg            # should be 5070 (may be NA and still equal by WKT)



# # downsample/crop helps speed and avoids Viewer issues
# ned_clip  <- terra::mask(terra::crop(ned_5070, gp_outline_5070), gp_outline_5070)
# ned_df    <- as.data.frame(ned_clip, xy = TRUE, na.rm = TRUE) %>%
#   dplyr::rename(elev_m = tidyselect::last_col())
# 
# p_extent <- ggplot() +
#   geom_raster(data = ned_df, aes(x = x, y = y, fill = elev_m)) +
#   geom_sf(data = gp_outline_5070, fill = NA, color = "red", size = 0.4) +
#   coord_sf(crs = crs_r) +   # stay in EPSG:5070
#   theme_minimal() +
#   labs(title = "Extent and Alignment Check",
#        fill = "Elevation (m)"
# )
# 
# ggsave(meta_path,
#        p_extent,
#        device = "pdf",
#        width = 9,
#        height = 7,
#        units = "in",
#        bg = "white",
#        dpi = 300)

# ------------------------------------------------------------------------------
# 2. Mask and Crop Raster
# ------------------------------------------------------------------------------
# --- make bounding box ---
gp_bbox_5070 <- gp_outline_5070 %>%
  sf::st_buffer(50e3) %>%       # 50 km
  sf::st_bbox() %>%
  sf::st_as_sfc(crs = 5070) %>% # correct CRS here
  sf::st_sf()

# --- mask and crop raster ---
ned_5070_gp <- ned_5070 %>%
  terra::crop(gp_bbox_5070) %>%
  terra::mask(terra::vect(gp_bbox_5070))

# --- clamp any residual negatives to NA (belt-and-suspenders) ---
ned_5070_gp <- terra::ifel(ned_5070_gp < 0, NA, ned_5070_gp)

# ------------------------------------------------------------------------------
# 3. Check Results
# ------------------------------------------------------------------------------
# --- Quick audit ---
# print(ned_5070_gp)                  # summary header
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








# ---------- 4) Where are negative cells? ----------
#r_neg <- r < 0
plot(ned_5070_gp, main = "Locations of negative elevation (< 0 m)")



terra::writeRaster(
  ned_5070_gp,
  here("data","processed","ned","ned_gp_5070_90m_trimmed.tif"),
  overwrite = TRUE
)


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


r_slope_deg <- terra::terrain(ned_5070_gp, v = "slope", unit = "degrees", neighbors = 8)




terra::writeRaster(
  r_slope_deg,
  here("data","processed","ned","slope_gp_5070_90m.tif"),
  overwrite = TRUE
)
