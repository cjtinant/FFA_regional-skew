# ==============================================================================
# Function: dedup_raster_inventory
# Purpose:  Inventory raster files, detect duplicates, optionally move .zip files,
#           and write summary CSVs for quality assurance.
# Author:   Charles Jason Tinant — with ChatGPT 4o
# Last Updated: 2025-07-08
# ==============================================================================

dedup_raster_inventory <- function(input_dir = "data/raw",
                                   output_dir = "to_check",
                                   archive_zips = TRUE,
                                   zip_subdir = "archives/raster_zips") {
  # Load required libraries
  library(fs)
  library(here)
  library(tidyverse)
  library(cli)
  
  # Define full paths
  input_path <- here(input_dir)
  

  
  output_path <- here(output_dir)
  zip_path <- here(output_dir, zip_subdir)
  
  # Ensure input exists
  stopifnot(dir_exists(input_path))
  
  # Create output folders
  if (!dir_exists(output_path)) dir_create(output_path, recurse = TRUE)
  if (archive_zips && !dir_exists(zip_path)) dir_create(zip_path, recurse = TRUE)
  
  # Inventory raster and sidecar files
  raster_files <- dir_info(
    path = input_path,
    recurse = TRUE,
    regexp = "\\.(bil|tif|img|hdr|stx)$"
  ) %>%
    mutate(
      file_type = tools::file_ext(path),
      basename = path_file(path),
      relative_path = path_rel(path, start = input_path),
      size_mb = round(as.numeric(size) / 1e6, 2),
      last_modified = modification_time,
      possible_duplicate = duplicated(basename) | duplicated(basename, fromLast = TRUE)
    )
  
  # Flag potential duplicates
  duplicates <- raster_files %>%
    filter(possible_duplicate) %>%
    group_by(basename) %>%
    mutate(size_variation = n_distinct(size_mb) > 1) %>%
    ungroup()
  
  # Write output summaries
  write_csv(raster_files, file.path(output_path, "raster_file_inventory.csv"))
  write_csv(duplicates, file.path(output_path, "duplicate_raster_summary.csv"))
  cli::cli_alert_success("✅ Inventory and duplicates written to {.file {output_path}}")

  # Return result invisibly
  invisible(list(raster_files = raster_files, duplicates = duplicates))
}
