# ==============================================================================
# Title:           Zonal raster helpers
# Purpose:         Prep rasters to zones; compute dominant class, class counts,
#                  and class fractions with area-weighted exact extraction.
# Author:          CJ Tinant — with ChatGPT
# Created:         2025-08-07
# Last-Edit:       2025-08-08
#
# Change Log:
# 2025-08-08        Moved the align function to `prep_and_align.R`.
# 2025-08-08        Updated dominant class function

#
# Notes:
# - Depends on an existing align_zones_to(zones, r) helper.
# - Works with terra SpatRaster + sf/SpatVector polygons.
# - Returns tibbles with id_col as the first column.
# ==============================================================================

#' Dominant (modal) category by zone using area weights
#'
#' @param r A single-band categorical `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`).
#' @param id_col Name of the identifier column in `zones`.
#'
#' @return Tibble with columns: `id_col`, `.dominant` (integer class code).
#' @export
# Robust dominant class using the per-polygon data.frame from exactextractr
dominant_category <- function(r, zones, id_col = "macro_id") {
  # Ensure single-band categorical raster
  if (terra::nlyr(r) != 1) {
    r <- r[[1]]
  }
  # Always work with sf to keep exactextractr happy
  if (inherits(zones, "SpatVector")) zones <- sf::st_as_sf(zones)
  stopifnot(id_col %in% names(zones))
  
  # Get a list of data.frames: one per polygon, with columns <layername> and coverage_fraction
  dfs <- exactextractr::exact_extract(r, zones, progress = TRUE)
  
  # Compute area-weighted mode per polygon
  dom_vals <- purrr::map_int(dfs, function(df) {
    v <- df[[1]]                      # first (and only) raster band
    w <- df$coverage_fraction
    ok <- !is.na(v) & !is.na(w)
    if (!any(ok)) return(NA_integer_)
    # Coerce factors to integers safely
    if (is.factor(v)) v <- as.integer(v)
    sums <- tapply(w[ok], v[ok], sum)
    as.integer(names(which.max(sums)))
  })
  
  tibble::tibble(!!id_col := zones[[id_col]], .dominant = dom_vals)
}
# dominant_category <- function(r, zones, id_col = "macro_id") {
#   .require_namespace(c("exactextractr", "tibble", "sf"))
#   .assert_single_band(r)
#   zones_sf <- .ensure_sf_polygons(zones)
#   .assert_has_id(zones_sf, id_col)
#   
#   vals <- exactextractr::exact_extract(
#     r, zones_sf,
#     function(vals, cov) {
#       v <- vals[[1]]
#       ok <- !is.na(v)
#       if (!any(ok)) return(NA_integer_)
#       # Sum coverage by class and take the max
#       area_by_class <- tapply(cov[ok], v[ok], sum)
#       as.integer(names(which.max(area_by_class)))
#     }
#   )
#   tibble::tibble(!!id_col := zones_sf[[id_col]], .dominant = vals)
# }

#' Area-weighted counts by category per zone (long table)
#'
#' @param r A single-band categorical `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`).
#' @param id_col Name of the identifier column in `zones`.
#'
#' @return Tibble with columns: `id_col`, `value` (class), `area` (weighted sum).
#' @export
category_counts <- function(r, zones, id_col = "macro_id") {
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r); .assert_has_id(zones_sf, id_col)
  
  res <- exactextractr::exact_extract(
    r, zones_sf,
    fun = function(df, ...) {
      v  <- df[[1]]  # first (only) band
      ok <- !is.na(v)
      if (!any(ok)) return(NULL)
      dplyr::tibble(value = v[ok], area = df$coverage_fraction[ok]) |>
        dplyr::group_by(value) |>
        dplyr::summarise(area = sum(area), .groups = "drop") |>
        dplyr::mutate(!!id_col := unique(df[[id_col]]))
    },
    include_cols   = id_col,
    summarize_df   = TRUE,   # <-- IMPORTANT
    progress       = FALSE
  )
  
  res |> purrr::compact() |> dplyr::bind_rows() |> dplyr::relocate(!!rlang::sym(id_col))
}


#' Proportion of zone covered by selected classes
#'
#' Reclassifies the raster to binary (1 = in `classes`, 0 = otherwise) and
#' computes the area-weighted mean, which equals the area fraction.
#'
#' @param r A single-band categorical `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`).
#' @param classes Integer vector of class codes to treat as 1.
#' @param id_col Identifier column in `zones`.
#' @param out_name Output column name for the fraction (default "prop").
#'
#' @return Tibble with columns: `id_col`, `out_name` (numeric fraction in [0,1]).
#' @export
class_fraction <- function(r, zones, classes,
                           id_col = "macro_id",
                           out_name = "prop") {
  .require_namespace(c("exactextractr", "tibble", "terra", "sf"))
  .assert_single_band(r)
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_has_id(zones_sf, id_col)
  
  all_vals <- unique(stats::na.omit(as.vector(terra::values(r))))
  rc <- cbind(from = all_vals, to = ifelse(all_vals %in% classes, 1, 0))
  r_bin <- terra::classify(r, rc, others = NA)
  
  frac <- exactextractr::exact_extract(
    r_bin, zones_sf, fun = "weighted_mean", progress = FALSE
  )
  
  tibble::tibble(!!id_col := zones_sf[[id_col]], !!out_name := frac)
}

# ---- internal helpers --------------------------------------------------------

.require_namespace <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, FUN.VALUE = logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

.ensure_sf_polygons <- function(z) {
  if (inherits(z, "SpatVector")) z <- sf::st_as_sf(z)
  stopifnot(inherits(z, "sf"))
  # Make valid if needed
  if (!all(sf::st_is_valid(z))) z <- sf::st_make_valid(z)
  # Sanity: polygons only
  gt <- unique(sf::st_geometry_type(z, by_geometry = TRUE))
  if (!all(gt %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("`zones` must contain polygon geometries.", call. = FALSE)
  }
  z
}

.assert_single_band <- function(r) {
  if (terra::nlyr(r) != 1) {
    stop("Functions expect a single-band (categorical) raster.", call. = FALSE)
  }
}

.assert_has_id <- function(zones_sf, id_col) {
  if (!id_col %in% names(zones_sf)) {
    stop("`zones` is missing the identifier column: ", id_col, call. = FALSE)
  }
}
