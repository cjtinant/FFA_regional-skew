# File: R/utils/organize_raw_shapefiles.R
# Title: Organize Shapefile Components into Subfolders
# Author: CJ Tinant
# Date: 2025-04-21
# Description: This script finds all .shp files in data/raw/vector_raw/,
# then moves each .shp and its associated sidecar files into a new folder
# named after the base file (e.g., us_eco_l3/). Logs operations to a .csv file.

library(fs)
library(here)
library(tidyverse)

raw_dir <- here("data/raw/vector_raw")
shapefiles <- dir_ls(raw_dir, recurse = TRUE, glob = "*.shp")

log <- tibble()

for (shp in shapefiles) {
  base <- path_ext_remove(shp)
  pattern <- paste0(base, ".*")
  sidecars <- dir_ls(path_dir(shp), regexp = pattern)

  dest_dir <- path(raw_dir, path_file(base))
  dir_create(dest_dir)

  moved <- map_chr(sidecars, ~ {
    new_path <- path(dest_dir, path_file(.x))
    file_move(.x, new_path)
    new_path
  })

  log <- bind_rows(log, tibble(
    original_dir = path_dir(shp),
    shapefile_base = path_file(base),
    n_files_moved = length(moved),
    moved_files = paste(path_file(moved), collapse = "; ")
  ))
}

# Save log file
log_path <- here("to_check/shapefile_reorg_log.csv")
write_csv(log, log_path)
message("✅ Moved and reorganized shapefiles. Log saved to: ", log_path)