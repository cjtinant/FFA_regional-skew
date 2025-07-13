# ==============================================================================
# Script Name:    02x_join_nhdphr_catchments.R
# Purpose:        Combine and clean NHDPlus HR catchments by Level IV ecoregion
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-07-12
#
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-07-12
# Last Updated:   2025-07-12
#
# Description:
# This script reads multiple NHDPlus HR catchment GeoPackages, performs 
# geometry validation in chunks to prevent memory issues, standardizes geometry 
# types to MULTIPOLYGON, and exports a combined spatial dataset. File naming is 
# based on sanitized region names (e.g., ecoregion or subregion tiles).
#
# Inputs:
# - GeoPackages: data/raw/nhdphr_catchments/*.gpkg
# - Log file:    data/log/catchment_download_log.csv (with 'status == "success"')
#
# Output:
# - GeoPackage:  data/processed/nhdphr/nhdphr_catchments_combined.gpkg
#
# Key Steps:
# - Filter download log for successful files
# - Read files with robust error handling
# - Validate geometries in chunks (to avoid memory overflow)
# - Enforce MULTIPOLYGON geometry consistency
# - Export combined layer
#
# Dependencies:
# - dplyr, fs, here, purrr, readr, sf, stringr, janitor
# ==============================================================================

library(dplyr)
library(fs)
library(here)
library(purrr)
library(readr)
library(sf)
library(stringr)
library(janitor)

# ------------------------------------------------------------------------------
# 1. Load download log and filter to successful entries
# ------------------------------------------------------------------------------

log_file <- here("data/log/catchment_download_log.csv")

log_tbl <- read_csv(log_file, show_col_types = FALSE) %>%
  group_by(us_l4name) %>%
  arrange(desc(timestamp), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  filter(status == "success") %>%
  mutate(
    safe_name = str_replace_all(us_l4name, "[^A-Za-z0-9]+", "_"),
    file_path = here("data", "raw", "nhdphr_catchments",
                     paste0(safe_name, ".gpkg"))
  ) %>%
  filter(file_exists(file_path))

# ------------------------------------------------------------------------------
# 2. Read and combine all valid catchment files safely (with messages)
# ------------------------------------------------------------------------------

read_safe_catchments <- function(path) {
  tryCatch({
    st_read(path, quiet = TRUE)
  }, error = function(e) {
    message("❌ Failed to read: ", path, "\n  → ", e$message)
    NULL
  })
}

# Use safe reader and filter NULLs
catchments_list <- map(log_tbl$file_path, read_safe_catchments) %>%
  compact()  # remove failed reads

# ------------------------------------------------------------------------------
# 3. Combine, validate, clean, and reproject
# ------------------------------------------------------------------------------

# Optionally check geometry types first (skip if already checked)
geom_types <- map(catchments_list, ~ unique(st_geometry_type(.x)))

# Combine (delay validation until after bind)
catchments_raw <- bind_rows(catchments_list)

# Optionally check geometry types first (skip if already checked)
geom_types <- map(catchments_list, ~ unique(st_geometry_type(.x)))

# Combine (delay validation until after bind)
catchments_raw <- bind_rows(catchments_list)

# Validate geometries
# Create row-based chunk IDs
chunk_size <- 1000
n_chunks <- ceiling(nrow(catchments_raw) / chunk_size)

catchments_raw <- catchments_raw %>%
  mutate(chunk_id = rep(1:n_chunks, each = chunk_size, length.out = n()))

# Validate in chunks
catchments_valid <- catchments_raw %>%
  group_split(chunk_id) %>%
  map(~ st_make_valid(.x)) %>%
  bind_rows()

# Check projection
st_crs(catchments_valid)

# Enforce consistent geometry type (e.g., MULTIPOLYGON)
catchments_valid <- st_cast(catchments_valid, "MULTIPOLYGON")

# ------------------------------------------------------------------------------
# 4. Export combined catchments
# ------------------------------------------------------------------------------

output_path <- here("data", "processed", "nhdphr", "nhdphr_catchments_combined.gpkg")
dir_create(dirname(output_path))
st_write(catchments_valid, output_path, delete_dsn = TRUE)

message("✅ Combined catchments written to: ", output_path)




