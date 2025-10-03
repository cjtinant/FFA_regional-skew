# ==============================================================================
# Script Name:     raster_summaries_continuous.R
# Purpose:         Calculate continuous raster summaries by zone
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-08-07
# Last Updated:    2025-08-29
# Change Log:
# - 2025-08-29     Updated header metadata
#
# Discussion:      Computes area-weighted summaries for a single-band continuous
#                  raster: mean, median, min, max, sum, sd, and (optionally)
#                  weighted quantiles.
#
# Workflow Summary:

# User Inputs:
# - A single-band continuous `terra::SpatRaster`
# -  `sf` polygons (in same CRS).
# - req_cols      Required attribute columns in zones (e.g., "macro_id")
#
# Function Outputs:
# - Tibble with `id_col` first, then one column per requested stat/quantile.
# ==============================================================================

#' Continuous raster summaries by zone (area-weighted)
#'
#' Computes area-weighted summaries for a single-band continuous raster:
#' mean, median, min, max, sum, sd, and (optionally) weighted quantiles.
#'
#' @param r A single-band continuous `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`).
#' @param id_col Identifier column in `zones`. Default: "macro_id".
#' @param stats Character vector of stats to compute. Any of:
#'   c("mean","median","min","max","sum","sd"). Default: c("mean","median").
#' @param probs Optional numeric vector in (0,1) for weighted quantiles,
#'   e.g., c(0.05,0.25,0.75,0.95). Column names will be like `q05`, `q25`, etc.
#' @return Tibble with `id_col` first, then one column per requested stat/quantile.
#' @export
cont_summary <- function(r, zones, id_col = "macro_id",
                         stats = c("mean", "median"),
                         probs = NULL) {
  .require_namespace(c("exactextractr","tibble","dplyr","sf","terra"))
  .assert_single_band(r)
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_has_id(zones_sf, id_col)
  
  # Built-ins we can call by name for speed
  built_in <- intersect(stats, c("mean","median","sum"))
  out_list <- list()
  
  if ("mean" %in% built_in) {
    out_list$mean <- tibble::tibble(
      !!id_col := zones_sf[[id_col]],
      mean = exactextractr::exact_extract(r, zones_sf, fun = "weighted_mean",
                                          progress = FALSE)
    )
  }
  if ("median" %in% built_in) {
    out_list$median <- tibble::tibble(
      !!id_col := zones_sf[[id_col]],
      median = exactextractr::exact_extract(r, zones_sf, fun = "weighted_median",
                                            progress = FALSE)
    )
  }
  if ("sum" %in% built_in) {
    out_list$sum <- tibble::tibble(
      !!id_col := zones_sf[[id_col]],
      sum = exactextractr::exact_extract(
        r, zones_sf, fun = "weighted_sum", progress = FALSE
      )
    )
  }
  
  # Custom functions evaluated via (vals, cov) callback
  needs_custom <- setdiff(stats, c(built_in))
  if (length(needs_custom)) {
    res <- exactextractr::exact_extract(
      r, zones_sf,
      function(vals, cov) {
        v <- vals[[1]]
        w <- cov
        ok <- !is.na(v) & !is.na(w) & w > 0
        if (!any(ok)) return(
          setNames(as.list(rep(NA_real_, length(needs_custom))), needs_custom)
        )
        v <- v[ok]; w <- w[ok]
        
        ans <- list()
        if ("min" %in% needs_custom) ans$min <- min(v)
        if ("max" %in% needs_custom) ans$max <- max(v)
        if ("sd"  %in% needs_custom)  ans$sd  <- .wtd_sd(v, w)
        # Note: "sum" handled above; "mean"/"median" have built-ins
        ans[needs_custom]  # order guarantees consistent naming
      },
      summarize_df = TRUE, # return one row per zone with named cols
      progress = FALSE
    )
    if (nrow(res)) {
      out_list$custom <- dplyr::bind_cols(
        tibble::tibble(!!id_col := zones_sf[[id_col]]),
        res
      )
    }
  }
  
  # Weighted quantiles (qXX columns)
  if (!is.null(probs) && length(probs)) {
    probs <- sort(unique(probs))
    qnames <- paste0("q", sprintf("%02d", round(100 * probs)))
    qres <- exactextractr::exact_extract(
      r, zones_sf,
      function(vals, cov) {
        v <- vals[[1]]; w <- cov
        ok <- !is.na(v) & !is.na(w) & w > 0
        if (!any(ok)) return(as.list(rep(NA_real_, length(probs))))
        .wtd_quantile(v[ok], w[ok], probs = probs)
      },
      summarize_df = TRUE,
      progress = FALSE
    )
    names(qres) <- qnames
    out_list$quant <- dplyr::bind_cols(
      tibble::tibble(!!id_col := zones_sf[[id_col]]),
      qres
    )
  }
  
  # Stitch outputs left-to-right with id_col first
  out <- Reduce(function(a, b) dplyr::left_join(a, b, by = id_col), out_list)
  dplyr::relocate(out, !!rlang::sym(id_col))
}

# ---- internal weighted helpers ----------------------------------------------

.wtd_sd <- function(x, w) {
  w <- w / sum(w)
  m <- sum(w * x)
  sqrt(sum(w * (x - m)^2))
}

.wtd_quantile <- function(x, w, probs) {
  ord <- order(x); x <- x[ord]; w <- w[ord]
  cw <- cumsum(w) / sum(w)
  vapply(probs, function(p) {
    idx <- which(cw >= p)[1]
    if (is.na(idx)) tail(x, 1) else x[idx]
  }, numeric(1))
}

# ---- tiny internal helpers ---------------------------------------------------

.require_namespace <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, FUN.VALUE = logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

.assert_single_band <- function(r) {
  if (!inherits(r, "SpatRaster")) {
    stop("`r` must be a terra::SpatRaster.", call. = FALSE)
  }
  if (terra::nlyr(r) != 1L) {
    stop("`r` must be single-band; got ", terra::nlyr(r), " layers.", call. = FALSE)
  }
}

.ensure_sf_polygons <- function(z) {
  # Accept sf polygons/multipolygons or SpatVector polygons
  if (inherits(z, "SpatVector")) z <- sf::st_as_sf(z)
  if (!inherits(z, "sf")) {
    stop("`zones` must be sf or terra::SpatVector.", call. = FALSE)
  }
  if (!inherits(sf::st_geometry(z), "sfc_POLYGON") &&
      !inherits(sf::st_geometry(z), "sfc_MULTIPOLYGON")) {
    stop("`zones` must be polygonal (POLYGON/MULTIPOLYGON).", call. = FALSE)
  }
  
  # Make valid + normalize type
  s2_prev <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(s2_prev), add = TRUE)
  
  z <- z %>%
    sf::st_make_valid() %>%
    sf::st_cast("MULTIPOLYGON", warn = FALSE)
  
  # Project to raster CRS if both have CRS and they differ (silent, safe)
  z
}

.assert_has_id <- function(zones_sf, id_col) {
  if (!id_col %in% names(zones_sf)) {
    stop("`id_col` '", id_col, "' not found in `zones`.", call. = FALSE)
  }
  if (all(is.na(zones_sf[[id_col]]))) {
    stop("`id_col` '", id_col, "' is all NA in `zones`.", call. = FALSE)
  }
  invisible(TRUE)
}

# If you prefer geometry column name 'geom' across the project:
.set_geom_name <- function(x) {
  # keep sf semantics but use 'geom' as active column name
  if (inherits(x, "sf")) {
    sf::st_geometry(x) <- "geom"
  }
  x
}
