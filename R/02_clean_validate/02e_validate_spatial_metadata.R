# ==============================================================================
# Script Name:    02e_validate_spatial_metadata.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-06-28
#
# Purpose:        Validate CRS, resolution, and spatial extent of all raster and 
#                 vector files in the `data/processed/` directory.
#
# Output:         CSV summary report saved to `data/meta/spatial_validation_summary.csv`
#
# Dependencies:
# - dplyr:         Data manipulation
# - fs             File system operations
# - glue           Formats strings
# - here:          Consistent relative paths: locate files relative to proj root
# - purrr          Functional programming toolkit
# - readr          Reads rectangular data
# - sf             Support for simple feature access, a standardized way to
#                    encode and analyze spatial vector data. Binds to 'GDAL'
# - terra:         Spatial data analysis-- wector and raster data operations
# ==============================================================================
library(dplyr)
library(fs)
library(glue)
library(purrr)
library(readr)
library(sf)
library(terra)

aoi <- sf::st_read("data/processed/ecoregions/us_eco_levels.gpkg",
                   layer = "us_eco_l1",
                   quiet = TRUE) %>%
  sf::st_transform(5070) %>%
  sf::st_union()  # dissolve to single polygon

# ------------------------------------------------------------------------------
# Define directories
# ------------------------------------------------------------------------------
dir_processed <- "data/processed"
dir_meta <- "data/meta"
dir_create(dir_meta)

# ------------------------------------------------------------------------------
# List files
# ------------------------------------------------------------------------------
raster_files <- dir_ls(dir_processed, recurse = TRUE, regexp = "\\.(tif|img|grd)$")
vector_files <- dir_ls(dir_processed, recurse = TRUE, regexp = "\\.(gpkg|shp)$")

# ------------------------------------------------------------------------------
# Function to get raster metadata
# ------------------------------------------------------------------------------
get_raster_info <- function(path) {
  r <- rast(path)
  crs_proj <- terra::crs(r, proj = TRUE)
  epsg <- try(terra::crs(r, describe = TRUE)$code, silent = TRUE)
  epsg <- ifelse(inherits(epsg, "try-error"), NA_integer_, epsg)
  
  # Convert raster extent to polygon
  bbox_poly <- sf::st_as_sfc(sf::st_bbox(r)) %>%
    sf::st_transform(5070)
  
  aoi_check <- sf::st_intersects(bbox_poly, aoi, sparse = FALSE)[1, 1]
  
  tibble(
    layer_name = path_file(path),
    type = "raster",
    crs = crs_proj,
    resolution = paste(res(r), collapse = " x "),
    extent = paste(ext(r), collapse = ", "),
    crs_check = epsg == 5070,
    aoi_check = aoi_check,
    notes = NA
  )
}

# ------------------------------------------------------------------------------
# Function to get vector metadata
# ------------------------------------------------------------------------------

fail_log <- list()  # Initialize the failure log outside the function

get_vector_info <- function(path) {
  ext <- tools::file_ext(path)
  file_id <- path_file(path)
  
  # Try to get layers if it's a GPKG
  if (tolower(ext) == "gpkg") {
    layer_names <- try(sf::st_layers(path)$name, silent = TRUE)
    if (inherits(layer_names, "try-error")) {
      warning(glue("⚠️ Could not open GPKG file: {file_id}. Skipping."))
      
      # Log file-level failure
      fail_log[[length(fail_log) + 1]] <<- tibble(
        file = file_id,
        layer = NA_character_,
        reason = "file_open_error"
      )
      
      return(NULL)
    }
  } else {
    layer_names <- NA_character_
  }
  
  # Try to read each layer
  map_dfr(layer_names, function(layer_name) {
    v <- try(sf::st_read(path, layer = layer_name, quiet = TRUE), silent = TRUE)
    if (inherits(v, "try-error")) {
      warn_msg <- glue("⚠️ Failed to read layer '{layer_name}' from {file_id}. Skipping.")
      warning(warn_msg)
      
      # Log layer-level failure
      fail_log[[length(fail_log) + 1]] <<- tibble(
        file = file_id,
        layer = layer_name,
        reason = "read_error"
      )
      
      return(NULL)
    }
    
    epsg <- st_crs(v)$epsg
    bbox_poly <- sf::st_as_sfc(sf::st_bbox(v)) %>%
      sf::st_transform(5070)
    aoi_check <- sf::st_intersects(bbox_poly, aoi, sparse = FALSE)[1, 1]
    
    tibble(
      layer_name = paste(file_id, layer_name, sep = "::"),
      type = "vector",
      crs = st_crs(v)$input,
      resolution = NA,
      extent = paste(st_bbox(v), collapse = ", "),
      crs_check = epsg == 5070,
      aoi_check = aoi_check,
      notes = NA
    )
  })
}

# ------------------------------------------------------------------------------
# Apply functions
# ------------------------------------------------------------------------------
raster_meta <- map_dfr(raster_files, get_raster_info)
vector_meta <- map_dfr(vector_files, get_vector_info)

# ------------------------------------------------------------------------------
# Combine, deduplicate, export
# ------------------------------------------------------------------------------
summary_tbl <- bind_rows(raster_meta, vector_meta) %>%
  distinct(layer_name, .keep_all = TRUE)

write_csv(summary_tbl, file.path(dir_meta, "spatial_validation_summary.csv"))
message("✅ Spatial metadata summary saved to: data/meta/spatial_validation_summary.csv")

# Filter for rows that failed either check
flagged_tbl <- summary_tbl %>%
  filter(!crs_check | !aoi_check)

# Write filtered output
write_csv(flagged_tbl, "data/meta/spatial_validation_summary_flagged.csv")

message("✅ Flagged summary saved to: data/meta/spatial_validation_summary_flagged.csv")

# ------------------------------------------------------------------------------
# Check fails
# ------------------------------------------------------------------------------

if (length(fail_log) > 0) {
  fail_df <- bind_rows(fail_log)
  write_csv(fail_df, "data/intermediate/spatial_validation_vector_fail_log.csv")
  message("📁 Logged vector layer read failures to: data/intermediate/spatial_validation_vector_fail_log.csv")
} else {
  message("✅ No vector read failures encountered.")
}

st_layers("data/processed/nhdplus/flowlines_combined.gpkg")
