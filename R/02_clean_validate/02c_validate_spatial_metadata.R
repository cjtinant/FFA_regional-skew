# ==============================================================================
# Script Name:     02c_validate_spatial_metadata.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-06-28
# Last Update:     2025-07-14
# Change Log:
# - 2025-07-25     Update header information;
#                  move notes to `script-notes_and_developer-log`
#
# Purpose:         Validate CRS and resolution of raster and vector files.
#
# Workflow Summary:
# 1. List vector and raster files in data/processed.
# 2. Make function to validate vector files.
# 3. Make function to validate raster files.
# 4. Validate vector files.
# 5. Validate raster files.
# 6. Recheck rasters with errors.
# 7. Replace failed entries with recheck results.
# 8. Recheck vector results for data issues.
# 9. Check vector results for minimum spatial extent
#
# Input/Data URLs: Raster and vector files in the `data/processed/` directory.
#                  The vector files validated are in .gpkg and .shp formats.
#                  The raster files validated are in .tif. format.
# Outputs:
# - Vector summary: data/log/validate_spatial/vector_validation_summary.csv
# - Raster summaries (batched):
#        data/log/validate_spatial/raster_metadata_batch_XX.csv
# - Rechecked raster output: data/log/validate_spatial/raster_recheck_results.csv
#
# Dependencies:
# - dplyr, readr   General data wrangling, import and export.
# - fs             File interface system.
# - glue           String interpolation
# - here           Consistent relative paths.
# - purrr          Apply a function to each element of a vector.
# - sf             Handling spatial data.
# - terra           Vector and raster data operations.
#
# Helper Functions:
#
# Related Milestone Report:
# ==============================================================================
# --- load libraries ---
library(dplyr)
library(fs)
library(glue)
library(here)
library(purrr)
library(readr)
library(sf)
library(terra)
library(cli)

# ------------------------------------------------------------------------------
# 1. List vector and raster files separately
# ------------------------------------------------------------------------------
vector_files <- dir_ls(here("data/processed"),
                       recurse = TRUE, regexp = "\\.(gpkg|shp)$")
raster_files <- dir_ls(here("data/processed"),
                       recurse = TRUE, regexp = "\\.tif$")

# ------------------------------------------------------------------------------
# 2. Function: Validate vector files
# ------------------------------------------------------------------------------
validate_vector_metadata <- function(file) {
  tryCatch({
    layer <- st_layers(file)$name[1]
    vec <- st_read(file, layer = layer, quiet = TRUE)
    crs <- st_crs(vec)$input
    bbox <- st_bbox(vec)

    tibble(
      file = path_rel(file, start = here()),
      type = "vector",
      crs = crs,
      resolution = NA,
      xmin = bbox["xmin"],
      xmax = bbox["xmax"],
      ymin = bbox["ymin"],
      ymax = bbox["ymax"]
    )
  }, error = function(e) {
    cli::cli_alert_warning("⚠️ Could not read vector file: {file}")
    tibble(file = path_rel(file, start = here()), type = "vector", crs = NA,
           resolution = NA, xmin = NA, xmax = NA, ymin = NA, ymax = NA)
  })
}

# ------------------------------------------------------------------------------
# 3. Function: Validate raster files
# ------------------------------------------------------------------------------
validate_raster_metadata <- function(file) {
  file <- as.character(file)[1]  # Force scalar

  tryCatch({
    r <- rast(file)
    crs_val <- as.character(crs(r))[1]
    bbox <- ext(r)
    resolution <- res(r) %>% paste(collapse = " x ")

    tibble(
      file = path_rel(file, start = here()),
      type = "raster",
      crs = crs_val,
      resolution = resolution,
      xmin = xmin(bbox),
      xmax = xmax(bbox),
      ymin = ymin(bbox),
      ymax = ymax(bbox),
      file_size_MB = round(file_info(file)$size[1] / 1024^2, 2),
      error = NA
    )
  }, error = function(e) {
    cli::cli_alert_warning("⚠️ Could not read: {basename(file)} — {e$message}")
    tibble(
      file = path_rel(file, start = here()),
      type = "raster",
      crs = NA,
      resolution = NA,
      xmin = NA,
      xmax = NA,
      ymin = NA,
      ymax = NA,
      file_size_MB = round(file_info(file)$size[1] / 1024^2, 2),
      error = as.character(e$message)
    )
  })
}

# ------------------------------------------------------------------------------
# 4. Validate vector files
# ------------------------------------------------------------------------------
cli::cli_h2("🔍 Validating vector files...")
vector_summary <- map_dfr(seq_along(vector_files), function(i) {
  cli::cli_alert("Vector {i}/{length(vector_files)}: {basename(vector_files[i])}")
  validate_vector_metadata(vector_files[i])
})

out_path <- here("data/log/validate_spatial", "vector_validation_summary.csv")
if (!dir_exists(dirname(out_path))) dir_create(dirname(out_path))

write_csv(vector_summary, out_path)
cli::cli_alert_success("✅ Summary saved to {out_path}")


# ------------------------------------------------------------------------------
# 5. Validate raster files as batches
# ------------------------------------------------------------------------------
cli::cli_h2("🌄 Validating raster files...")

batch_size <- 100
raster_chunks <- split(raster_files,
                       ceiling(seq_along(raster_files) / batch_size))

for (i in seq_along(raster_chunks)) {
  cli::cli_h2("🌄 Processing raster batch {i}/{length(raster_chunks)}")

  chunk_summary <- map_dfr(raster_chunks[[i]], function(f) {
    cli::cli_alert("→ {basename(f)}")
    validate_raster_metadata(f)
  })

  batch_filename <- sprintf("raster_metadata_batch_%02d.csv", i)
  batch_path <- here("data", "log", "validate_spatial", batch_filename)
  stopifnot(length(batch_path) == 1, is.character(batch_path))
  write_csv(chunk_summary, file = batch_path)
}

# --- Path to metadata batch outputs ---
batch_files <- dir_ls(here("data/log/validate_spatial"),
                      regexp = "raster_metadata_batch_.*\\.csv$")

# --- Combine all batch CSVs ---
raster_validation_summary <- map_dfr(
  batch_files,
  read_csv,
  show_col_types = FALSE
)

raster_validation_summary <- map_dfr(batch_files, function(f) {
  read_csv(f, show_col_types = FALSE) %>%
    mutate(file_size_MB = as.numeric(file_size_MB))
})

# --- Write a raster summary file ---
out_path <- here("data/log/validate_spatial", "raster_validation_summary.csv")
write_csv(raster_validation_summary, out_path)

# ------------------------------------------------------------------------------
# 6. Recheck rasters with errors
# ------------------------------------------------------------------------------
# --- Identify files with errors ---
raster_errors <- raster_validation_summary %>%
  filter(!is.na(error)) %>%
  pull(file)

length(raster_errors)

# --- Write a log file to compare ---
raster_errors_log <- here("data/log/validate_spatial",
                          "raster_error_recheck.csv")

# --- Recheck only the failed files ---
recheck_results <- map_dfr(raster_errors, ~{
  cli::cli_alert("🔄 Rechecking: {.file {basename(.x)}}")
  validate_raster_metadata(here(.x))
})

write_csv(recheck_results, raster_errors_log)

# ------------------------------------------------------------------------------
# 7. Replace failed entries with recheck results
# ------------------------------------------------------------------------------
# --- Combine updated rows with successful original rows ---
rast_validation_summ_updated <- raster_validation_summary %>%
  # Remove old entries for failed files
  filter(!(file %in% raster_errors)) %>%
  # Add rechecked versions
  bind_rows(recheck_results) %>%
  arrange(file)

# --- Overwrite the master summary CSV ---
write_csv(rast_validation_summ_updated,
          here("data/log/validate_spatial", "raster_validation_summary.csv"))

cli::cli_alert_success("✅ Updated summary written to raster_validation_summary.csv")

# --- Confirm no remaining errors ---
remaining_errors <- rast_validation_summ_updated %>%
  filter(!is.na(error))

cli::cli_alert_info("🚨 Remaining unreadable rasters: {nrow(remaining_errors)}")

# ------------------------------------------------------------------------------
# 8. Check vector results for data issues
# ------------------------------------------------------------------------------
vec_summary <- read_csv(here("data/log/validate_spatial/vector_validation_summary.csv"))

# Count unreadable files
bad_vectors <- vec_summary %>%
  filter(is.na(crs) | is.na(xmin) | is.na(xmax))

cli::cli_alert_info("🚨 Unreadable vector files: {nrow(bad_vectors)}")

# ---- Recheck unreadable files ----
# Recheck vector files that failed
recheck_vec_results <- purrr::map_dfr(bad_vectors$file, ~{
  cli::cli_alert("🔄 Rechecking: {.file {basename(.x)}}")
  validate_vector_metadata(here::here(.x))
})

# Combine successful and rechecked entries
vec_summary_updated <- vec_summary %>%
  filter(!(file %in% bad_vectors$file)) %>%
  bind_rows(recheck_vec_results) %>%
  arrange(file)

# Write updated version
write_csv(vec_summary_updated,
          here("data/log/validate_spatial/vector_validation_summary.csv"))

cli::cli_alert_success("✅ Vector summary updated after recheck.")

# ---- Flag potential issues for review ----
# Mismatched or missing CRS
vec_summary_updated %>%
  filter(is.na(crs) | crs == "") %>%
  select(file, crs)

# Vectors with zero extent
vec_summary_updated %>%
  filter(xmin == xmax | ymin == ymax)

# ------------------------------------------------------------------------------
# 9. Check vector results for minimum spatial extent
# ------------------------------------------------------------------------------
# ---- Load and Filter Level 1 ecoregions ----
eco_l1_gp <- st_read(here("data/r/us_ecoregions/us-eco-levels.gpkg"),
                     layer = "us_eco_l1", quiet = TRUE) %>%
  filter(NA_L1NAME == "GREAT PLAINS")

# Union all features to create a bounding box or mask
eco_gp_union <- st_union(eco_l1_gp) %>% st_as_sf()
bbox_gp <- st_bbox(eco_gp_union)

# Add bounding box containment check
vec_summary_bbox_check <- vec_summary %>%
  mutate(
    contains_bbox_gp = if_else(
      !is.na(xmin) & xmin <= bbox_gp["xmin"] &
        xmax >= bbox_gp["xmax"] &
        ymin <= bbox_gp["ymin"] &
        ymax >= bbox_gp["ymax"],
      TRUE, FALSE
    )
  )

suspect_vectors <- vec_summary_bbox_check %>%
  filter(contains_bbox_gp == FALSE | is.na(contains_bbox_gp))

# ---- Interpret failures ----
vec_summary_bbox_check %>%
  filter(!contains_bbox_gp | is.na(contains_bbox_gp)) %>%
  arrange(desc(file))

vec_summary_bbox_check <- vec_summary_bbox_check %>%
  mutate(
    scope = case_when(
      is.na(contains_bbox_gp) ~ "unknown",
      contains_bbox_gp ~ "full GP",
      TRUE ~ "partial GP"
    )
  )

write_csv(vec_summary_bbox_check,
          here("data/log/validate_spatial/vector_bbox_summary.csv"))

vec_summary_bbox_check %>%
  filter(scope == "partial GP" | scope == "unknown") %>%
  write_csv(here("data/log/validate_spatial/vector_bbox_suspects.csv"))
