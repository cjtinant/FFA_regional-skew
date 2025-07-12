# ==============================================================================
# Function: inventory_raster_data
# Purpose:  Inventory raster files, detect duplicates, and write summary CSVs
#           for quality assurance. Optionally archives ZIP files.
#
# Author:   Charles Jason Tinant — revised with ChatGPT 4o
# Date Created: 2025-07-08
# Last Updated: 2025-07-11
#
# Change Log:
# - 2025-07-11: Added support for MODIS HDF files
# - 2025-07-10: Renamed function to inventory_raster_data(); generalized paths,
#               added optional ZIP archive subfolder, consistent output naming
# - 2025-07-08: Initial version with raster inventory and duplicate detection
# ==============================================================================

inventory_raster_data <- function(input_dir = "data/raw",
                                  output_dir = "to_check",
                                  archive_zips = TRUE,
                                  zip_subdir = "archives/raster_zips") {
  # Load required libraries
  library(fs)
  library(tidyverse)
  library(cli)
  
  # Resolve full paths
  input_path <- path_abs(input_dir)
  output_path <- path_abs(output_dir)
  zip_path <- path(output_path, zip_subdir)
  
  # Validate input directory
  stopifnot(dir_exists(input_path))
  
  # Create output folders as needed
  if (!dir_exists(output_path)) dir_create(output_path, recurse = TRUE)
  if (archive_zips && !dir_exists(zip_path)) dir_create(zip_path, recurse = TRUE)
  
  # Inventory raster and sidecar files
  raster_files <- dir_info(
    path = input_path,
    recurse = TRUE,
    regexp = "\\.(bil|tif|img|hdr|stx|hdf)$"
  ) %>%
    mutate(
      file_type = tools::file_ext(path),
      basename = path_file(path),
      relative_path = path_rel(path, start = input_path),
      folder = path_split(relative_path) %>% map_chr(~ .x[[1]]),
      size_mb = round(as.numeric(size) / 1e6, 2),
      last_modified = modification_time,
      data_status = case_when(
        str_detect(input_path, "data/raw") ~ "raw",
        str_detect(input_path, "data/processed") ~ "processed",
        TRUE ~ "unknown"
      ),
      possible_duplicate = duplicated(basename) | duplicated(basename, 
                                                             fromLast = TRUE),
      description = case_when(
        file_type == "tif"  ~ "GeoTIFF raster",
        file_type == "bil"  ~ "PRISM binary raster",
        file_type == "img"  ~ "Erdas Imagine raster",
        file_type == "hdr"  ~ "ENVI-style header",
        file_type == "stx"  ~ "Raster stats sidecar",
        file_type == "hdf"  ~ "Hierarchical Data Format raster",
        TRUE                ~ "Other raster format"
      )
    )
  
  # Identify duplicates by basename
  duplicates <- raster_files %>%
    filter(possible_duplicate) %>%
    group_by(basename) %>%
    mutate(size_variation = n_distinct(size_mb) > 1) %>%
    ungroup()
  
  # Define output CSV paths
  inventory_path <- path(output_path, "raster_data_inventory.csv")
  dupes_path     <- path(output_path, "duplicate_raster_data_summary.csv")
  
  # Write CSV summaries
  write_csv(raster_files, inventory_path)
  write_csv(duplicates, dupes_path)
  
  # Console messages
  cli::cli_alert_success("✅ Raster data inventory complete.")
  cli::cli_alert_info("→ Full inventory saved to {.file {inventory_path}}")
  cli::cli_alert_info("→ Duplicate summary saved to {.file {dupes_path}}")
  
  # Return results invisibly
  invisible(list(raster_files = raster_files, duplicates = duplicates))
}
