# ==============================================================================
# Script Name:     01n_download_ned.R
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-06-25
# Last Updated:    2025-10-04
#
# Change Log:
# - 2025-07-24     Update header information; 
#                  move notes to `script-notes_and_developer-log`.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}; Updated header metadata.
# - 2025-10-07     Refactored entire script to identify issue with raster
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
#     See

# NEXT STEPS: write 'diag_summary.csv'

# --- make a quick summary for README notes ---
diag_summary <- diag_tbl %>%
  summarise(
    lat_min   = min(lat_ctr), lat_med = median(lat_ctr), lat_max = max(lat_ctr),
    obs_y_min = min(res_y_m_obs), obs_y_med = median(res_y_m_obs),
    obs_y_max = max(res_y_m_obs),
    nom_min   = min(res_m_nom_z), nom_med = median(res_m_nom_z), 
    nom_max = max(res_m_nom_z),
    over_min  = min(oversample_y), over_med = median(oversample_y),
    over_max = max(oversample_y)
  )


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
    lat_min   = min(lat_ctr), lat_med = median(lat_ctr), lat_max = max(lat_ctr),
    obs_y_min = min(res_y_m_obs), obs_y_med = median(res_y_m_obs),
    obs_y_max = max(res_y_m_obs),
    nom_min   = min(res_m_nom_z), nom_med = median(res_m_nom_z), 
    nom_max = max(res_m_nom_z),
    over_min  = min(oversample_y), over_med = median(oversample_y),
    over_max = max(oversample_y)
  )

# ------------------------------------------------------------------------------
# 5. Build metric template in EPSG:5070, fixed cell size
# ------------------------------------------------------------------------------
target_crs <- "EPSG:5070"  # NAD83 / Conus Albers (project default family)
cell_m     <- 90           # choose 30/60/90; 90 m keeps files lean

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

# if you also want geographic NAD83 (EPSG:4269) for later steps:
# elev_4269 <- terra::project(elev_5070, "EPSG:4269", method = "bilinear")
# out_4269  <- file.path(out_dir, "ned_gp_4269_~90m.tif")
# terra::writeRaster(elev_4269, out_4269, overwrite = TRUE)

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

# --- write raster results ---
terra::writeRaster(elev_5070, out_elev_5070, overwrite = TRUE)
terra::writeRaster(elev_5070, out_slope_5070, overwrite = TRUE)


# --- write orig metadata for provenance ---
readr::write_csv(diag_tbl, out_meta)





# # write metadata for provenance
# meta_dir <- here::here("data", "meta")
# fs::dir_create(meta_dir)
# 

# 
# readr::write_csv(diag_tbl, outfile)
# message("Wrote tile resolution metadata: ", outfile)

# --- 9) Post-check (should be one unique combo now) ---------------------------
post_diag <- tibble::tibble(
    res_x    = terra::res(elev_5070)[1],
    res_y    = terra::res(elev_5070)[2],
    origin_x = terra::origin(elev_5070)[1],
    origin_y = terra::origin(elev_5070)[2],
    crs_wkt  = terra::crs(elev_5070, proj = TRUE)
  )
print(post_diag)






# OLD STARTS HERE



# ------------------------------------------------------------------------------
# 3. Download elevation (elevatr) clipped to bbox
# ------------------------------------------------------------------------------
# --- iterate rows, not columns ---
rows_sf <- split(tile_grid, seq_len(nrow(tile_grid)))  # list of 1-row sf objects

# --- go and get um!!! ---
downloaded <- purrr::pmap_lgl(
  .l = list(
    tile_sf = rows_sf,
    outpath = tile_grid$tile_path,
    tid     = tile_grid$tile_id
  ),
  .f = function(tile_sf, outpath, tid) {
    if (fs::file_exists(outpath)) return(TRUE)   # resume-friendly
    
    r <- fetch_tile(tile_sf)
    if (is.null(r)) {
      message(sprintf("Tile %03d FAILED.", tid))
      return(FALSE)
    }
    
    terra::writeRaster(
      r, filename = outpath, overwrite = TRUE,
      gdal = c("COMPRESS=LZW","TILED=YES","BIGTIFF=YES","BLOCKXSIZE=512","BLOCKYSIZE=512")
    )
    TRUE
  }
)

# -- mesg ---
if (!all(downloaded)) {
  failed <- which(!downloaded)
  warning(length(failed), " tiles failed: ", paste(failed, collapse = ", "))
  # You can re-run to retry failures; continuing with the rest will still work.
}

# ------------------------------------------------------------------------------
# 4. Check results
# ------------------------------------------------------------------------------
# --- Inspect tile geometry ---
r_list <- lapply(tile_files, terra::rast)

tile_diag <- tibble(
    file      = tile_files,
    res_x     = purrr::map_dbl(r_list, ~ terra::res(.x)[1]),
    res_y     = purrr::map_dbl(r_list, ~ terra::res(.x)[2]),
    origin_x  = purrr::map_dbl(r_list, ~ terra::origin(.x)[1]),
    origin_y  = purrr::map_dbl(r_list, ~ terra::origin(.x)[2]),
    crs_wkt   = purrr::map_chr(r_list, ~ terra::crs(.x, proj = TRUE))
  )

# --- Quick glance at unique combos (resolution + origin + CRS) ---
tile_diag %>%
  dplyr::distinct(res_x, res_y, origin_x, origin_y, crs_wkt) %>%
  print(n = Inf)

# Optional: see counts by resolution ---
tile_diag %>%
  dplyr::count(res_x, res_y, sort = TRUE) %>%
  print(n = Inf)





# --- Choose a common template -------------------------------------------------
# Pick the modal (most frequent) resolution to avoid over/undersampling extremes
modal_res <- tile_diag %>%
  dplyr::count(res_x, res_y, sort = TRUE) %>%
  dplyr::slice(1) %>%
  dplyr::select(res_x, res_y) %>%
  as.list()

# Use the first tile with the modal resolution/origin as the template if available,
# otherwise just use the first tile and force the desired resolution.
template <- r_list[[1]] %>%
  terra::project("EPSG:4326") %>%                     # ensure common CRS
  { terra::rast(terra::ext(.), crs = terra::crs(.),   # rebuild with target res
                resolution = c(modal_res$res_x, modal_res$res_y)) }

# Snap template to a clean origin so all resampled tiles line up nicely
template <- terra::snap(template, "near")  # aligns to a “nice” grid

# --- Resample tiles to the template ------------------------------------------
# Elevation is continuous → bilinear is appropriate
r_list_aligned <-
  purrr::map(r_list, ~ {
    if (!terra::compareGeom(.x, template, stopOnError = FALSE)) {
      terra::resample(.x, template, method = "bilinear")
    } else {
      .x
    }
  })

# Sanity check that all are now comparable
stopifnot(all(purrr::map_lgl(r_list_aligned,
                             ~ terra::compareGeom(.x, template, stopOnError = FALSE))))

# --- Mosaic -------------------------------------------------------------------
elev_4326_mosaic <-
  do.call(terra::mosaic, c(r_list_aligned, list(fun = "mean")))


# --- mosaic tiles --------------------------------------------------------------
tile_files <- tile_grid$tile_path[fs::file_exists(tile_grid$tile_path)]
stopifnot(length(tile_files) > 0)

message("Mosaicking tiles…")
r_list   <- lapply(tile_files, terra::rast)
elev_4326_mosaic <- do.call(terra::mosaic, c(r_list, list(fun = "mean")))  # average overlaps


# optional crop strictly to bbox
elev_4326_mosaic <- terra::crop(elev_4326_mosaic, terra::vect(gp_bbox_4326))

# --- project to EPSG:5070 at 30 m; compute slope ------------------------------
crs_target <- "EPSG:5070"
target_res <- 30

message("Projecting DEM to EPSG:5070 at 30 m…")
elev_5070_30m <- terra::project(
  elev_4326_mosaic, y = crs_target, method = "bilinear", res = target_res
)

message("Computing rook-case slope in degrees…")
slope_5070_30m <- terra::terrain(elev_5070_30m, v = "slope", neighbors = 4, unit = "degrees")

# --- clip & mask to Great Plains (in target CRS) ------------------------------
gp_5070 <- sf::st_transform(gp_sf, crs_target)
gp_v    <- terra::vect(gp_5070)

elev_mask  <- terra::mask(terra::crop(elev_5070_30m, gp_v), gp_v)
slope_mask <- terra::mask(terra::crop(slope_5070_30m, gp_v), gp_v)

# --- QA -----------------------------------------------------------------------
rs_e <- terra::res(elev_mask);  rs_s <- terra::res(slope_mask)
na_e <- terra::global(is.na(elev_mask),  "mean", na.rm = TRUE)[[1]]
na_s <- terra::global(is.na(slope_mask), "mean", na.rm = TRUE)[[1]]
message(sprintf("DEM res (m):   %.2f x %.2f", rs_e[1], rs_e[2]))
message(sprintf("Slope res (m): %.2f x %.2f", rs_s[1], rs_s[2]))
message(sprintf("NA elev frac:  %.3f", na_e))
message(sprintf("NA slope frac: %.3f", na_s))

# --- write outputs -------------------------------------------------------------
elev_path  <- file.path(out_dir, "elev_30m_gp.tif")
slope_path <- file.path(out_dir, "slope_30m_gp.tif")

terra::writeRaster(
  elev_mask,  filename = elev_path,  overwrite = TRUE,
  gdal = c("COMPRESS=LZW", "PREDICTOR=2", "TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512", "BIGTIFF=YES")
)
terra::writeRaster(
  slope_mask, filename = slope_path, overwrite = TRUE,
  gdal = c("COMPRESS=LZW", "PREDICTOR=2", "TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512", "BIGTIFF=YES")
)

message("Done. Files:")
message(elev_path)
message(slope_path)











# # 1) CRS must be EPSG:4326
# if (is.na(sf::st_crs(gp_bbox_4326))) {
#   # if CRS got dropped, set it explicitly (we know it should be 4326)
#   sf::st_crs(gp_bbox_4326) <- 4326
# }
# stopifnot(sf::st_crs(gp_bbox_4326)$epsg == 4326)
# 
# # 2) lon/lat ranges should be within [-180,180] x [-90,90]
# bb_coords <- sf::st_coordinates(gp_bbox_4326)
# xr <- range(bb_coords[, 1], na.rm = TRUE)
# yr <- range(bb_coords[, 2], na.rm = TRUE)
# message(sprintf("bbox lon range: [%.3f, %.3f] ; lat range: [%.3f, %.3f]", xr[1], xr[2], yr[1], yr[2]))
# stopifnot(xr[1] >= -180, xr[2] <= 180, yr[1] >= -90, yr[2] <= 90)
# 

# ------------------------------------------------------------------------------
# 2a) Download elevation (elevatr) clipped to bbox
# ------------------------------------------------------------------------------
# --- z=10 is a reasonable default; increase if you need finer fetch windows ---

elev_raster_r <- elevatr::get_elev_raster(
  locations             = gp_bbox_4326,
  z                     = 10,
  clip                  = "locations",
  expand                = 0,
  override_size_check   = TRUE
)
elev_rast_4326 <- terra::rast(elev_raster_r)


# --- convert to terra ---
elev_rast_4326 <- terra::rast(elev_raster_r)  # (likely geographic)
rm(elev_raster_r)

# ------------------------------------------------------------------------------
# 2b) Add from manual download of raw data
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# 3) Project DEM to EPSG:5070 AT 30 m (explicit), then compute slope (degrees)
# ------------------------------------------------------------------------------
# Set target CRS and cellsize
crs_target <- "EPSG:5070"
target_res <- 30

message("Projecting DEM to EPSG:5070 at 30 m…")
elev_5070_30m <- terra::project(
  elev_rast_4326,
  y      = crs_target,
  method = "bilinear",   # DEM: continuous
  res    = target_res
)

# QA: confirm resolution ~30 x 30 (meters)
rs <- terra::res(elev_5070_30m)
message(sprintf("DEM (5070) resolution: %.3f x %.3f (m)", rs[1], rs[2]))

message("Computing slope (degrees, 4-neighbor/rook)…")
slope_5070_30m <- terra::terrain(
  elev_5070_30m,
  v         = "slope",
  neighbors = 4,          # rook’s case, smoother in plains/floodplains
  unit      = "degrees"
)

# ------------------------------------------------------------------------------
# 4) Clip & mask to Great Plains (in target CRS)
# ------------------------------------------------------------------------------
gp_5070 <- sf::st_transform(gp_sf, crs_target)
gp_v     <- terra::vect(gp_5070)

elev_mask <- terra::mask(terra::crop(elev_5070_30m, gp_v), gp_v)
slope_mask <- terra::mask(terra::crop(slope_5070_30m, gp_v), gp_v)

# QA: NA fraction, extents
na_elev <- terra::global(is.na(elev_mask), "mean", na.rm = TRUE)[[1]]
na_slope <- terra::global(is.na(slope_mask), "mean", na.rm = TRUE)[[1]]
message(sprintf("NA fraction (elev):  %.3f", na_elev))
message(sprintf("NA fraction (slope): %.3f", na_slope))

# ------------------------------------------------------------------------------
# 5) Write outputs (compressed GeoTIFF + overviews)
# ------------------------------------------------------------------------------
out_dir <- file.path(here(), "data", "processed", "ned")
fs::dir_create(out_dir)

elev_path  <- file.path(out_dir, "elev_30m_gp.tif")
slope_path <- file.path(out_dir, "slope_30m_gp.tif")

gdal_opts <- c(
  "COMPRESS=LZW",
  "PREDICTOR=2",
  "TILED=YES",
  "BLOCKXSIZE=512",
  "BLOCKYSIZE=512",
  "BIGTIFF=YES"
)

message("Writing elevation raster…")
terra::writeRaster(
  elev_mask,
  filename = elev_path,
  overwrite = TRUE,
  gdal = gdal_opts
)

message("Writing slope raster…")
terra::writeRaster(
  slope_mask,
  filename = slope_path,
  overwrite = TRUE,
  gdal = gdal_opts
)

# Build overviews (optional; speeds map rendering of large rasters)
try({
  terra::addMinMax(elev_path)
  terra::addMinMax(slope_path)
}, silent = TRUE)

# ------------------------------------------------------------------------------
# 6) Final QA summary
# ------------------------------------------------------------------------------
message("----- Final QA -----")
message(sprintf("CRS (elev):  %s", terra::crs(elev_mask, proj = TRUE)))
message(sprintf("CRS (slope): %s", terra::crs(slope_mask, proj = TRUE)))
message(sprintf("Res (m):     elev %.2f x %.2f | slope %.2f x %.2f",
                terra::res(elev_mask)[1], terra::res(elev_mask)[2],
                terra::res(slope_mask)[1], terra::res(slope_mask)[2]))
message(sprintf("Extent elev:  %s", paste(signif(terra::ext(elev_mask), 5), collapse = ", ")))
message(sprintf("Extent slope: %s", paste(signif(terra::ext(slope_mask), 5), collapse = ", ")))
message("Done.")




# # --- Get elevation raster ----------------------------------------------------
# elev_raster <- get_elev_raster(
#   locations = gp_bbox,  # <-- this was the key
#   z = 10,
#   clip = "locations",
#   expand = 1000
# )
# 
# # ------------------------------------------------------------------------------
# # 2. Reproject raster to EPSG:5070
# # ------------------------------------------------------------------------------
# # Slope calculations and masking require a projected CRS
# # for accurate distances and angles.
# elev_rast_proj <- terra::project(rast(elev_raster), "EPSG:5070")
# 
# # ------------------------------------------------------------------------------
# # 3. Compute slope raster
# # ------------------------------------------------------------------------------
# slope_proj <- terrain(elev_rast_proj,
#                       v = "slope",
#                       neighbors = 4,
#                       unit = "degrees")
# 
# # ------------------------------------------------------------------------------
# # 4. Mask outputs
# # ------------------------------------------------------------------------------
# gp_vect <- vect(gp_sf)
# 
# elev_mask <- mask(crop(elev_rast_proj, gp_vect), gp_vect)
# slope_mask <- mask(crop(slope_proj, gp_vect), gp_vect)
# 
# # ------------------------------------------------------------------------------
# # 4. Save clipped rasters
# # ------------------------------------------------------------------------------
# dir_create(file.path(here(), "data", "processed", "ned"))
# 
# writeRaster(
#   elev_mask,
#   filename = file.path(here(), "data", "processed", "ned", "elev_30m_gp.tif"),
#   overwrite = TRUE
# )
# 
# writeRaster(
#   slope_mask,
#   filename = file.path(here(), "data", "processed", "ned", "slope_30m_gp.tif"),
#   overwrite = TRUE
# )


