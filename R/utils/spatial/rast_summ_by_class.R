# ==============================================================================
# Script Name:     Zonal raster helpers.R
# Purpose:         Calls {exactextractr} to compute dominant class, i.e category,
#                  class counts, and class fractions.
#                  with area-weighted exact extraction.
# Author:          CJ Tinant — with GPT 4o
# Date Created:    2025-08-07
# Last Updated:    2025-09-5
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
# - 2025-09-05     Added a PHZM summary function that converts a continuous PHZM
#                  surface (C or F) into USDA half-zone integer codes (1..26)
#                  inside the function, then does the compact summary returns:
#                  dominant, dominance fraction, class count, top-2.
#                  Updated category_counts() to fix a memory issue.
# - 2025-09-07     Added category_counts_tiled() function to deal with a RAM
#                  sawtooth or “one big raster + many polygons” behavior leading
#                  to an abort. The fu Let’s hard-cap memory by tiling the raster
#                  and summing results across tiles to avoid any single
#                  exact_extract() run building huge working sets.
#
# Discussion:
# The helper functions are thin wrappers for {exactextractr}. They define the
# project’s API (id column first, tidy tibbles, naming), can be used to
# compute multiple outputs from one pass, e.g. NDVI classes, and to return
# the dominance fraction. Calculation is delegated to {exactextractr}, which is
# able to reliably handle edge cases such as:partial pixels, holes, multi-part
# polygons, anti-meridian weirdness, etc.
#
# Dominant (modal) category by zone using area weights gives the majority
# class.
#
# Dominance fraction is a clean way to measure confidence in the modal class.
# If a macrozone is ~95% one class, the “dominant” label is very representative;
# if it’s ~55%, that’s basically a coin toss.
#
# The top_n_categories() returns top-N classes and their proportions per zone,
# using area-weighted counts from category_counts() to explore heterogeneous
# zones where a single dominant category is not representative.
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

# ==============================================================================
# category_counts_tiled(): low-RAM, tile-wise categorical tallies
# Author: CJ Tinant — with Gepeto
# Purpose: area-weighted counts for categorical rasters (e.g., NLCD),
#          robust to very large rasters and many polygons.
# Notes:
#   - Vector-signature summarizer (values, coverage_fractions, ...)
#   - Tiled raster processing; sum across tiles at the end.
#   - Writes per-tile partials to disk to cap heap growth.
#   - Uses %>% and vertical formatting (ADHD-friendly).
# ==============================================================================

category_counts_tiled <- function(
    r,
    zones,
    id_col             = "macro_id",
    nx                 = 6,
    ny                 = 6,
    zones_simplify_tol = 0,
    tmp_dir            = here::here("tmp", "zonal_partials"),
    progress           = FALSE
) {
  
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r)
  .assert_has_id(zones_sf, id_col)
  
  if (terra::nlyr(r) != 1L) {
    r <- r[[1L]]
  }
  
  # ensure integer categories, encourage disk i/o
  r <- terra::as.int(r)
  terra::terraOptions(memfrac = 0.6)
  fs::dir_create(tmp_dir)
  
  s2_prev <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  on.exit({ sf::sf_use_s2(s2_prev) }, add = TRUE)
  
  if (zones_simplify_tol > 0) {
    zones_sf <- zones_sf %>%
      sf::st_make_valid() %>%
      sf::st_simplify(dTolerance = zones_simplify_tol, preserveTopology = TRUE)
  }
  
  # ---- tile grid --------------------------------------------------------------
  e  <- terra::ext(r)
  dx <- (e$xmax - e$xmin) / nx
  dy <- (e$ymax - e$ymin) / ny
  
  tiles <- tidyr::expand_grid(
    ix = seq_len(nx),
    iy = seq_len(ny)
  ) %>%
    dplyr::mutate(
      xmin = e$xmin + (ix - 1) * dx,
      xmax = e$xmin + ix * dx,
      ymin = e$ymin + (iy - 1) * dy,
      ymax = e$ymin + iy * dy,
      tid  = sprintf("tx%02d_ty%02d", ix, iy)
    )
  
  part_files <- character(nrow(tiles))
  
  # helper: coerce any result to tibble
  .as_tbl <- function(x) {
    if (is.null(x)) return(NULL)
    if (is.numeric(x)) {
      nm <- names(x)
      if (!is.null(nm) && length(nm) == length(x)) {
        return(
          tibble::tibble(
            value = as.integer(nm),
            area  = as.numeric(unname(x))
          )
        )
      } else {
        return(NULL)
      }
    }
    if (is.data.frame(x)) return(tibble::as_tibble(x))
    NULL
  }
  
  # ---- per-tile loop ----------------------------------------------------------
  for (k in seq_len(nrow(tiles))) {
    
    tk   <- tiles[k, ]
    extk <- terra::ext(tk$xmin, tk$xmax, tk$ymin, tk$ymax)
    
    r_k <- try(terra::crop(r, extk, snap = "out"), silent = TRUE)
    if (inherits(r_k, "try-error") || is.null(r_k)) next
    if (is.na(terra::ncell(r_k)) || terra::ncell(r_k) == 0) next
    
    # prefer raster extent intersect (tighter than raw bbox)
    ext_poly <- sf::st_as_sfc(
      sf::st_bbox(terra::ext(r_k), crs = sf::st_crs(zones_sf))
    )
    sel <- sf::st_intersects(zones_sf, ext_poly, sparse = TRUE) %>% lengths() > 0
    if (!any(sel)) next
    
    z_k <- zones_sf[sel, , drop = FALSE]
    
    # ---- exact_extract with robust summarizer ---------------------------------
    res_k <- exactextractr::exact_extract(
      r_k,
      z_k,
      fun = function(values, coverage_fractions, ...) {
        ok <- !is.na(values)
        if (!any(ok)) {
          return(NULL)
        }
        vv <- as.integer(values[ok])
        ww <- coverage_fractions[ok]
        
        # guarantee names via factor levels
        u_levels <- sort(unique(vv))
        tab <- tapply(
          X     = ww,
          INDEX = factor(vv, levels = u_levels),
          FUN   = sum
        )
        
        tibble::tibble(
          value = as.integer(names(tab)),
          area  = as.numeric(unname(tab))
        )
      },
      summarize_df = FALSE,
      progress     = progress
    )
    
    # normalize outputs before combine
    res_k <- purrr::map(res_k, .as_tbl)
    
    # ---- index-safe combine (handles length mismatch) -------------------------
    ids_k  <- z_k[[id_col]]
    n_res  <- length(res_k)
    n_ids  <- length(ids_k)
    n_iter <- min(n_res, n_ids)
    
    if (n_res != n_ids) {
      warning(
        "Tile ", tk$tid, ": exact_extract returned ", n_res,
        " result(s) for ", n_ids, " polygon(s); attaching ids for the first ", n_iter, "."
      )
    }
    
    part_list <- vector("list", n_iter)
    
    for (i in seq_len(n_iter)) {
      xi <- res_k[[i]]
      if (is.null(xi)) next
      xi <- .as_tbl(xi)
      if (is.null(xi) || nrow(xi) == 0) next
      xi[[id_col]] <- ids_k[i]
      part_list[[i]] <- xi
    }
    
    part_k <-
      part_list %>%
      purrr::compact() %>%
      dplyr::bind_rows()
    
    if (nrow(part_k)) {
      out_csv <- file.path(tmp_dir, paste0("partials_", tk$tid, ".csv"))
      readr::write_csv(part_k, out_csv)
      part_files[k] <- out_csv
    }
    
    rm(r_k, z_k, res_k, part_k); gc()
  }
  
  # ---- reduce all partials on disk -------------------------------------------
  part_files <- part_files[nzchar(part_files)]
  
  if (!length(part_files)) {
    return(
      tibble::tibble(
        !!id_col := integer(),
        value    = integer(),
        area     = double()
      )
    )
  }
  
  if (requireNamespace("vroom", quietly = TRUE)) {
    
    final <-
      vroom::vroom(
        file           = part_files,
        col_select     = c(!!id_col, value, area),
        show_col_types = FALSE,
        progress       = FALSE
      ) %>%
      dplyr::mutate(
        !!id_col := as.integer(.data[[id_col]]),
        value    = as.integer(value),
        area     = as.numeric(area)
      ) %>%
      dplyr::group_by(!!rlang::sym(id_col), value) %>%
      dplyr::summarise(area = sum(area), .groups = "drop") %>%
      dplyr::relocate(!!rlang::sym(id_col))
    
  } else {
    
    batch_ids <- split(seq_along(part_files), ceiling(seq_along(part_files) / 50))
    
    partial_reduced <-
      purrr::map(batch_ids, function(ii) {
        purrr::map(part_files[ii], readr::read_csv, show_col_types = FALSE) %>%
          dplyr::bind_rows() %>%
          dplyr::mutate(
            !!id_col := as.integer(.data[[id_col]]),
            value    = as.integer(value),
            area     = as.numeric(area)
          ) %>%
          dplyr::group_by(!!rlang::sym(id_col), value) %>%
          dplyr::summarise(area = sum(area), .groups = "drop")
      }) %>%
      dplyr::bind_rows()
    
    final <-
      partial_reduced %>%
      dplyr::group_by(!!rlang::sym(id_col), value) %>%
      dplyr::summarise(area = sum(area), .groups = "drop") %>%
      dplyr::relocate(!!rlang::sym(id_col))
  }
  
  final
}




# ==============================================================================
# category_counts(): area-weighted category tallies with strict memory bounds
# Author: CJ Tinant — with Gepeto
# Notes:
#   - Works best if r is categorical integer (e.g., NLCD).
#   - Batches zones to cap peak memory. Tweak zones_batch.
#   - Optional geometry simplify (meters or degrees; keep small).
# ==============================================================================

category_counts <- function(
    r,
    zones,
    id_col        = "macro_id",
    zones_batch   = 200,     # lower if you still hit memory ceilings
    simplify_tol  = 0,       # e.g., 50 for ~50 m if CRS in meters; 0 = no simplify
    progress      = FALSE
) {
  
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r)
  .assert_has_id(zones_sf, id_col)
  
  if (terra::nlyr(r) != 1L) {
    r <- r[[1L]]
  }
  
  # ensure integer categories (important for rowsum keys)
  terra::datatype(r) <- "INT4S"
  
  # optional: temporarily disable s2 for heavy polygon ops (less RAM)
  s2_prev <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  
  on.exit({
    sf::sf_use_s2(s2_prev)
  }, add = TRUE)
  
  n_z <- nrow(zones_sf)
  idx <- split(seq_len(n_z), ceiling(seq_len(n_z) / zones_batch))
  
  parts <- vector("list", length(idx))
  
  for (k in seq_along(idx)) {
    
    ii <- idx[[k]]
    
    z_sub <- zones_sf[ii, , drop = FALSE]
    
    if (simplify_tol > 0) {
      z_sub <- sf::st_make_valid(z_sub) %>%
        sf::st_simplify(dTolerance = simplify_tol, preserveTopology = TRUE)
    }
    
    # --- exact_extract with vector signature (values, coverage_fractions, ...)
    res_k <- exactextractr::exact_extract(
      r,
      z_sub,
      fun = function(values, coverage_fractions, ...) {
        ok <- !is.na(values)
        if (!any(ok)) {
          return(NULL)
        }
        
        vv <- as.integer(values[ok])
        ww <- coverage_fractions[ok]
        
        s  <- rowsum(ww, group = vv, reorder = FALSE)
        
        tibble::tibble(
          value = as.integer(rownames(s)),
          area  = as.numeric(s[, 1L])
        )
      },
      summarize_df = FALSE,
      progress     = progress
    )
    
    ids_k <- z_sub[[id_col]]
    
    parts[[k]] <-
      purrr::map2(
        res_k,
        ids_k,
        ~ if (is.null(.x)) {
          NULL
        } else {
          dplyr::mutate(.x, !!id_col := .y)
        }
      ) %>%
      purrr::compact() %>%
      dplyr::bind_rows()
    
    # free memory between batches
    rm(res_k, z_sub)
    gc(verbose = FALSE)
  }
  
  parts %>%
    purrr::compact() %>%
    dplyr::bind_rows() %>%
    dplyr::relocate(!!rlang::sym(id_col)) %>%
    dplyr::mutate(value = as.integer(value))
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# top_n_categories(): top-N classes per polygon with proportions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
top_n_categories <- function(r, zones, n = 3, id_col = "macro_id") {
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r); .assert_has_id(zones_sf, id_col)
  if (terra::nlyr(r) != 1L) r <- r[[1L]]
  
  res <- exactextractr::exact_extract(
    r, zones_sf,
    fun = function(df, ...) {
      v  <- df[[1L]]
      ok <- !is.na(v)
      if (!any(ok)) return(NULL)
      
      dplyr::tibble(value = v[ok], w = df$coverage_fraction[ok]) %>%
        dplyr::group_by(value) %>%
        dplyr::summarise(area = sum(w), .groups = "drop") %>%
        dplyr::mutate(
          prop   = area / sum(area),
          !!id_col := unique(df[[id_col]])
        ) %>%
        dplyr::slice_max(area, n = n, with_ties = FALSE)
    },
    include_cols = id_col,
    summarize_df = TRUE,   # 👈 required for function(df, ...) signature
    progress     = FALSE
  )
  
  res %>%
    purrr::compact() %>%
    dplyr::bind_rows() %>%
    dplyr::mutate(value = as.integer(value)) %>%
    dplyr::relocate(!!rlang::sym(id_col))
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# phzm_summary(): compact PHZM zonal summary with auto-binning & labels
# ------------------------------------------------------------------------------
# Arguments:
#   r =                 Input raster. A single-band PHZM raster (SpatRaster from
#                       {terra}). Should contain the numeric zone codes
#                       (e.g., 5, 5.5, 6).
# zones =               Input layer file with polygons to summarize. Polygon
#                       zones (e.g., catchments, ecoregions, sites) over which
#                       the summarize the raster.
#                       Can be sf or SpatVector.
# id_col =              The join key. The name of the unique identifier column
#                       in zones that will be used to group results
#                       (default = "macro_id").
# min_prop =            Helps remove slivers. Minimum proportion threshold: drops
#                       categories that cover less than this fraction of the
#                       polygon.
#                       e.g. a global floor applied up front during the summary.
#                       Categories that cover less than this fraction of a
#                       polygon are ignored entirely when computing proportions.
#                       Example: if min_prop = 0.02, anything <2% of a zone just
#                       never enters the results table.
# drop_minor =          Helps remove slivers. If TRUE, removes very minor
#                       categories per polygon (based on drop_thresh).
# drop_thresh =         Helps remove slivers. Threshold for drop_minor: removes
#                       categories that occupy less than some percent of a zone,
#                       (0.05 is 5%).
#                       A post-processing cleanup. All categories are first
#                       tallied, then—if drop_minor = TRUE—categories with
#                       proportion < drop_thresh are removed from the final output.
#                       Example: if drop_thresh = 0.05, any categories <5% are
#                       stripped out after the full table has been built.
# auto_recode =         Controls value/label cleaning. If TRUE, the function will
#                       automatically recode PHZM raster values (e.g., USDA
#                       raster encodes 0.5 steps like 5a = 5.0, 5b = 5.5).
# temp_units =          Controls value/label cleaning. Unit system for labeling
#                       zones.
#                         - "auto" = whatever USDA uses (F, half-zones).
#                         - "C" or "F" = convert to Celsius or Fahrenheit
#                           equivalents if metadata supports it.
# force_recode =        Controls value/label cleaning. If TRUE, forces recoding
#                       of raster values even if they look correct already.
#                       Default is FALSE.
# label_cols =          If TRUE, adds human-readable label columns to the output
#                       (e.g., phzm_label = "Zone 5a").
# label_style =         Controls labeling style:
#                         - "short" = "5a".
#                         - "long" = "Zone 5a".
# return_halfzones =    Controls outputs. If TRUE, keeps half-zone detail
#                       (e.g., 5a, 5b → 5.0, 5.5).
#                       If FALSE, collapses to whole numbers.
# return_raster =       Controls outputs. If TRUE, also returns the recoded PHZM
#                       raster (useful for debugging or mapping). 
#                       If FALSE, returns only the summary table.
#
# The table returns one row per zone with:
#   id_col, phzm_dominant, phzm_dom_frac, phzm_class_count,
#   phzm_top1, phzm_top1_prop,
#   phzm_top2, phzm_top2_prop,
#   phzm_top3, phzm_top3_prop
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
phzm_summary <- function(
    r,
    zones,
    id_col           = "macro_id",
    min_prop         = 0,
    auto_recode      = TRUE,
    temp_units       = c("auto","C","F"),
    force_recode     = FALSE,
    return_halfzones = TRUE,   # 12.0/12.5/...
    label_cols       = TRUE,   # *_label columns
    label_style      = c("short","long"),  # "12b" | "Zone 12b"
    drop_minor       = TRUE,   # hide top1/top2/top3 < drop_thresh
    drop_thresh      = 0.05,
    return_raster    = FALSE
) {
  
  temp_units  <- match.arg(temp_units)
  label_style <- match.arg(label_style)
  
  if (terra::nlyr(r) != 1) r <- r[[1]]
  if (inherits(zones, "SpatVector")) zones <- sf::st_as_sf(zones)
  stopifnot(id_col %in% names(zones))
  
  # ---- 1) Decide whether to recode a temperature surface ---------------------
  recoded <- FALSE
  looks_halfzone_codes <- FALSE
  
  if (isTRUE(auto_recode) || isTRUE(force_recode)) {
    needs_recode <- force_recode || !terra::is.int(r)
    
    if (!needs_recode) {
      probe <- tryCatch(
        terra::values(r, n = 50000, na.rm = TRUE),
        error = function(e) numeric()
      )
      if (length(probe)) {
        looks_halfzone_codes <- all(probe >= 1 & probe <= 26, na.rm = TRUE)
        needs_recode <- !looks_halfzone_codes
      }
    }
    
    rng <- tryCatch({
      m <- terra::global(r, fun = "range", na.rm = TRUE)
      as.numeric(m[1, ])
    }, error = function(e) c(NA_real_, NA_real_))
    
    to_f <- switch(
      temp_units,
      C    = function(x) x * 9/5 + 32,
      F    = function(x) x,
      auto = {
        if (is.finite(rng[2]) && rng[2] < 60) {
          function(x) x * 9/5 + 32
        } else {
          function(x) x
        }
      }
    )
    
    if (needs_recode) {
      r <- terra::app(
        r,
        fun = function(x) {
          ifelse(
            is.na(x),
            NA_integer_,
            {
              f   <- to_f(x)
              z   <- floor((f + 60) / 10) + 1        # 1..13
              z   <- pmax(1, pmin(13, z))
              isb <- ((f + 60) %% 10) >= 5
              as.integer(z * 2 + as.integer(isb))    # 1..26
            }
          )
        }
      )
      recoded <- TRUE
      looks_halfzone_codes <- TRUE
    }
  }
  
  # ---- 2) Summarizer over polygons ------------------------------------------
  summarizer <- function(df) {
    
    v  <- df[[1]]
    w  <- if (!is.null(df$coverage_fraction)) df$coverage_fraction else rep(1, length(v))
    ok <- !is.na(v) & !is.na(w)
    
    if (!any(ok)) {
      return(c(
        dom = NA_real_, dom_frac = NA_real_, class_count = 0,
        top1 = NA_real_, top1_prop = NA_real_,
        top2 = NA_real_, top2_prop = NA_real_,
        top3 = NA_real_, top3_prop = NA_real_
      ))
    }
    
    if (is.factor(v)) v <- as.integer(v)
    
    sums <- tapply(w[ok], v[ok], sum)
    
    if (length(sums) == 0 || sum(sums) <= 0) {
      return(c(
        dom = NA_real_, dom_frac = NA_real_, class_count = 0,
        top1 = NA_real_, top1_prop = NA_real_,
        top2 = NA_real_, top2_prop = NA_real_,
        top3 = NA_real_, top3_prop = NA_real_
      ))
    }
    
    tot    <- sum(sums)
    props  <- sums / tot
    dom_id <- as.numeric(names(which.max(sums)))
    dom_fr <- as.numeric(max(sums) / tot)
    k      <- length(sums)
    
    ord  <- order(props, decreasing = TRUE)
    vals <- as.numeric(names(props)[ord])
    prps <- as.numeric(props[ord])
    
    keep <- prps >= min_prop
    vals <- vals[keep]
    prps <- prps[keep]
    
    # pad to top 3
    vals <- c(vals, NA_real_, NA_real_, NA_real_)[1:3]
    prps <- c(prps, NA_real_, NA_real_, NA_real_)[1:3]
    
    c(
      dom = dom_id, dom_frac = dom_fr, class_count = k,
      top1 = vals[1], top1_prop = prps[1],
      top2 = vals[2], top2_prop = prps[2],
      top3 = vals[3], top3_prop = prps[3]
    )
  }
  
  out <- exactextractr::exact_extract(
    r,
    zones,
    fun          = summarizer,
    progress     = FALSE,
    summarize_df = TRUE
  )
  
  # ---- Normalize output shape/names (bullet-proof) ---------------------------
  expected <- c(
    "dom","dom_frac","class_count",
    "top1","top1_prop",
    "top2","top2_prop",
    "top3","top3_prop"
  )
  
  out_df <- tryCatch(
    as.data.frame(out, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  
  if (is.null(out_df) || ncol(out_df) != length(expected)) {
    vec <- suppressWarnings(as.numeric(unlist(out)))
    nrow_guess <- if (length(vec)) length(vec) / length(expected) else 1
    nrow_guess <- if (is.finite(nrow_guess) && nrow_guess >= 1) nrow_guess else 1
    out_df <- as.data.frame(
      matrix(vec, ncol = length(expected), byrow = TRUE),
      stringsAsFactors = FALSE
    )
  }
  
  colnames(out_df) <- expected
  for (nm in expected) {
    out_df[[nm]] <- suppressWarnings(as.numeric(out_df[[nm]]))
  }
  
  # ---- 3) Optional: drop minor top-N (threshold) -----------------------------
  if (isTRUE(drop_minor)) {
    out_df$top1      <- ifelse(out_df$top1_prop >= drop_thresh, out_df$top1, NA_real_)
    out_df$top1_prop <- ifelse(is.na(out_df$top1), NA_real_, out_df$top1_prop)
    
    out_df$top2      <- ifelse(out_df$top2_prop >= drop_thresh, out_df$top2, NA_real_)
    out_df$top2_prop <- ifelse(is.na(out_df$top2), NA_real_, out_df$top2_prop)
    
    out_df$top3      <- ifelse(out_df$top3_prop >= drop_thresh, out_df$top3, NA_real_)
    out_df$top3_prop <- ifelse(is.na(out_df$top3), NA_real_, out_df$top3_prop)
  }
  
  # ---- 4) Convert classes to half-zone numbers (12.5) if we have codes -------
  vals_are_halves <- FALSE
  if (isTRUE(return_halfzones) && (recoded || looks_halfzone_codes)) {
    
    halfify <- function(x) ifelse(is.na(x), NA_real_, x / 2)
    
    out_df$dom  <- halfify(out_df$dom)
    out_df$top1 <- halfify(out_df$top1)
    out_df$top2 <- halfify(out_df$top2)
    out_df$top3 <- halfify(out_df$top3)
    
    vals_are_halves <- TRUE
  }
  
  # ---- 5) Human-readable labels (robust) ------------------------------------
  .label_from_codes <- function(code, style = c("short","long")) {
    style <- match.arg(style)
    z     <- floor(code / 2)
    is_b  <- (code %% 2) == 1
    lab   <- paste0(z, ifelse(is_b, "b", "a"))
    if (style == "long") paste("Zone", lab) else lab
  }
  
  .label_from_halves <- function(half, style = c("short","long")) {
    style <- match.arg(style)
    z     <- floor(half)
    is_b  <- abs(half - z - 0.5) < 1e-8
    lab   <- paste0(z, ifelse(is_b, "b", "a"))
    if (style == "long") paste("Zone", lab) else lab
  }
  
  add_labels <- function(df_vals) {
    lab_fun <- if (vals_are_halves) .label_from_halves else .label_from_codes
    tibble::tibble(
      phzm_dominant_label = ifelse(is.na(df_vals$dom),  NA_character_, lab_fun(df_vals$dom,  label_style)),
      phzm_top1_label     = ifelse(is.na(df_vals$top1), NA_character_, lab_fun(df_vals$top1, label_style)),
      phzm_top2_label     = ifelse(is.na(df_vals$top2), NA_character_, lab_fun(df_vals$top2, label_style)),
      phzm_top3_label     = ifelse(is.na(df_vals$top3), NA_character_, lab_fun(df_vals$top3, label_style))
    )
  }
  
  # ---- 6) Build/return -------------------------------------------------------
  out_tbl <- tibble::tibble(
    !!id_col             := zones[[id_col]],
    phzm_dominant        = out_df[["dom"]],
    phzm_dom_frac        = out_df[["dom_frac"]],
    phzm_class_count     = out_df[["class_count"]],
    phzm_top1            = out_df[["top1"]],
    phzm_top1_prop       = out_df[["top1_prop"]],
    phzm_top2            = out_df[["top2"]],
    phzm_top2_prop       = out_df[["top2_prop"]],
    phzm_top3            = out_df[["top3"]],
    phzm_top3_prop       = out_df[["top3_prop"]]
  )
  
  if (isTRUE(label_cols)) {
    out_tbl <- dplyr::bind_cols(out_tbl, add_labels(out_df))
  }
  
  if (isTRUE(return_raster)) {
    return(list(tbl = out_tbl, r_recoded = r))
  } else {
    return(out_tbl)
  }
}






#' Area-weighted counts by category per zone (long table)
#'
#' @param r A single-band categorical `terra::SpatRaster`.
#' @param zones `sf` polygons (same CRS as `r`).
#' @param id_col Name of the identifier column in `zones`.
#'
#' @return Tibble with columns: `id_col`, `value` (class), `area` (weighted sum).
#' @export

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
category_counts <- function(
    r,
    zones,
    id_col   = "macro_id",
    progress = FALSE
) {
  
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r)
  .assert_has_id(zones_sf, id_col)
  
  if (terra::nlyr(r) != 1L) {
    r <- r[[1L]]
  }
  
  # vector signature EXACTLY as required: (values, coverage_fractions, ...)
  res <- exactextractr::exact_extract(
    r,
    zones_sf,
    fun = function(values, coverage_fractions, ...) {
      ok <- !is.na(values)
      if (!any(ok)) {
        return(NULL)
      }
      
      vv <- as.integer(values[ok])
      ww <- coverage_fractions[ok]
      
      s <- rowsum(ww, group = vv, reorder = FALSE)
      
      tibble::tibble(
        value = as.integer(rownames(s)),
        area  = as.numeric(s[, 1L])
      )
    },
    summarize_df = FALSE,
    progress     = progress
  )
  
  ids <- zones_sf[[id_col]]
  
  purrr::map2(
    res,
    ids,
    ~ if (is.null(.x)) {
      NULL
    } else {
      dplyr::mutate(.x, !!id_col := .y)
    }
  ) %>%
    purrr::compact() %>%
    dplyr::bind_rows() %>%
    dplyr::relocate(!!rlang::sym(id_col)) %>%
    dplyr::mutate(value = as.integer(value))
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
