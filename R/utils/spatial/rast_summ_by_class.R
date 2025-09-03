# ==============================================================================
# Script Name:     Zonal raster helpers.R
# Purpose:         Calls {exactextractr} to compute dominant class, i.e category,
#                  class counts, and class fractions.
#                  with area-weighted exact extraction.
# Author:          CJ Tinant — with GPT 4o
# Date Created:    2025-08-07
# Last Updated:    2025-09-01
# Change Log:
# - 2025-08-08     Moved the align function to `prep_and_align.R`.
# - 2025-08-08     Updated dominant class function.
# - 2025-09-01     Update script header metadata.
# - 2025-09-03     Add discussion to script header metadata.
#                  Make factors explicit and guard for missing coverage_fraction
#                  in the dominant_category() helper.
#                  Add a stable type cast on value to category_counts(), so
#                  downstream joins don’t get tripped by factor vs integer.
#                  Add a single counts pass for class_fraction() to avoid multiple
#                  passes (e.g., NLCD developed/forest/grass/cultivated). See
#                  below for a use case.
#
# Discussion:
# The helper functions are thin wrappers for {exactextractr}. The helpers define
# the project’s API (id column first, tidy tibbles, naming), while delegating
# calculation to a well-maintained library.{exactextractr} streams efficiently;
# and helpers can compute multiple outputs from one pass if needed (see below).
# Additionally, {exactextractr} is able to reliably handle edge cases such as:
# partial pixels, holes, multipart polygons, antimeridian weirdness, etc.
#
# User Inputs:
# - Depends on an existing align_zones_to(zones, r) helper.
# - Works with terra SpatRaster + sf/SpatVector polygons.
#
# Function Outputs:
# - Returns tibbles with id_col as the first column.
# Notes:
#
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
  if (terra::nlyr(r) != 1) r <- r[[1]]
  if (inherits(zones, "SpatVector")) zones <- sf::st_as_sf(zones)
  stopifnot(id_col %in% names(zones))
  
  dfs <- exactextractr::exact_extract(r, zones, progress = FALSE)
  
  dom_vals <- purrr::map_int(dfs, function(df) {
    if (!nrow(df)) return(NA_integer_)
    v <- df[[1]]
    w <- df$coverage_fraction %||% rep(1, length(v))  # safety
    # normalize
    if (is.factor(v)) v <- as.integer(v)
    ok <- !is.na(v) & !is.na(w)
    if (!any(ok)) return(NA_integer_)
    sums <- tapply(w[ok], v[ok], sum)
    as.integer(names(which.max(sums)))
  })
  
  tibble::tibble(!!id_col := zones[[id_col]], .dominant = dom_vals)
}

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
      dplyr::tibble(value = v[ok], area = df$coverage_fraction[ok]) %>%
        dplyr::group_by(value) %>%
        dplyr::summarise(area = sum(area), .groups = "drop") %>%
        dplyr::mutate(!!id_col := unique(df[[id_col]]))
    },
    include_cols   = id_col,
    summarize_df   = TRUE,   # <-- IMPORTANT
    progress       = FALSE
  )

  res %>%
    purrr::compact() %>%
    dplyr::bind_rows() %>%
    dplyr::mutate(value = as.integer(value)) %>%
    dplyr::relocate(!!rlang::sym(id_col))
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

# Compute fractions for many class groups in one extraction pass
# Usage:
#   nlcd_groups <- list(
#   nlcd_frac_developed  = 21:24,
#   nlcd_frac_forest     = 41:43,
#   nlcd_frac_grassland  = 71,
#   nlcd_frac_cultivated = 81:82
#   )
#
# nlcd_tbl <- class_fractions_multi(r_nlcd, zones_aligned_sf, nlcd_groups,
#                                   id_col = "macro_id")

class_fractions_multi <- function(r, zones, groups, id_col = "macro_id") {
  # `groups` = named list, e.g. list(dev = 21:24, forest = 41:43, grass = 71,
  #                                  cult = 81:82)
  counts_long <- category_counts(r, zones, id_col) # value, area per zone
  totals <- counts_long |>
    dplyr::group_by(.data[[id_col]]) |>
    dplyr::summarise(area_tot = sum(area), .groups = "drop")
  fracs <- purrr::imap_dfr(groups, function(cls, nm) {
    counts_long |>
      dplyr::filter(value %in% cls) |>
      dplyr::group_by(.data[[id_col]]) |>
      dplyr::summarise(area_grp = sum(area), .groups = "drop") |>
      dplyr::right_join(totals, by = id_col) |>
      dplyr::mutate("{nm}" := dplyr::if_else(area_tot > 0, area_grp / area_tot, NA_real_)) |>
      dplyr::select(all_of(id_col), dplyr::all_of(nm))
  }) |>
    purrr::reduce(~ dplyr::full_join(.x, .y, by = id_col))
  fracs[order(fracs[[id_col]]), , drop = FALSE]
}

# ---- internal helpers --------------------------------------------------------

.require_namespace <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, FUN.VALUE = logical(1),
                          quietly = TRUE)]
  if (length(missing)) {
    stop("Missing required packages: ", paste(missing, collapse = ", "),
         call. = FALSE)
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
