# ==============================================================================
# Script Name:     prep_and_align.R
# Purpose:         Utilities to (a) align polygon zones to a raster’s CRS and
#                  (b) prepare a raster for zonal work (optional crop/mask).
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-08-08
# Last Updated:    2025-09-03
#
# Changelog:
# - 2025-08-08     Merge zonal_raster_helpers.R and align_zones_to.R which both
#                  have a prep_raster function.
# - 2025-08-29     Update header metadata
# - 2025-09-03     Add `Discussion` to explain what the function does;
#                  Update `User Inputs` and `Function Outputs` descriptions.
#
# Discussion: What each function does (in plain terms)
# - align_zones_to(zones, rst, ...)
#     - Ensures zones are valid (optional), converts to SpatVector, and
#       reprojects zones to the raster’s CRS (no raster warping).
#     - Returns a SpatVector (polygons) in the same CRS as the raster.
# - prep_raster(rst, zones, do_crop = TRUE, do_mask = TRUE, ...)
#     - Opens the raster (or path) as a SpatRaster.
#     - Calls align_zones_to() to get zones in the raster CRS.
#     - Optionally crops the raster to the zones bbox and masks it to the polygon
#       shapes.
#     - Returns list(r = <SpatRaster>, zones = <SpatVector>).
#
# User Inputs:
#   - polygon zones (sf or SpatVector) and a raster (SpatRaster or path).
# Function Outputs:
#   - align_zones_to(): SpatVector (polygons) in the raster CRS
#   - prep_raster():    list(r = SpatRaster, zones = SpatVector)
#
# Depends: terra, sf, cli
#
# Suggested workflow:
# utils/assert_inputs_ok.R, prep_and_align, rast_summaries_x
# ==============================================================================

# ---- internal namespace check ------------------------------------------------
.require_namespace <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, FUN.VALUE = logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

#' Align zones to a raster CRS (no raster warping)
#'
#' @param zones sf polygons or terra SpatVector polygons.
#' @param rst   terra SpatRaster or a path readable by terra::rast().
#' @param make_valid logical; repair invalid geometries if possible (default TRUE).
#' @param quiet logical; suppress info messages (default FALSE).
#'
#' @return terra SpatVector with CRS matching `rst`.
align_zones_to <- function(zones, rst, make_valid = TRUE, quiet = FALSE) {
  .require_namespace(c("terra", "sf"))
  
  # Normalize raster
  r <- if (inherits(rst, "SpatRaster")) rst else terra::rast(rst)
  
  # Normalize zones → SpatVector polygons
  z <- zones
  if (inherits(z, "sf")) {
    if (!all(sf::st_geometry_type(z) %in% c("POLYGON", "MULTIPOLYGON"))) {
      stop("`zones` must contain POLYGON/MULTIPOLYGON geometries.", call. = FALSE)
    }
    z <- terra::vect(z)
  } else if (!inherits(z, "SpatVector")) {
    stop("`zones` must be sf or terra SpatVector.", call. = FALSE)
  }
  
  # Optional validity repair
  if (isTRUE(make_valid)) {
    z <- tryCatch(terra::makeValid(z), error = function(e) z)
  }
  
  # CRS checks
  z_crs <- terra::crs(z, proj = TRUE)
  r_crs <- terra::crs(r, proj = TRUE)
  if (is.na(z_crs) && !is.na(r_crs)) stop("`zones` has no CRS; assign one before aligning.", call. = FALSE)
  if (!is.na(z_crs) && is.na(r_crs)) stop("Raster has no CRS; assign one before aligning.", call. = FALSE)
  
  # Reproject if needed
  if (!terra::same.crs(z, r)) {
    if (!quiet) cli::cli_inform("Reprojecting zones → raster CRS...")
    z <- terra::project(z, r)
  } else if (!quiet) {
    cli::cli_inform("Zones already match raster CRS; no reprojection needed.")
  }
  
  z
}

#' Prepare raster + zones for zonal operations
#'
#' @param rst        SpatRaster or path.
#' @param zones      sf or SpatVector polygons.
#' @param do_crop    logical; crop raster to zones bbox (default TRUE).
#' @param do_mask    logical; mask raster to zone polygons (default TRUE).
#' @param make_valid logical; repair invalid polygon geometries (default TRUE).
#' @param quiet      logical; suppress info messages (default FALSE).
#'
#' @return list(r = SpatRaster, zones = SpatVector)
prep_raster <- function(rst,
                        zones,
                        do_crop    = TRUE,
                        do_mask    = TRUE,
                        make_valid = TRUE,
                        quiet      = FALSE) {
  .require_namespace(c("terra", "sf"))
  
  r <- if (inherits(rst, "SpatRaster")) rst else terra::rast(rst)
  z <- align_zones_to(zones, r, make_valid = make_valid, quiet = quiet)
  
  if (isTRUE(do_crop)) r <- terra::crop(r, z)
  if (isTRUE(do_mask)) r <- terra::mask(r, z)
  
  list(r = r, zones = z)
}
