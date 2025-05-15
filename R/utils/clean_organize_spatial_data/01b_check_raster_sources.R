# ============================================================================
# Script Name:    01b_check_raster_sources.R
# Author:         CJ Tinant
# Date Created:   2025-04-21
# Purpose:        Quality assurance of raw raster layers for regional skew project
#
# Description:
#   - Recursively locate raster files in data/raw/raster_raw/
#   - Validate raster readability and extract key metadata:
#       * File format, resolution, CRS, extent, and nodata values
#   - Identify inconsistencies across raster layers (e.g., CRS, resolution)
#   - Export a summary CSV for review: to_check/raster_summary_qc.csv
#
# Input: 
#   - .bil or .tif raster files in data/raw/raster_raw/
#
# Output: 
#   - to_check/raster_summary_qc.csv
#
# Dependencies:
#   - terra
#   - fs
#   - here
#   - tidyverse
#
# Notes:
#   - Intended as part of milestone 01b (raster QA & organization)
#   - Large or invalid rasters will be flagged for manual review
# ============================================================================

library(terra)
library(fs)
library(here)
library(tidyverse)

# Get raster files (.bil and .tif)
raster_paths <- dir_ls(here("data/raw/raster_raw"), recurse = TRUE, regexp = "\\.(bil|tif)$")

# Summarize properties
raster_summary <- map_dfr(raster_paths, function(path) {
  tryCatch({
    r <- rast(path)
    tibble(
      file = path_file(path),
      format = tools::file_ext(path),
      nrow = nrow(r),
      ncol = ncol(r),
      resolution_x = res(r)[1],
      resolution_y = res(r)[2],
      crs = crs(r, describe = TRUE),
      nodata = terra::NAflag(r),
      xmin = ext(r)[1],
      xmax = ext(r)[2],
      ymin = ext(r)[3],
      ymax = ext(r)[4]
    )
  }, error = function(e) {
    tibble(file = path_file(path), error = e$message)
  })
})

library(tidyverse)

# Separate the crs list-column into individual columns
raster_summary_flat <- raster_summary %>%
  select(file, crs, nodata) %>%
  unnest_wider(crs, names_sep = "_") %>%
  mutate(
    crs_preview = coalesce(crs_name, crs_authority, crs_code, crs_area),
    crs_preview = str_trunc(as.character(crs_preview), 60),
    nodata = map_chr(nodata, ~ {
      tryCatch({
        val <- unlist(.x)
        if (length(val) == 1) as.character(val) else NA_character_
      }, error = function(e) NA_character_)
    })
  )

raster_summary_flat

raster_summary_flagged <- raster_summary_flat %>%
  mutate(
    crs_missing = is.na(crs_preview) | crs_preview %in% c("NAD83", "NA"),
    crs_note = if_else(crs_missing, "⚠️ Check or reproject", "✅ OK")
  )

raster_summary_flagged

raster_summary_flagged <- raster_summary_flagged %>%
  mutate(
    matches_5070 = str_detect(crs_preview, "5070|NAD83.*Albers")
  )


# Save
write_csv(raster_summary_flagged, here("to_check/raster_summary_qc.csv"))


