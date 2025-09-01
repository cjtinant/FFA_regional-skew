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
