# ==============================================================================
# Script Name:     rast_summ_by_class.R
# Purpose:         Computes dominant class, i.e category, class counts, and
#                  class fractions with area-weighted exact extraction.
# Author:          CJ Tinant (with Gepeto) — GPT 4o and GPT 5 - thinking
# Date Created:    2025-08-07
# Last Updated:    2025-10-02
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
#                  to an abort. The function hard-caps memory by tiling the raster
#                  and summing results across tiles to avoid any single
#                  exact_extract() run building huge working sets.
# - 2025-09-22     Added a bug-fixs to category_counts_tiled() function to fix
#                  (I) a “length mismatch” at the root by: (1) always validating
#                  geometry,(2) optionally dissolving to one row per id_col,
#                  (3) using include_cols = id_col so IDs are never “attached”
#                  post-hoc, and (4) computing area with include_area = TRUE to
#                  just sum coverage_area, safely aggregates across tiles.
#                  (II ) to remove dependency on cell_area column; compute pixel
#                  area from raster res; use summarize_df=TRUE with ID carried
#                  via include_cols; derive constant cell area from terra::res()
#                  for NLCD/Albers tiles; fallback to provided cell_area when
#                  available; guard against lon/lat rasters.
# - 2025-10-02     Added nlcd_fractions_tiled(). Standardized individual function
#                  metadata.
#
# Discussion:
# The helper functions are thin wrappers for {exactextractr}. They define the
# project’s API (id column first, tidy tibbles, naming), can be used to
# compute multiple outputs from one pass, e.g. NDVI classes, and to return
# the dominance fraction. Calculation is delegated to {exactextractr}, which is
# able to reliably handle edge cases such as:partial pixels, holes, multi-part
# polygons, anti-meridian weirdness, etc.
#
# See individual helper functions for User Inputs and Function Outputs.
#
# ==============================================================================
# Function: nlcd_fractions_tiled()
# Purpose : Area-weighted NLCD class fractions by zone (robust tiling workflow)
# Inputs  :
#   r               SpatRaster or path to NLCD (categorical; keep native grid)
#   zones           sf/sfc object OR path to vector; if path, supply 'layer'
#   layer           layer name if 'zones' is a path to a GPKG
#   id_col          zone ID column (default: "macro_id")
#   allowed_codes   integer NLCD codes to keep
#   nx, ny          tile grid (increase if memory is tight; e.g., 10, 10)
#   simplify_tol    meters; simplify zones before tiling (0 = none)
#   memfrac         terra mem fraction hint
#   progress        logical; print per-tile progress
# Outputs :
#   A list with:
#     $long  = tibble(id_col, code, prop)
#     $wide  = tibble(one row/zone; columns nlcd_frac_<code>)
#     $qa    = tibble(id_col, sum_prop)   # should be ~1
# Dependencies: here, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
#   - Do NOT reproject the NLCD. Transform zones to the raster CRS.
#   - Requires integer NLCD (e.g., *_nn.tif). Will stop() otherwise.
#   - Tiling avoids giant per-cell tables and OOM/aborts.
# ==============================================================================

nlcd_fractions_tiled <- function(
    r,
    zones,
    layer           = NULL,
    id_col          = "macro_id",
    allowed_codes   = c(11,12,21,22,23,24,31,41,42,43,52,71,81,82,90,95),
    nx              = 8,
    ny              = 8,
    simplify_tol    = 0,
    memfrac         = 0.6,
    progress        = TRUE
) {
  
  suppressPackageStartupMessages({
    library(sf)
    library(terra)
    library(tidyverse)
    library(exactextractr)
  })
  
  `%||%` <- function(a, b) if (!is.null(a)) a else b
  set.seed(42)
  terra::terraOptions(memfrac = memfrac, todisk = TRUE, progress = as.integer(progress))
  options(exactextractr.max_cells_in_memory = 1e7)
  
  # ---- 0) Ingest ----------------------------------------------------------------
  
  # Raster
  r <- if (inherits(r, "SpatRaster")) r else terra::rast(r)
  if (!grepl("^INT", terra::datatype(r))) {
    stop("NLCD raster must be integer (INT*). Got: ", terra::datatype(r),
         ". Use the categorical LandCover (e.g., *_nn.tif).")
  }
  
  # Zones
  if (inherits(zones, "character")) {
    if (is.null(layer)) stop("zones is a path; please supply 'layer'.")
    zones <- sf::st_read(zones, layer = layer, quiet = !progress)
  }
  stopifnot(inherits(zones, "sf"))
  stopifnot(id_col %in% names(zones))
  
  # CRS align (vector -> raster)
  zones <- zones %>%
    sf::st_make_valid() %>%
    sf::st_transform(terra::crs(r))
  
  # Enforce 'geom' active geometry if present per project convention
  if ("geometry" %in% names(zones)) {
    zones <- dplyr::rename(zones, geom = geometry)
    sf::st_geometry(zones) <- "geom"
  }
  
  # Optional simplify (pre-tiling)
  if (simplify_tol > 0) {
    zones <- sf::st_simplify(zones, dTolerance = simplify_tol, preserveTopology = TRUE)
  }
  
  # ---- 1) Tiler -----------------------------------------------------------------
  
  make_tiles <- function(x, nx = 8, ny = 8, crs = NULL) {
    if (inherits(x, "bbox")) {
      bb  <- x
      crs <- crs %||% sf::st_crs(NA)
    } else if (inherits(x, "sf") || inherits(x, "sfc")) {
      bb  <- sf::st_bbox(x)
      crs <- crs %||% sf::st_crs(x)
    } else if (inherits(x, "SpatRaster") || inherits(x, "SpatVector")) {
      e   <- terra::ext(x)
      bb  <- c(xmin = e$xmin, ymin = e$ymin, xmax = e$xmax, ymax = e$ymax)
      crs <- crs %||% sf::st_crs(terra::crs(x))
    } else {
      stop("Unsupported input to make_tiles().")
    }
    
    xs <- seq(bb[["xmin"]], bb[["xmax"]], length.out = nx + 1L)
    ys <- seq(bb[["ymin"]], bb[["ymax"]], length.out = ny + 1L)
    
    bbox_to_sfg <- function(xmin, ymin, xmax, ymax, crs) {
      sf::st_as_sfc(
        sf::st_bbox(c(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax), crs = crs)
      )[[1]]
    }
    
    grid <- expand.grid(ix = seq_len(nx), iy = seq_len(ny))
    polys_sfg <- purrr::pmap(
      grid,
      \(ix, iy) bbox_to_sfg(xs[ix], ys[iy], xs[ix + 1L], ys[iy + 1L], crs)
    )
    
    sf::st_sf(
      tile_id = seq_along(polys_sfg),
      geom    = sf::st_sfc(polys_sfg, crs = crs)
    )
  }
  
  tiles <- make_tiles(zones, nx = nx, ny = ny)
  
  # ---- 2) Summarizer (df form; exactextractr passes columns: value, coverage_fraction) ----
  
  summarize_codes <- function(df, ...) {
    df %>%
      dplyr::filter(!is.na(value)) %>%
      dplyr::mutate(code = as.integer(round(value))) %>%
      dplyr::count(code, wt = coverage_fraction, name = "w_sum") %>%
      dplyr::select(code, w_sum)
  }
  
  # ---- 3) Loop tiles -----------------------------------------------------------
  
  parts <- vector("list", nrow(tiles))
  
  s2_prev <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(s2_prev), add = TRUE)
  
  for (i in seq_len(nrow(tiles))) {
    
    tpoly <- tiles[i, ]
    
    # pick all zones that intersect this tile
    idx <- which(lengths(sf::st_intersects(zones, tpoly)) > 0L)
    if (length(idx) == 0L) next
    
    z_tile <-
      zones[idx, ] %>%
      sf::st_make_valid() %>%
      suppressWarnings(sf::st_intersection(tpoly)) %>%
      dplyr::filter(sf::st_is(geom, c("POLYGON","MULTIPOLYGON")),
                    sf::st_is_valid(geom))
    
    if (nrow(z_tile) == 0L) next
    
    r_tile <- try(terra::crop(r, terra::ext(sf::st_bbox(tpoly))), silent = TRUE)
    if (inherits(r_tile, "try-error")) next
    
    res_list <- try(
      exactextractr::exact_extract(
        r_tile, z_tile,
        summarize_df = TRUE, progress = FALSE, fun = summarize_codes
      ),
      silent = TRUE
    )
    if (inherits(res_list, "try-error")) next
    if (is.data.frame(res_list)) res_list <- list(res_list)
    if (length(res_list) == 0L) next
    
    res_tile <- purrr::imap_dfr(
      res_list,
      ~ {
        x <- .x; j <- .y
        if (is.null(x) || !is.data.frame(x) || nrow(x) == 0L) return(NULL)
        dplyr::mutate(x, !!rlang::sym(id_col) := z_tile[[id_col]][[j]])
      }
    )
    
    if (nrow(res_tile) > 0L) {
      parts[[i]] <- res_tile %>% dplyr::filter(code %in% allowed_codes)
    }
    
    if (progress) {
      message(sprintf("Tile %d/%d: %d rows",
                      i, nrow(tiles), ifelse(is.null(parts[[i]]), 0L, nrow(parts[[i]]))))
    }
    if (i %% 8 == 0) { gc(); Sys.sleep(0.02) }
  }
  
  # ---- 4) Combine tiles -> per-zone fractions ---------------------------------
  
  nlcd_counts <-
    parts %>%
    purrr::compact() %>%
    dplyr::bind_rows() %>%
    dplyr::group_by(!!rlang::sym(id_col), code) %>%
    dplyr::summarise(w_sum = sum(w_sum), .groups = "drop")
  
  if (nrow(nlcd_counts) == 0L) {
    stop("No NLCD counts produced. Check inputs, tiling, and code filters.")
  }
  
  nlcd_long <-
    nlcd_counts %>%
    dplyr::group_by(!!rlang::sym(id_col)) %>%
    dplyr::mutate(prop = w_sum / sum(w_sum)) %>%
    dplyr::ungroup() %>%
    dplyr::select(!!rlang::sym(id_col), code, prop)
  
  nlcd_wide <-
    nlcd_long %>%
    tidyr::pivot_wider(
      names_from   = code,
      values_from  = prop,
      values_fill  = 0,
      names_prefix = "nlcd_frac_"
    ) %>%
    dplyr::arrange(!!rlang::sym(id_col))
  
  qa_sum <-
    nlcd_long %>%
    dplyr::group_by(!!rlang::sym(id_col)) %>%
    dplyr::summarise(sum_prop = sum(prop), .groups = "drop")
  
  if (any(abs(qa_sum$sum_prop - 1) > 1e-6)) {
    warning("Some zones have NLCD fractions that do not sum to 1. ",
            "Check geometry validity or nodata at the AOI edge.")
  }
  
  list(
    long = nlcd_long,
    wide = nlcd_wide,
    qa   = qa_sum
  )
}

# ==============================================================================
# Function: dominant_category
# Purpose : Use area weights to give the majority class or dominant (modal)
#           category
# Inputs  :
#   r               A single-band categorical `terra::SpatRaster`.
#   zones           `sf` polygons (same CRS as `r`) or `SpatVector`.
#   id_col         Name of the identifier column in `zones`.
# Outputs :
#   Tibble with columns:
#     $id_col      zone identifier
#     $.dominant   integer class code of the weighted mode
#     $.dom_frac   dominance fraction in [0,1] = 
#                            (area of modal class) / (area of all classes)
# Dependencies: exactextractr,  purrr
# Notes:
# Dominance fraction is a clean way to measure confidence in the modal class.
# If a macrozone is ~95% one class, the “dominant” label is very representative;
# if it’s ~55%, that’s basically a coin toss.
# ==============================================================================

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
# Function: category_counts_tiled()
# Purpose: area-weighted counts for categorical rasters (e.g., NLCD),
#          robust to very large rasters and many polygons. Uses low-RAM,
#          tile-wise categorical tallies
# Inputs  :
#   r                   SpatRaster or path
#   zones               sf/sfc object OR path to vector; if path, supply 'layer'
#   id_col              zone ID column (default: "macro_id")
#   nx, ny              tile grid (increase if memory is tight; e.g., 10, 10)
#   zones_simplify_tol  meters; simplify zones before tiling (0 = none)
#   tmp_dir             = here::here("tmp", "zonal_partials"),
# Outputs :
#
# Dependencies: here, fs, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
#   - Vector-signature summarizer (values, coverage_fractions, ...)
#   - Tiled raster processing; sum across tiles at the end.
#   - Writes per-tile partials to disk to cap heap growth.
#   - Uses %>% and vertical formatting (ADHD-friendly).
# ==============================================================================

category_counts_tiled <- function(
    r,
    zones,
    id_col              = "macro_id",
    nx                  = 6,
    ny                  = 6,
    zones_simplify_tol  = 0,
    dissolve_by_id      = TRUE,
    tmp_dir             = here::here("tmp", "zonal_partials"),
    progress            = FALSE
) {
  
  # ---- inputs & guards --------------------------------------------------------
  zones_sf <- .ensure_sf_polygons(zones)
  .assert_single_band(r)
  .assert_has_id(zones_sf, id_col)
  
  if (terra::nlyr(r) != 1L) {
    r <- r[[1L]]
  }
  
  # integer categories; encourage disk I/O
  r <- terra::as.int(r)
  terra::terraOptions(memfrac = 0.6)
  fs::dir_create(tmp_dir)
  
  # S2 off for robust polygon ops
  s2_prev <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  on.exit({ sf::sf_use_s2(s2_prev) }, add = TRUE)
  
  # Always validate; simplify if requested
  zones_sf <- zones_sf %>%
    sf::st_make_valid()
  
  if (zones_simplify_tol > 0) {
    zones_sf <- zones_sf %>%
      sf::st_simplify(
        dTolerance       = zones_simplify_tol,
        preserveTopology = TRUE
      )
  }
  
  # Optional dissolve to guarantee one feature per id
  if (isTRUE(dissolve_by_id)) {
    zones_sf <- zones_sf %>%
      dplyr::select(!!rlang::sym(id_col)) %>%
      dplyr::group_by(!!rlang::sym(id_col)) %>%
      dplyr::summarise(do_union = TRUE, .groups = "drop") %>%
      sf::st_make_valid()
  }
  
  # ---- tile grid --------------------------------------------------------------
  e  <- terra::ext(r)
  dx <- (e$xmax - e$xmin) / nx
  dy <- (e$ymax - e$ymin) / ny
  
  tiles <-
    tidyr::expand_grid(
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
  
  # ---- per-tile loop ----------------------------------------------------------
  for (k in seq_len(nrow(tiles))) {
    
    tk   <- tiles[k, ]
    extk <- terra::ext(tk$xmin, tk$xmax, tk$ymin, tk$ymax)
    
    r_k <- try(terra::crop(r, extk, snap = "out"), silent = TRUE)
    if (inherits(r_k, "try-error") || is.null(r_k)) next
    if (is.na(terra::ncell(r_k)) || terra::ncell(r_k) == 0) next
    
    # Prefer raster extent intersect (tighter than raw bbox)
    ext_poly <- sf::st_as_sfc(
      sf::st_bbox(terra::ext(r_k), crs = sf::st_crs(zones_sf))
    )
    
    sel <- sf::st_intersects(zones_sf, ext_poly, sparse = TRUE) %>%
      lengths() > 0
    
    if (!any(sel)) next
    
    z_k <- zones_sf[sel, , drop = FALSE]
    
    # ---- exact_extract with id carried in, and coverage area -----------------
    # Guard: we expect projected (meters) — NLCD is Albers/5070.
    if (terra::is.lonlat(r_k)) {
      stop("Raster is in lon/lat. Reproject to an equal-area CRS (e.g., EPSG:5070) before extraction.")
    }
    
    # Constant cell area for this tile (m²) = xres * yres in projected CRS
    area_per_cell_k <- abs(prod(terra::res(r_k)))
    
    res_k <- exactextractr::exact_extract(
      r_k,
      z_k,
      include_cols = id_col,   # carry IDs inside the DF
      # (Do NOT rely on include_cell_area; some versions don't emit it.)
      summarize_df = TRUE,     # we pass a data-frame function(df, ...)
      progress     = progress,
      fun = function(df, ...) {
        # df has: value, coverage_fraction, and id_col; may or may not have cell_area
        if (!("value" %in% names(df) && "coverage_fraction" %in% names(df) && id_col %in% names(df))) {
          return(NULL)
        }
        
        # if cell_area is missing, fall back to constant area from raster resolution
        if (!"cell_area" %in% names(df)) {
          df$cell_area <- area_per_cell_k
        }
        
        df %>%
          dplyr::filter(!is.na(.data$value)) %>%
          dplyr::mutate(coverage_area = .data$coverage_fraction * .data$cell_area) %>%
          dplyr::group_by(.data[[id_col]], .data$value) %>%
          dplyr::summarise(area = sum(.data$coverage_area, na.rm = TRUE), .groups = "drop")
      }
    )
    # Combine polygon-wise results for this tile
    part_k <-
      res_k %>%
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
  
  # vroom if available; otherwise batch read
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
        value    = as.integer(.data$value),
        area     = as.numeric(.data$area)
      ) %>%
      dplyr::group_by(!!rlang::sym(id_col), .data$value) %>%
      dplyr::summarise(area = sum(.data$area, na.rm = TRUE), .groups = "drop") %>%
      dplyr::relocate(!!rlang::sym(id_col))
    
  } else {
    
    batch_ids <- split(seq_along(part_files), ceiling(seq_along(part_files) / 50))
    
    partial_reduced <-
      purrr::map(batch_ids, function(ii) {
        purrr::map(part_files[ii], readr::read_csv, show_col_types = FALSE) %>%
          dplyr::bind_rows() %>%
          dplyr::mutate(
            !!id_col := as.integer(.data[[id_col]]),
            value    = as.integer(.data$value),
            area     = as.numeric(.data$area)
          ) %>%
          dplyr::group_by(!!rlang::sym(id_col), .data$value) %>%
          dplyr::summarise(area = sum(.data$area, na.rm = TRUE), .groups = "drop")
      }) %>%
      dplyr::bind_rows()
    
    final <-
      partial_reduced %>%
      dplyr::group_by(!!rlang::sym(id_col), .data$value) %>%
      dplyr::summarise(area = sum(.data$area, na.rm = TRUE), .groups = "drop") %>%
      dplyr::relocate(!!rlang::sym(id_col))
  }
  
  final
}

# ==============================================================================
# Function: category_counts():
# Purpose : Area-weighted category tallies with strict memory bounds
# Inputs  :
# Outputs :
# Dependencies: here, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
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

# ==============================================================================
# Function: top_n_categories(): 
# Purpose : Top-N classes per polygon with proportions
# Inputs  :
#   r               SpatRaster or path to NLCD (categorical; keep native grid)
#   zones           sf/sfc object OR path to vector; if path, supply 'layer'
#   id_col          zone ID column (default: "macro_id")
#   n
# Outputs :
# Dependencies: here, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
# The top_n_categories() returns top-N classes and their proportions per zone,
# using area-weighted counts from category_counts() to explore heterogeneous
# zones where a single dominant category is not representative.
# ==============================================================================
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

# ==============================================================================
# Function: phzm_summary()
# Purpose : Compact PHZM zonal summary with auto-binning & labels
# Inputs / Arguments:
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
# Outputs :
# The table returns one row per zone with:
#   id_col, phzm_dominant, phzm_dom_frac, phzm_class_count,
#   phzm_top1, phzm_top1_prop,
#   phzm_top2, phzm_top2_prop,
#   phzm_top3, phzm_top3_prop
# Dependencies: here, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
# ==============================================================================

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

# ==============================================================================
# Function: category_counts()
# Purpose : Area-weighted counts by category per zone (long table)
# Inputs  :
#   r               A single-band categorical `terra::SpatRaster`.
#   zones           `sf` polygons (same CRS as `r`).
#   id_col          zone ID column (default: "macro_id")
# Outputs :
#   Tibble with columns: `id_col`, `value` (class), `area` (weighted sum).
# Dependencies: here, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
# ==============================================================================

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

# ==============================================================================
# Function: class_fraction()
# Purpose : Proportion of zone covered by selected classes
# Inputs  :
#   r               A single-band categorical `terra::SpatRaster`.
#   zones           `sf` polygons (same CRS as `r`).
#   classes         Integer vector of class codes to treat as 1.
#   id_col          zone ID column (default: "macro_id")
#   outname         Output column name for the fraction (default "prop").
# Outputs :
#    Tibble with columns: `id_col`, `out_name` (numeric fraction in [0,1]).
# Dependencies: here, sf, terra, exactextractr, tidyverse, purrr
# Notes   :
#   Reclassifies the raster to binary (1 = in `classes`, 0 = otherwise) and
#   computes the area-weighted mean, which equals the area fraction.
# ==============================================================================

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
