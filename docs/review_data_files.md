Review Raw Data Files
================
CJ Tinant
2025-07-10 14:37:55

- [Overview](#overview)
- [Goals](#goals)
- [Part 1: Inventory Vector and CSV Files in
  data/raw](#part-1-inventory-vector-and-csv-files-in-dataraw)
  - [1.1. Run Deduplication Script](#11-run-deduplication-script)
  - [1.2. Move Archived ZIPs](#12-move-archived-zips)
- [Part 2: Inventory Raster Files in
  data/raw](#part-2-inventory-raster-files-in-dataraw)
  - [2.1. Inventory Raster Files](#21-inventory-raster-files)
- [Part 3: Clean Data Raw](#part-3-clean-data-raw)
  - [3.1 Update and Log Data Raw
    Inventory](#31-update-and-log-data-raw-inventory)
  - [3.2. Remove Unneeded Climate
    Rasters](#32-remove-unneeded-climate-rasters)
- [Part 4: Inventory Vector and CSV Files in
  data/processed](#part-4-inventory-vector-and-csv-files-in-dataprocessed)

## Overview

This document supports QA of raw spatial inputs used for regional skew
modeling. The goal is to inventory, validate, and deduplicate vector and
raster files within the data/raw/ directory prior to covariate
extraction.

## Goals

- ✅ Identify and remove duplicate files from data/raw
- ✅ Deduplicate and standardize raster inputs in data/raw/
- 🗂️ Organize spatial datasets by relevance, format, and source

## Part 1: Inventory Vector and CSV Files in data/raw

### 1.1. Run Deduplication Script

This step recursively lists vector and CSV files, flags potential
duplicates, and summarizes file characteristics by folder.

Vector files are grouped by their basename to identify possible version
conflicts. Files with the same name but differing in size are flagged
for further review, as these discrepancies may indicate distinct
versions or incomplete copies. Preferred formats such as `.gpkg` and
`.csv` are prioritized for retention, while others (e.g., `.shp`) are
reviewed for relevance and redundancy.

The full inventory is saved to `to_check/vector_file_inventory.csv`,
while a filtered summary of files with shared names is exported to
`to_check/duplicate_vector_summary.csv`. Lower-priority duplicates are
moved to `to_check/duplicates/` for archival and manual review.

``` r
knitr::opts_chunk$set(echo = TRUE)

result_vec_raw <- inventory_feature_data(
  input_dir = here("data/raw"),
  output_dir = here("to_check")
)
```

    ## ✔ ✅ Feature data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/to_check/feature_file_inventory.csv'

    ## ℹ → Duplicates summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/to_check/duplicate_feature_summary.csv'

### 1.2. Move Archived ZIPs

This step moves zipped files from `data\raw\` to `data\archives\`

``` r
move_zip_to_archives()
```

    ## ℹ No *.zip files found in 'ecoregions'

    ## ℹ No *.zip files found in 'koppen_climate'

    ## ℹ No *.zip files found in 'modis'

    ## ℹ No *.zip files found in 'nhdplus'

    ## ℹ No *.zip files found in 'nlcd'

    ## ℹ No *.zip files found in 'peakflow_gages'

    ## ℹ No *.zip files found in 'phzm'

    ## ℹ No *.zip files found in 'prism'

    ## ℹ No *.zip files found in 'statsgo2'

    ## ℹ No matching files found in any domain folder.

## Part 2: Inventory Raster Files in data/raw

### 2.1. Inventory Raster Files

This step inventories raster files with common geospatial formats,
including `.bil`, `.tif`, `.img`, `.hdr`, and `.stx`. Files are grouped
by their basename to detect potential duplicates, particularly those
with the same name but differing file sizes—an indication of possible
version mismatches or incomplete downloads.

The full inventory of raster files is saved to
`to_check/raster_file_inventory.csv`, with duplicate flags for QA. A
filtered summary of raster files with matching names is prepared for
manual review as `to_check/duplicate_raster_summary.csv`.

``` r
result_vec_raw <- inventory_feature_data(
  input_dir = here("data/raw"),
  output_dir = here("to_check")
)
```

    ## ✔ ✅ Feature data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/to_check/feature_file_inventory.csv'

    ## ℹ → Duplicates summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/to_check/duplicate_feature_summary.csv'

## Part 3: Clean Data Raw

### 3.1 Update and Log Data Raw Inventory

``` r
# get vector results
files_raw_vec <- read_csv(here("to_check", "vector_file_inventory.csv"),
                          show_col_types = FALSE) %>%
#  filter(file_type == "gpkg" |
#           file_type == "csv"
#         ) %>%
  select(file_type, relative_path, possible_duplicate) %>%
  separate(
    col  = relative_path, 
    into = c("folder", "file"),
    sep = "/",           # delimiter
    extra = "merge",     # merge any additional parts into last column
    fill = "right"       # if no slash, leave second column NA
  ) %>%
  arrange(file_type, folder) %>%
  mutate(data_type = "vector")

# get raster results
files_raw_rast <- read_csv(here("to_check", "raster_file_inventory.csv"),
                          show_col_types = FALSE) %>%
  select(file_type, relative_path, possible_duplicate) %>%
  separate(
    col  = relative_path, 
    into = c("folder", "file"),
    sep = "/",           # delimiter
    extra = "merge",     # merge any additional parts into last column
    fill = "right"       # if no slash, leave second column NA
  ) %>%
  arrange(file_type, folder) %>%
  mutate(data_type = "raster")

# combine and summarise results
files_raw_all <- bind_rows(files_raw_vec, files_raw_rast) %>%
  relocate(data_type, file_type, folder, file)


files_raw_summary <- files_raw_all %>%
  count(data_type, folder, file_type, possible_duplicate) %>%
  arrange(folder)

write_csv(files_raw_summary,
          here("data/log/summary_raw_data_files.csv"))
```

### 3.2. Remove Unneeded Climate Rasters

DISCUSS

``` r
# This step removes `koppen_climate` raster files for the periods **1901–1930**, # **1931–1960**, and **1961–1990** because the regional skew modeling targets 
# modern climate normals (1990–2020).

# Identify outdated Koppen-Geiger rasters
# koppen_rasters_to_remove <- files_raw_rast %>%
#   filter(
#     folder == "koppen_climate",
#     !str_detect(file, "1990|2000|2010|2020")
#   ) %>%
#   mutate(remove_reason = "outside_target_period")

# (Run Once) Log files marked for removal
# write_csv(koppen_rasters_to_remove,
#          here("data/log/koppen_climate_files_removed.csv"))
```

## Part 4: Inventory Vector and CSV Files in data/processed

``` r
knitr::opts_chunk$set(echo = TRUE)

result_vec <- dedup_vector_inventory(
  input_dir = here("data/processed"),
  output_dir = here("data/intermediate")
)
```
