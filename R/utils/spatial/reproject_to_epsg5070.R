# =============================================================================
# Script Name:    reproject_to_epsg5070.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-05-12
# Last Updated:   2025-05-15           # 
# Purpose:        Helper function to reproject .bil files to EPSG5070
#
# Description:
#   - [Step 1: what the function does...]
#   - [Step 2: any side effects, file outputs, or key decisions]
#
# Input: 
#   - [e.g., File paths, data frames, raw XML, etc.]
#
# Output: 
#   - [e.g., A tibble, a CSV, a shapefile, etc.]
#
# Dependencies:
#   - [e.g., xml2, dplyr, terra, fs]
#
# Notes:
#   - [Optional: reference to related milestones, issues, or expected uses]
# =============================================================================
reproject_to_epsg5070 <- function(bil_files,
                                  out_dir = here::here("data/intermediate/prism_epsg5070"),
                                  log_path = here::here("data/log/prism_crs_log.csv")) {
  library(terra)
  library(fs)
  library(dplyr)
  
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
  readr::write_csv(crs_log, log_path)
  
  invisible(crs_log)
}








