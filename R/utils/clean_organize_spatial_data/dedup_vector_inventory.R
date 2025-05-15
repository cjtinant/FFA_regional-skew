#' dedup_vector_inventory
#'
#' Creates an inventory of vector files in a given folder, flags potential duplicates,
#' and writes summary CSVs to a specified output directory.
#'
#' @param input_dir Directory containing vector files (default: "data/raw/vector_raw")
#' @param output_dir Directory to write summary CSVs (default: "to_check")
#'
#' @return A list with two tibbles: `vector_files`, `duplicates`
#' @export
#'
dedup_vector_inventory <- function(input_dir = "data/raw/vector_raw", output_dir = "to_check") {
  library(fs)
  library(tidyverse)
  library(here)
  
  # Ensure input path exists
  input_path <- here(input_dir)
  stopifnot(dir_exists(input_path))
  
  # Create output path if it doesn't exist
  output_path <- here(output_dir)
  if (!dir_exists(output_path)) dir_create(output_path)
  
  # List relevant vector files
  vector_files <- dir_info(
    path = input_path,
    recurse = TRUE,
    regexp = "\\.(shp|gpkg|geojson|kml|gdb|sqlite)$"
  ) %>%
    mutate(
      file_type = tools::file_ext(path),
      basename = path_file(path),
      size_mb = round(as.numeric(size) / 1e6, 2),
      possible_duplicate = duplicated(basename) | duplicated(basename, fromLast = TRUE)
    )
  
  # Summarize duplicate groups
  duplicates <- vector_files %>%
    filter(possible_duplicate) %>%
    group_by(basename) %>%
    mutate(size_variation = n_distinct(size_mb) > 1) %>%
    ungroup()
  
  # Write to CSV
  write_csv(vector_files, file.path(output_path, "vector_file_inventory.csv"))
  write_csv(duplicates, file.path(output_path, "duplicate_vector_summary.csv"))
  
  message("✅ Inventory complete. CSVs written to: ", output_path)
  
  return(list(vector_files = vector_files, duplicates = duplicates))
}
