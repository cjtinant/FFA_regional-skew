# =============================================================================
# Script Name:    summarise_raster_crs.R
# Author:         CJ Tinant
# Date Created:   2025-05-15
# Last Updated:   [yyyy-mm-dd]
# Purpose:        Utility: Summarize CRS from raster files (.tif and .bil) 
#
# Description:
#   - Returns a tibble of CRS given an input directory with raster files.
#   - (Optional:) writes a summary log, if (write_log) = TRUE;
#       User can specify path if (write_log) = TRUE; 
#       Example: log_path = here::here("data/log/raster_crs_summary.csv")
#
# Input: 
#   - User-defined raster_dir (e.g., "data/processed/prism")
# Output: 
#   - tibble
#   - Optional: log.csv
#
# Dependencies:
#   - terra        # raster and vector geometric operations
#   - dplyr        # data manipulation
#   - purrr        # functional programming tools
#   - fs           # file operations
#   - readr        # read rectangular data
#
# Notes:
#   - Milestone 01
#
# =============================================================================

summarise_raster_crs <- function(
    raster_dir = here::here("data/processed/prism"),
    write_log = TRUE,
    log_path = here("data/log/raster_crs_summary.csv")
) {
  library(terra)
  library(dplyr)
  library(purrr)
  library(fs)
  library(readr)
  library(here)

  message("🔍 Searching for .tif and .bil files in: ", raster_dir)
  raster_files <- dir_ls(raster_dir, recurse = TRUE, type = "file") %>%
    keep(~ str_detect(.x, "\\.(tif|bil)$"))

  if (length(raster_files) == 0) {
    warning("⚠️ No .tif or .bil files found in: ", raster_dir)
    return(tibble())
  }

  message("📦 Processing ", length(raster_files), " raster files...")

  crs_summary <- map_dfr(raster_files, function(file) {
    tryCatch({
      r <- rast(file)
      tibble(
        file = path_file(file),
        path = path_abs(file),
        crs_name = crs(r, describe = TRUE),
        epsg = terra::crs(r, proj = TRUE),
        ncol = ncol(r),
        nrow = nrow(r),
        res_x = res(r)[1],
        res_y = res(r)[2]
      )
    }, error = function(e) {
      tibble(
        file = path_file(file),
        path = path_abs(file),
        crs_name = NA,
        epsg = NA,
        ncol = NA, nrow = NA,
        res_x = NA, res_y = NA
      )
    })
  })

  if (write_log) {
    dir_create(path_dir(log_path), recurse = TRUE)
    write_csv(crs_summary, log_path)
    message("✅ CRS summary written to: ", log_path)
  }

  return(crs_summary)
}