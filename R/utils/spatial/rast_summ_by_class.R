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
# - 2025-09-04     Added dominance fraction to the dominant (modal) category by
#                  zone using area weights function, i.e. `dominant_category()`;
#                  Added a function to get top n Köppen classes per macrozone
#
# Discussion:
# The helper functions are thin wrappers for {exactextractr}. They define the
# project’s API (id column first, tidy tibbles, naming), can be used to
# compute multiple outputs from one pass, e.g. NDVI classes, and to return
# the dominance fraction. Calculation is delegated to {exactextractr}, which is
# able to reliably handle edge cases such as:partial pixels, holes, multipart
# polygons, antimeridian weirdness, etc.
#
# Dominance fraction is a clean way to measure confidence in the modal class.
# If a macrozone is ~95% one class, the “dominant” label is very representative;
# if it’s ~55%, that’s basically a coin toss.
#
# See individual helper functions for User Inputs and Function Outputs:
#
# ==============================================================================

#' Dominant (modal) category by zone using area weights 
#'
#' @param r A single-band categorical `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`) or `SpatVector`.
#' @param id_col Name of the identifier column in `zones`.
#'
#' @return Tibble with columns:
#'   - `id_col`      : zone identifier
#'   - `.dominant`   : integer class code of the weighted mode
#'   - `.dom_frac`   : dominance fraction in [0,1] = (area of modal class) / (area of all classes)
#' @export
dominant_category <- function(r, zones, id_col = "macro_id") {
  if (terra::nlyr(r) != 1) r <- r[[1]]
  if (inherits(zones, "SpatVector")) zones <- sf::st_as_sf(zones)
  stopifnot(id_col %in% names(zones))
  
  dfs <- exactextractr::exact_extract(r, zones, progress = FALSE)
  
  dom <- purrr::map_dfr(dfs, function(df) {
    if (!nrow(df)) return(tibble::tibble(.dominant = NA_integer_, .dom_frac = NA_real_))
    
    v <- df[[1]]
    w <- if (!is.null(df$coverage_fraction)) df$coverage_fraction else rep(1, length(v))
    
    # normalize inputs
    if (is.factor(v)) v <- as.integer(v)
    ok <- !is.na(v) & !is.na(w)
    if (!any(ok)) return(tibble::tibble(.dominant = NA_integer_, .dom_frac = NA_real_))
    
    sums <- tapply(w[ok], v[ok], sum)
    if (length(sums) == 0 || sum(sums) <= 0) {
      return(tibble::tibble(.dominant = NA_integer_, .dom_frac = NA_real_))
    }
    max_class <- as.integer(names(which.max(sums)))
    dom_frac  <- as.numeric(max(sums) / sum(sums))
    
    tibble::tibble(.dominant = max_class, .dom_frac = dom_frac)
  })
  
  tibble::tibble(!!id_col := zones[[id_col]]) %>%
    dplyr::bind_cols(dom)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# # Get top 2 Köppen classes per macrozone
# top2 <- top_n_categories(r_koppen, z_koppen_sf, n = 2, id_col = "macro_id")
# 
# top2
# # A tibble like:
# #   macro_id  rank  value  prop
# #       1       1      7  0.71
# #       1       2     11  0.23
# #       2       1      7  0.56
# #       2       2     14  0.33
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Top-N categories per zone with proportions
#'
#' @param r A single-band categorical `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`) or `SpatVector`.
#' @param n Number of top classes to return (default 2).
#' @param id_col Name of the identifier column in `zones`.
#'
#' @return Tibble with columns: `id_col`, `rank`, `value`, `prop`.
#'         One row per class per zone (up to `n` per zone).
#' @export
top_n_categories <- function(r, zones, n = 2, id_col = "macro_id") {
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r)
  .assert_has_id(zones_sf, id_col)
  
  # Get weighted counts (area fractions not yet normalized)
  counts_long <- category_counts(r, zones_sf, id_col)
  
  # Normalize to proportions
  counts_long <- counts_long %>%
    dplyr::group_by(.data[[id_col]]) %>%
    dplyr::mutate(prop = area / sum(area)) %>%
    dplyr::ungroup()
  
  # Slice top-n per zone
  topn <- counts_long %>%
    dplyr::group_by(.data[[id_col]]) %>%
    dplyr::slice_max(order_by = prop, n = n, with_ties = FALSE) %>%
    dplyr::arrange(.data[[id_col]], dplyr::desc(prop)) %>%
    dplyr::mutate(rank = dplyr::row_number(), .by = !!rlang::sym(id_col)) %>%
    dplyr::ungroup()
  
  topn %>%
    dplyr::select(!!id_col, rank, value, prop)
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

class_fractions_multi <- function(r, zones, groups, id_col = "macro_id") {
  # `groups` = named list, e.g. list(dev = 21:24, forest = 41:43, grass = 71,
  #                                  cult = 81:82)
  counts_long <- category_counts(r, zones, id_col) # value, area per zone
  totals <- counts_long %>%
    dplyr::group_by(.data[[id_col]]) %>%
    dplyr::summarise(area_tot = sum(area), .groups = "drop")
  fracs <- purrr::imap_dfr(groups, function(cls, nm) {
    counts_long %>%
      dplyr::filter(value %in% cls) %>%
      dplyr::group_by(.data[[id_col]]) %>%
      dplyr::summarise(area_grp = sum(area), .groups = "drop") %>%
      dplyr::right_join(totals, by = id_col) %>%
      dplyr::mutate("{nm}" := dplyr::if_else(area_tot > 0, area_grp / area_tot, NA_real_)) %>%
      dplyr::select(all_of(id_col), dplyr::all_of(nm))
  }) %>%
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
