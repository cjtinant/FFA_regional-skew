# ==============================================================================
# Script Name:     01n_download_ned.R
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-06-25
# Last Updated:    2025-10-08
#
# Change Log:
# - 2025-07-24     Update header information; 
#                  move notes to `script-notes_and_developer-log`.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}; Updated header metadata.
# - 2025-10-08     Refactored entire script to identify issue with raster
#                  resolution.
#
# Purpose:         Download 3DEP/NED elevation for the Great Plains, project to
#                  EPSG:5070 at 90m, compute slope (degrees), clip/mask, save.
#
# Workflow Summary:
#  1. Get study area outline (EPSG:5070).
#  2. Prepare to download 3DEP/NED elevation raster:
#       - Make bounding box (bbox) in WGS 84 GCS (EPSG:4326) with 50km buffer;
#       - Tile bbox (6 x 6 by default) and prep temp files for download.
#  3. Download tiles (see Notes).
#  4. Check download results by inspecting differences in the downloaded tiles.
#  5. Build a template of what the resulting mosiac should look like.
#  6. Project the tiles onto the template grid.
#  7. Mosiac the projected tiles together.
#  8. Make a slope raster.
#  9. Write results.

# Notes:
# - Tiles fetched at z=10 (~100–115 m/px at GP latitudes); warped tiles
#    oversample to ~60–72 m/px; final template = 90 m in EPSG:5070.

# ==============================================================================
# --- Load libraries ---
suppressPackageStartupMessages({
  library(elevatr)
  library(fs)
  library(here)
  library(maps)       # avoids heavier basemap deps
  library(sf)
  library(terra)
  library(tidyverse)
})

# --- set memory limits for download ---
terra::terraOptions(memfrac = 0.7)

# --- make helper: fetch one tile with retries ---
fetch_tile <- function(tile_sf, z = 10, tries = 3, sleep_base = 2) {
  for (k in seq_len(tries)) {
    msg <- sprintf(
      "Fetching tile %s (attempt %d/%d)...", tile_sf$tile_id, k, tries)
    message(msg)
    out <- try(
      elevatr::get_elev_raster(
        locations           = tile_sf,   # EPSG:4326 polygon
        z                   = z,
        clip                = "locations",
        expand              = 0,         # degrees! keep 0 (we already buffered)
        override_size_check = TRUE
      ),
      silent = TRUE
    )
    if (!inherits(out, "try-error")) {
      return(terra::rast(out))
    }
    # polite backoff
    Sys.sleep(sleep_base * k)
  }
  return(NULL)
}

# ------------------------------------------------------------------------------
# 1. Setup
# ------------------------------------------------------------------------------
# --- inputs ---
gpkg_file  <- file.path(
  here(), "data", "processed", "study_area", "great_plains_outline.gpkg")

eco_layer  <- "gp_outline_5070"

out_dir    <- file.path(here(), "data", "processed", "ned")

tmp_tiles  <- file.path(here(), "tmp", "ned_tiles")

# --- make directories if they don't exist (safe if they do exist) ---
fs::dir_create(out_dir)
fs::dir_create(tmp_tiles)

# --- read in the study area outline ---
gp_sf <- st_read(gpkg_file, layer = eco_layer, quiet = TRUE) 

# --- quick CRS check ---
message("gp_sf CRS: ", sf::st_crs(gp_sf)$input %||% sf::st_crs(gp_sf)$wkt)
message("gp_sf EPSG: ",sf::st_crs(gp_sf)$epsg)

# ------------------------------------------------------------------------------
# 2. Prepare to download raster tiles
# ------------------------------------------------------------------------------
# --- make bounding box ---
gp_bbox_4326 <- gp_sf %>%
  sf::st_buffer(50e3) %>%       # 50 km
  sf::st_bbox() %>%
  sf::st_as_sfc(crs = 5070) %>% # correct CRS here
  sf::st_transform(4326) %>%
  sf::st_sf()
sf::st_geometry(gp_bbox_4326) <- "geom"
stopifnot(sf::st_crs(gp_bbox_4326)$epsg == 4326)

# --- quick CRS check ---
message("gp_bbox_4326 CRS: ",
        sf::st_crs(gp_bbox_4326)$input %||% sf::st_crs(gp_bbox_4326)$wkt)
message("gp_bbox_4326 EPSG: ",
        sf::st_crs(gp_bbox_4326)$epsg)


# --- tile the bbox (6 x 6 by default; adjust as needed) ---
nx <- 6L
ny <- 6L

tile_grid <- sf::st_make_grid(
    gp_bbox_4326,
    n   = c(nx, ny),
    what = "polygons"
  ) %>%
  sf::st_as_sf() %>%
  dplyr::mutate(tile_id = dplyr::row_number())
sf::st_geometry(tile_grid) <- "geom"

# --- Keep only tiles that intersect the bbox (all do) and name files ---
tile_grid <- tile_grid %>%
  mutate(tile_path = file.path(tmp_tiles, sprintf("tile_%03d.tif", tile_id)))

# ------------------------------------------------------------------------------
# 3. Download tiles with retries
# ------------------------------------------------------------------------------
downloaded <- purrr::pmap_lgl(
    .l = list(tile_sf = split(tile_grid, seq_len(nrow(tile_grid)))),
    .f = function(tile_sf) {
      r <- fetch_tile(
        tile_sf = tile_sf, z = 10, tries = 3, sleep_base = 2)
      
      if (is.null(r)) return(FALSE)
      terra::writeRaster(
        r,
        filename  = tile_sf$tile_path,
        overwrite = TRUE
      )
      TRUE
    }
  )

if (!all(downloaded)) {
  failed <- which(!downloaded)
  warning(length(failed), " tiles failed: ", paste(failed, collapse = ", "))
}

# --- write names of the downloaded tiles ---
tile_files <- tile_grid$tile_path[fs::file_exists(tile_grid$tile_path)]
stopifnot(length(tile_files) > 0)

# ------------------------------------------------------------------------------
# 4. Check download results: Inspect degree-grid differences
# ------------------------------------------------------------------------------
# --- make the tile files into spat rasters ---
r_list <- lapply(tile_files, terra::rast)

# --- Tile resolution diagnostics (pre-reprojection) ---
# inputs: tile_files, r_list (as built earlier), z (e.g., 10)
z <- 10

wm_res_m <- function(z, lat_deg) {
  156543.033928041 * cos(pi * lat_deg / 180) / (2^z)
}

diag_tbl <- tibble::tibble(
    file      = tile_files,
    res_x_deg = purrr::map_dbl(r_list, ~ terra::res(.x)[1]),
    res_y_deg = purrr::map_dbl(r_list, ~ terra::res(.x)[2]),
    origin_x  = purrr::map_dbl(r_list, ~ terra::origin(.x)[1]),
    origin_y  = purrr::map_dbl(r_list, ~ terra::origin(.x)[2]),
    crs_wkt   = purrr::map_chr(r_list, ~ terra::crs(.x, proj = TRUE))
  ) %>%
  dplyr::mutate(
    # tile centroid latitude (degrees)
    lat_ctr = purrr::map_dbl(file, ~ {
      r <- terra::rast(.x)
      e <- terra::ext(r)
      (terra::ymin(e) + terra::ymax(e)) / 2
    }),
    # degrees -> meters
    m_per_deg_lat = 111132,                         # J. Snyder approx.
    m_per_deg_lon = 111320 * cos(pi * lat_ctr / 180),
    res_y_m_obs   = res_y_deg * m_per_deg_lat,
    res_x_m_obs   = res_x_deg * m_per_deg_lon,
    # nominal Web-Mercator ground resolution at this latitude and zoom
    res_m_nom_z   = wm_res_m(z, lat_ctr),
    # how the EPSG:4326 warp compares to nominal (Y direction is stable)
    oversample_y  = res_y_m_obs / res_m_nom_z
  )

# --- make a quick summary for README notes ---
diag_summary <- diag_tbl %>%
  summarise(
    # latitude
    lat_min   = min(lat_ctr), lat_med = median(lat_ctr), lat_max = max(lat_ctr),
    # cell-size in y
    obs_y_min = min(res_y_m_obs), obs_y_med = median(res_y_m_obs),
    obs_y_max = max(res_y_m_obs),
    # cell-size in x
    obs_x_min = min(res_x_m_obs), obs_x_med = median(res_x_m_obs),
    obs_x_max = max(res_x_m_obs),
    nom_min   = min(res_m_nom_z), nom_med = median(res_m_nom_z), 
    nom_max = max(res_m_nom_z),
    over_min  = min(oversample_y), over_med = median(oversample_y),
    over_max = max(oversample_y)
  ) %>%
  # mutate(across(where(is.numeric),round, 2)) # this is the old approach
  #   new approach uses the anonymous function \(x)
  mutate(across(where(is.numeric), \(x) round(x, digits = 2)))

# ------------------------------------------------------------------------------
# 5. Build metric template in EPSG:5070, fixed cell size
# ------------------------------------------------------------------------------
target_crs <- "EPSG:5070"  # NAD83 / Conus Albers (project default family)
cell_m     <- 90           # 90 m is a better fit for the nominal 

# --- union extent in target CRS ---
proj_exts <- purrr::map(r_list, ~ terra::ext(terra::project(.x, target_crs)))
ext_mat   <- do.call(
  rbind,
  purrr::map(proj_exts, ~ c(terra::xmin(.x), terra::xmax(.x),
                            terra::ymin(.x), terra::ymax(.x)))
)
union_ext <- terra::ext(min(ext_mat[,1]), max(ext_mat[,2]),
                        min(ext_mat[,3]), max(ext_mat[,4]))

template <- terra::rast(
  union_ext,
  crs        = target_crs,
  resolution = cell_m
)

# --- make clean origin on a neat grid ---
snap_extent_to_res <- function(ext, res) {
  xmin <- floor(terra::xmin(ext) / res) * res
  ymin <- floor(terra::ymin(ext) / res) * res
  xmax <- ceiling(terra::xmax(ext) / res) * res
  ymax <- ceiling(terra::ymax(ext) / res) * res
  terra::ext(xmin, xmax, ymin, ymax)
}

union_ext_snapped <- snap_extent_to_res(union_ext, cell_m)

# --- snap to grid ---
template <- terra::rast(
  union_ext_snapped,
  crs        = target_crs,
  resolution = cell_m
)

# ------------------------------------------------------------------------------
# 6. Project each tile to template grid
# ------------------------------------------------------------------------------
# --- Elevation is continuous → bilinear resampling ---
tiles_aligned <- purrr::map(
  r_list,
  ~ terra::project(.x, template, method = "bilinear")
)

# --- sanity check: all comparable to template? ---
stopifnot(all(purrr::map_lgl(
  tiles_aligned, ~ terra::compareGeom(.x, template, stopOnError = FALSE)
)))

# ------------------------------------------------------------------------------
# 7. Mosaic on aligned grid
# ------------------------------------------------------------------------------
elev_5070 <- do.call(terra::mosaic, c(tiles_aligned, list(fun = "mean")))

# --- Optional: clip mosaic to original outline (+ buffer) in 5070 ---
gp_5070 <- sf::st_transform(gp_sf, 5070) %>% sf::st_buffer(50e3)
elev_5070 <- terra::mask(elev_5070, terra::vect(gp_5070))

# --- Post-check (should be one unique combo now) ---
post_diag <- tibble::tibble(
  res_x    = terra::res(elev_5070)[1],
  res_y    = terra::res(elev_5070)[2],
  origin_x = terra::origin(elev_5070)[1],
  origin_y = terra::origin(elev_5070)[2],
  crs_wkt  = terra::crs(elev_5070, proj = TRUE)
)
print(post_diag)

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



# ------------------------------------------------------------------------------
# 9. Write results
# -------------------------------------------------------------------------------
# --- make file paths ---
out_elev_5070 <- file.path(out_dir, "ned_gp_5070_90m.tif")
out_slope_5070 <- file.path(out_dir, "slope_gp_5070_90m.tif")

out_meta <- file.path(
  here("data",
       "meta",
       paste0(format(Sys.Date(), "%Y-%m-%d"),
              "_ned_tiles_resolution_z", z, ".csv"
              )
       )
)

out_meta_summ <- file.path(
  here("docs",
       "metadata",
       "raster-data-summaries",
              "ned_tiles_diagnostics.csv"
       )
)

# --- write raster results ---
terra::writeRaster(elev_5070, out_elev_5070, overwrite = TRUE)
terra::writeRaster(elev_5070, out_slope_5070, overwrite = TRUE)

# --- write orig metadata and metadata summary for provenance ---
readr::write_csv(diag_tbl, out_meta)
readr::write_csv(diag_summary, out_meta_summ)

