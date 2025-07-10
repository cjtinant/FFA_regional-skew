# ==============================================================================
# Script: inventory_feature_data.R
# Purpose: Create an inventory of feature (vector + tabular) files in a directory,
#          flag duplicates, and write summary tables for review.
# Author: Charles Jason Tinant — revised with ChatGPT 4o
# Date Created: 2025-05
# Last Updated: 2025-07-10
#
# Change Log:
# - 2025-07-10: Renamed function to inventory_feature_data(); added path safety,
#               updated comments and output messages for clarity
# - 2025-07-08: Initial version with duplicate detection by basename
# ==============================================================================

inventory_feature_data <- function(input_dir = "data/raw",
                                   output_dir = "to_check") {
  # Load required packages
  library(fs)
  library(tidyverse)
  library(cli)
  
  # Resolve absolute paths
  input_path <- path_abs(input_dir)
  output_path <- path_abs(output_dir)
  
  # Validate and prepare directories
  stopifnot(dir_exists(input_path))
  if (!dir_exists(output_path)) dir_create(output_path, recurse = TRUE)
  
  # List vector and tabular files (exclude raster formats)
  feature_files <- dir_info(
    path = input_path,
    recurse = TRUE,
    regexp = "\\.(shp|gpkg|geojson|kml|gdb|sqlite|json|zip|csv|rds|tsv)$"
  ) %>%
    # Remove shapefile sidecars
    filter(!str_detect(path_file(path), "\\.(shx|dbf|prj|cpg|sbn|sbx)$")) %>%
    mutate(
      file_type = tools::file_ext(path),
      basename = path_file(path),
      relative_path = path_rel(path, start = input_path),
      size_mb = round(as.numeric(size) / 1e6, 2),
      last_modified = modification_time,
      possible_duplicate = duplicated(basename) | duplicated(basename, fromLast = TRUE)
    )
  
  # Flag and summarize duplicates
  duplicates <- feature_files %>%
    filter(possible_duplicate) %>%
    group_by(basename) %>%
    mutate(size_variation = n_distinct(size_mb) > 1) %>%
    ungroup()
  
  # Define output file paths
  file_inventory_path <- path(output_path, "feature_file_inventory.csv")
  duplicates_path <- path(output_path, "duplicate_feature_summary.csv")
  
  # Write CSV outputs
  write_csv(feature_files, file_inventory_path)
  write_csv(duplicates, duplicates_path)
  
  # Console messages
  cli::cli_alert_success("✅ Feature data inventory complete.")
  cli::cli_alert_info("→ Full inventory saved to {.file {file_inventory_path}}")
  cli::cli_alert_info("→ Duplicates summary saved to {.file {duplicates_path}}")
  
  # Return results
  return(list(feature_files = feature_files, duplicates = duplicates))
}