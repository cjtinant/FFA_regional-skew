# ==============================================================================
# Script Name:     assert_inputs_ok.R
# Purpose:         Pre-flight checks for zonal aggregation with polygon zones.
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-08-08
# Last Updated:    2025-08-29
# Change Log:
# - 2025-08-29     Updated the original script to increase functionality
#
# Discussion:      The original function was a single use helper function to
#                  "assert inputs are ok" prior to zonal aggregation with a
#                  custom macroregion. "Asserting inputs are ok" originally
#                  consisted of checking the file path and class, i.e. the vector
#                  type, and whether an ID column existed.
#
# Workflow Summary:
# 1. Verify that rasters can be opened.
# 2. Enforce CRS and polygonal geometry.
# 3. Standardize the geometry column as `geom`.
# 4. Guarantees unique, non-NA IDs.
# 5. Optionally reproject to the project CRS: NAD83 / EPSG:4269.
#
# User Inputs:
# - raster_paths  Character vector or named list of raster file paths
# - zones         sf or terra::SpatVector (POLYGON/MULTIPOLYGON)
# - req_cols      Required attribute columns in zones (e.g., "macro_id")
# - id_col        Stable unique ID column name to ensure/create
# - target_crs    EPSG; defaults to 4269 (NAD83) per project convention
#
# Function Outputs:
# - sf with geometry column named 'geom', reprojected to target_crs,
#   guaranteed unique non-NA id_col, ready for exactextractr or terra::extract.
# ==============================================================================

assert_inputs_ok <- function(raster_paths,
                             zones,
                             req_cols = character(),
                             id_col   = "macro_id",
                             target_crs = 4269,   # NAD83 / EPSG:4269 (project default)
                             enforce_unique = TRUE,
                             quiet    = FALSE) {
  
  # ---- 0) Dependencies -------------------------------------------------------
  if (!requireNamespace("terra", quietly = TRUE)) stop("Package 'terra' is required.")
  if (!requireNamespace("sf",    quietly = TRUE)) stop("Package 'sf' is required.")
  if (!quiet && requireNamespace("cli", quietly = TRUE)) {
    say <- function(msg) cli::cli_inform(c(">" = msg))  # pretty messages
  } else {
    say <- function(msg) invisible(msg)
  }
  
  # ---- 1) Normalize raster paths & check existence/readability ---------------
  if (is.list(raster_paths)) raster_paths <- unlist(raster_paths, use.names = TRUE)
  raster_paths <- as.character(raster_paths)
  
  if (length(raster_paths) == 0L) stop("`raster_paths` is empty.")
  
  missing_files <- raster_paths[!file.exists(raster_paths)]
  if (length(missing_files)) {
    stop("Missing raster file(s):\n  - ", paste(missing_files, collapse = "\n  - "))
  }
  
  can_open <- vapply(raster_paths, function(p) {
    ok <- TRUE
    tryCatch({
      r <- terra::rast(p)
      if (is.null(dim(r))) ok <- FALSE
    }, error = function(e) ok <<- FALSE, warning = function(w) NULL)
    ok
  }, logical(1))
  if (!all(can_open)) {
    bad <- raster_paths[!can_open]
    stop("Unreadable raster file(s) (terra::rast failed):\n  - ", paste(bad, collapse = "\n  - "))
  }
  
  # ---- 2) Zones type, polygonal geometry, CRS, geometry column name ----------
  z <- zones
  if (inherits(z, "SpatVector")) z <- sf::st_as_sf(z)
  if (!inherits(z, "sf")) stop("`zones` must be an sf or SpatVector object.")
  
  gcls <- unique(sf::st_geometry_type(z, by_geometry = TRUE))
  if (!all(gcls %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("`zones` must be polygonal; found: ", paste(gcls, collapse = ", "))
  }
  
  if (is.na(sf::st_crs(z))) stop("`zones` has no CRS; expected EPSG:", target_crs, ".")
  
  if (sf::st_crs(z)$epsg != target_crs) {
    z <- sf::st_transform(z, target_crs)
    say(paste0("Reprojected zones to EPSG:", target_crs))
  }
  
  # enforce preferred geometry column name 'geom' (project convention)
  if (!identical(attr(z, "sf_column"), "geom")) {
    old_geom <- attr(z, "sf_column")
    names(z)[names(z) == old_geom] <- "geom"
    sf::st_geometry(z) <- "geom"
  }
  
  # ---- 3) Required columns ---------------------------------------------------
  if (length(req_cols)) {
    missing_cols <- setdiff(req_cols, names(z))
    if (length(missing_cols)) {
      stop("`zones` missing required column(s): ", paste(missing_cols, collapse = ", "))
    }
  }
  
  # ---- 4) Ensure stable unique ID -------------------------------------------
  if (!id_col %in% names(z)) {
    z[[id_col]] <- seq_len(nrow(z))
    say(paste0("Created id_col '", id_col, "' via row_number()."))
  }
  
  # coerce numeric IDs to integer
  if (is.numeric(z[[id_col]]) && !is.integer(z[[id_col]])) {
    z[[id_col]] <- as.integer(z[[id_col]])
  }
  
  if (enforce_unique) {
    if (anyDuplicated(z[[id_col]]) > 0) {
      z[[id_col]] <- seq_len(nrow(z))
      say(paste0("Detected duplicate IDs; regenerated sequential ", id_col, "."))
    }
  }
  
  if (any(is.na(z[[id_col]]))) stop("`", id_col, "` contains NA after enforcement.")
  
  # ---- 5) Optional: warn on clear CRS mismatches between rasters and zones ---
  # (terra/exactextractr can reproject on the fly, but early warning helps)
  # Read the first raster's CRS as a proxy
  r0 <- terra::rast(raster_paths[1])
  crs_r <- terra::crs(r0, proj=TRUE)
  if (!isTRUE(sf::st_is_longlat(z)) && grepl("longlat", crs_r, ignore.case = TRUE)) {
    say("Note: zones are projected but first raster is geographic (longlat). Check intended CRS mix.")
  }

  # added -- did not check on 2025-09-02
  # drop Z/M if present (can trip exactextractr)
  if (any(sf::st_is(z, c("POLYGON Z", "MULTIPOLYGON Z", "POLYGON M", "MULTIPOLYGON M",
                         "POLYGON ZM", "MULTIPOLYGON ZM")))) {
    z <- sf::st_zm(z, drop = TRUE, what = "ZM")
  }

# added -- did not check on 2025-09-02
  # ensure valid geometries (repair if needed)
  if (!all(sf::st_is_valid(z))) {
    if (!quiet) say("Found invalid geometries; repairing with st_make_valid().")
    z <- sf::st_make_valid(z)
  }

  # added -- did not check on 2025-09-02
  # ensure non-empty geometries
  if (any(sf::st_is_empty(z$geom))) {
    bad_n <- sum(sf::st_is_empty(z$geom))
    stop(bad_n, " zone geometries are empty after normalization.")
  }
   
  return(z)
}
