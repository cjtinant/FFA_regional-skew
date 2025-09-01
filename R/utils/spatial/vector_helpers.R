# ==============================================================================
# Script Name:     R/utils/spatial/vector_helpers.R
# Purpose:         Helper functions for spatial vector layers.
# Author:          Charles Jason Tinant with ChatGPT 4o
# Date Created:    2025-08-14
# Last Update:     2025-08-14
# Change Log:
# - 2025-08-14     Initialize script
# - 2025-09-01     Updated header metadata
#
# Description:
#
# Workflow Summary:
#
# Depends:
#
# Next Steps:
# Example Roxygen
##' Align zones to a raster CRS (no raster warping)
##' 
##' @param zones sf polygons or terra SpatVector polygons.
##' @param rst   terra SpatRaster or a path readable by terra::rast().
##' @param make_valid logical; repair invalid geometries if possible (default TRUE).
##' @param quiet logical; suppress info messages (default FALSE).
##' 
##' @return terra SpatVector with CRS matching `rst`.
# ==============================================================================
# --- enforce 'geom' as active sf column ---
ensure_geom <- function(x) {
  stopifnot(inherits(x, "sf"))
  if ("geom" %in% names(x)) {
    st_geometry(x) <- "geom"
  } else if ("geometry" %in% names(x)) {
    x <- dplyr::rename(x, geom = geometry)
    st_geometry(x) <- "geom"
  } else {
    stop("No geometry column named 'geom' or 'geometry' found.")
  }
  x
}