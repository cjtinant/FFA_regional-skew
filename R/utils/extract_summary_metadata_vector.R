
# ==============================================================================
# Script Name:  extract_summary_metadata_vector.R
# Purpose:      Iterate over all layers in a GeoPackage and extract metadata
# Author:       Charles Jason Tinant — with ChatGPT 4o
# Date Created: 2025-07-20
# Last Updated:
#
# Changelog:
# - 2025-07-20: Initial version to summarize geometry, CRS, and attribute schema
#
# Workflow Summary:
# - Load vector file using {sf}
# - Extract layer summary metadata (geometry, CRS, extent, features, columns)
# - Extract attribute schema (field names and data types)
# - Write both summaries to CSV
#
# Dependencies:
# -    here:      consistent relative paths
# -    dplyr
# -    readr
# -    sf:        spatial vector data support
# ==============================================================================

library(sf)
library(dplyr)
library(readr)
library(tibble)
library(here)

# ---- Define input and output paths ----
gpkg_file   <- here("data", "processed", "statsgo2",
                    "statsgo2_mupolygon.gpkg")

#gpkg_file <- here("data/processed/statsgo2/statsgo2_mupolygon.gpkg")

output_dir  <- here("docs", "metadata", "vector-data-summaries")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

if (!file.exists(gpkg_file)) {
  stop("Geopackage not found: ", gpkg_file)
}

# ---- Get layer names ----
layer_info <- st_layers(gpkg_file)
layer_names <- layer_info$name

# ---- Initialize summary list ----
summary_list <- list()

# ---- Iterate through layers ----
for (layer in layer_names) {
  message("Processing layer: ", layer)
  
  # Read the layer
  vec <- st_read(gpkg_file, layer = layer, quiet = TRUE)
  
  # Get attribute schema
  field_info <- tibble(
    layer = layer,
    field_name = names(vec),
    data_type = sapply(vec, function(x) class(x)[1])
  )
  
  # Write per-layer field metadata
  write_csv(field_info, file.path(output_dir, paste0(layer, "_attribute_metadata_v01.csv")))
  
  # Summarize layer
  summary_info <- tibble(
    file = basename(gpkg_file),
    layer = layer,
    geometry_type = st_geometry_type(vec, by_geometry = FALSE) |> as.character(),
    crs = st_crs(vec)$input,
    extent = paste(st_bbox(vec), collapse = ", "),
    n_features = nrow(vec),
    n_attributes = ncol(vec) - 1,
    geometry_column = attr(vec, "sf_column"),
    timestamp = Sys.time()
  )
  
  summary_list[[layer]] <- summary_info
}

# ---- Combine and write full summary ----
vector_summary <- bind_rows(summary_list)
write_csv(vector_summary, 
          file.path(output_dir, "statsgo2_mupolygon_layer_metadata_v01.csv"))

# ------------------------------------------------------------------------------
# 2. Get attribute names for layers
# ------------------------------------------------------------------------------

layer_names <- st_layers(gpkg_file)$name

field_names_list <- lapply(layer_names, function(layer) {
  data <- st_read(gpkg_file, layer = layer, quiet = TRUE)
  tibble(
    layer = layer,
    field_name = names(data),
    data_type = sapply(data, function(x) class(x)[1])
  )
})

# Combine into one table
fields_df <- bind_rows(field_names_list)

# Summarise to drop duplicates
fields_summary <- fields_df %>%
  select(-layer) %>%
  distinct() %>%
  arrange(field_name, data_type)

# Write output
write_csv(fields_summary, 
          file.path(output_dir, "statsgo2_mupolygon_attribute_metadata_v01.csv"))
