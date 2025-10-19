# =============================================================================
# Script Name:     reproject_bil_to_epsg5070.R
# Purpose:         Helper function to reproject .bil files to EPSG5070.
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-05-12
# Last Updated:    2025-08-29
# Change Log:
# - 2025-07-28     Update header information;
#                  Move notes to `script-notes_and_developer-log`.
#                  Update output to `data/raw/``
# - 2025-08-29     Rename function for clarity of use.
#
# Description:
#
# Workflow Summary:
# 1. Check if a .bil file already in EPSG:5070.
# 2. Reproject to EPSG:5070 if the .bil has another coordinate system.
# 3. Export reprojected files and log.
#
# User Inputs:
# - user-defined .bil file.
# Function Outputs:
# - reprojected .bil file saved to `data/raw/prism_epsg5070`.
#
# Depends: dplyr, fs, here, readr, terra
# =============================================================================
reproject_to_epsg5070 <- function(bil_files,
                                  out_dir = here("data/raw/prism_epsg5070"),
                                  log_path = here(
                                    "data/log/prism_crs_log.csv")) {
  library(dplyr)
  library(fs)
  library(here)
  library(readr)
  library(terra)

  dir_create(out_dir, recurse = TRUE)

  crs_log <- purrr::map_dfr(bil_files, function(f) {
    r <- rast(f)
    crs_original <- crs(r)

    # Check if it's already in EPSG:5070
    is_proj_5070 <- grepl("5070", crs_original) || grepl("Conus Albers", crs_original)

    # Output path
    fname_out <- path_file(f)
    fname_out <- path_ext_set(fname_out, "tif")
    out_path <- file.path(out_dir, fname_out)

    # Reproject if needed
    if (!is_proj_5070) {
      cat("Reprojecting:", fname_out, "\n")
      r_proj <- project(r, "EPSG:5070", method = "bilinear")
      writeRaster(r_proj, filename = out_path, overwrite = TRUE)
      crs_new <- crs(r_proj)
    } else {
      cat("Already EPSG:5070:", fname_out, "\n")
      file_copy(f, out_path, overwrite = TRUE)
      crs_new <- crs(r)
    }

    tibble(
      file = f,
      output = out_path,
      original_crs = crs_original,
      new_crs = crs_new
    )
  })

  # Save log
  write_csv(crs_log, log_path)

  invisible(crs_log)
}
