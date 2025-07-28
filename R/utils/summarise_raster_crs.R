# =============================================================================
# Script Name:     summarise_raster_crs.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-05-15
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-28     Update header information.
#
# Purpose:         Summarize CRS from raster files (.tif and .bil). The function
#                  Returns a tibble of CRS given an input directory with raster
#                  files, and writes a summary log.
#
# Input/Data URLs:
# - User-defined raster directory (e.g., "data/processed/prism")
# Output:
#   - tibble of results
#   - a log of the CRS for the user-defined raster directory.
#
# Dependencies:
# - dplyr, readr   Data manipulation, input and output.
# - fs             File operations.
# - here           Consistent relative paths.
# - purrr          Functional programming tools.
# - terra          Raster and vector geometric operations.
#
# Helper Functions:
#
# Related Milestone Reports:
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
