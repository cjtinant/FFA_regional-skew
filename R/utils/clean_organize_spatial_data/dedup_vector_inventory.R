# ==============================================================================
# Script: dedup_vector_inventory.R
# Purpose: Create an inventory of vector files in a directory, flag duplicates,
#          and write summary tables for review.
# Author: Charles Jason Tinant — revised with ChatGPT 4o
# Last Updated: 2025-07-08
# ==============================================================================

dedup_vector_inventory <- function(input_dir = "data/raw",
                                   output_dir = "to_check") {
  # Load required packages
  library(fs)
  library(tidyverse)
  library(here)
  library(cli)
  
  # Validate input directory
  input_path <- here(input_dir)
  stopifnot(dir_exists(input_path))
  
  # Create output directory if needed
  output_path <- here(output_dir)
  if (!dir_exists(output_path)) dir_create(output_path)
  
  # List vector files and common containers
  vector_files <- dir_info(
    path = input_path,
    recurse = TRUE,
    regexp = "\\.(shp|gpkg|geojson|kml|gdb|sqlite|json|zip|csv)$"
  ) %>%
    # Exclude auxiliary shapefile components
    filter(!str_detect(path_file(path), "\\.(shx|dbf|prj|cpg|sbn|sbx)$")) %>%
    mutate(
      file_type = tools::file_ext(path),
      basename = path_file(path),
      relative_path = path_rel(path, start = input_path),
      size_mb = round(as.numeric(size) / 1e6, 2),
      last_modified = modification_time,
      possible_duplicate = duplicated(basename) | duplicated(basename, fromLast = TRUE)
    )
  
  # Summarize duplicates
  duplicates <- vector_files %>%
    filter(possible_duplicate) %>%
    group_by(basename) %>%
    mutate(size_variation = n_distinct(size_mb) > 1) %>%
    ungroup()
  
  # Write CSV summaries
  write_csv(vector_files, file.path(output_path, "vector_file_inventory.csv"))
  write_csv(duplicates, file.path(output_path, "duplicate_vector_summary.csv"))
  
  # Console message
  cli::cli_alert_success("✅ Inventory complete. CSVs written to {.file {output_path}}")
  
  return(list(vector_files = vector_files, duplicates = duplicates))
}
