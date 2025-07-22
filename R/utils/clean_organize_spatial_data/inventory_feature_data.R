# ==============================================================================
# Script: inventory_feature_data.R
# Purpose: Create an inventory of feature (vector + tabular) files in a directory,
#          flag duplicates, and write summary tables for review.
# Author: Charles Jason Tinant — revised with ChatGPT 4o
# Date Created: 2025-05
# Last Updated: 2025-07-14
#
# Change Log:
# - 2025-07-14: Updated output to permanently log results
# - 2025-07-13: Improved duplicate logic to distinguish catchment and flowline
#               files with same base name in different folders
# ==============================================================================

inventory_feature_data <- function(input_dir = "data/raw",
                                   output_dir = "data/log") {
  # Load required packages
  library(fs)
  library(tidyverse)
  library(cli)

  # Resolve absolute paths
  input_path <- path_abs(input_dir)
  output_path <- path_abs(output_dir)

  stopifnot(dir_exists(input_path))
  if (!dir_exists(output_path)) dir_create(output_path, recurse = TRUE)

  # List vector and tabular files
  feature_files <- dir_info(
    path = input_path,
    recurse = TRUE,
    regexp = "\\.(shp|gpkg|geojson|kml|gdb|sqlite|json|zip|csv|rds|tsv)$"
  ) %>%
    filter(!str_detect(path_file(path), "\\.(shx|dbf|prj|cpg|sbn|sbx)$")) %>%
    mutate(
      file_type = tools::file_ext(path),
      basename = path_file(path),
      basename_no_ext = tools::file_path_sans_ext(basename),
      relative_path = path_rel(path, start = input_path),
      top_folder = path_split(relative_path) %>% map_chr(~ .x[[1]]),
      context_key = paste0(top_folder, "/", basename_no_ext),
      size_mb = round(as.numeric(size) / 1e6, 2),
      last_modified = modification_time
    ) %>%
    group_by(context_key) %>%
    mutate(possible_duplicate = n() > 1) %>%
    ungroup()

  # Flag and summarize true duplicates
  duplicates <- feature_files %>%
    filter(possible_duplicate) %>%
    group_by(context_key) %>%
    mutate(size_variation = n_distinct(size_mb) > 1) %>%
    ungroup()

  # Write outputs
  file_inventory_path <- path(output_path, "feature_file_inventory.csv")
  duplicates_path <- path(output_path, "duplicate_feature_summary.csv")

  write_csv(feature_files, file_inventory_path)
  write_csv(duplicates, duplicates_path)

  cli::cli_alert_success("✅ Feature data inventory complete.")
  cli::cli_alert_info("→ Full inventory saved to {.file {file_inventory_path}}")
  cli::cli_alert_info("→ Duplicates summary saved to {.file {duplicates_path}}")

  return(list(feature_files = feature_files, duplicates = duplicates))
}
