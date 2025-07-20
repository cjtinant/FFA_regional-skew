Review and Inventory of Spatial and Tabular Data
================
CJ Tinant
2025-07-14 12:11:57

- [Overview](#overview)
- [Goals](#goals)
- [Part 1: Inventory Files in
  data/raw](#part-1-inventory-files-in-dataraw)
  - [1.1. Run Feature Inventory
    Script](#11-run-feature-inventory-script)
  - [1.2. Run Raster Inventory Script](#12-run-raster-inventory-script)
  - [1.3. Move Archived ZIPs](#13-move-archived-zips)
  - [1.4. Check Results](#14-check-results)
  - [1.5. Remove Unneeded Climate
    Rasters](#15-remove-unneeded-climate-rasters)
- [Part 2: Inventory Files in
  data/processed](#part-2-inventory-files-in-dataprocessed)
  - [2.1. Run Feature Inventory
    Script](#21-run-feature-inventory-script)
  - [2.2. Run Raster Inventory Script](#22-run-raster-inventory-script)
- [Part 3: Check Results](#part-3-check-results)

## Overview

The goal is to inventory, validate, and document feature (vector and
tabular) and raster datasets stored in the data/ directory, with a focus
on identifying duplicates, standardizing file structure, and preparing
inputs for covariate extraction in the regional skew model.

## Goals

- ✅ Identify and remove duplicate files from data/raw
- ✅ Deduplicate and standardize raster inputs in data/raw/
- 🗂️ Organize spatial datasets by relevance, format, and source

## Part 1: Inventory Files in data/raw

### 1.1. Run Feature Inventory Script

This step recursively lists vector and CSV files, flags potential
duplicates, and summarizes file characteristics by folder.

Feature files are grouped by their basename to identify possible version
conflicts. Files with the same name but differing in size are flagged
for further review, as these discrepancies may indicate distinct
versions or incomplete copies. Preferred formats such as `.gpkg` and
`.csv` are prioritized for retention, while others (e.g., `.shp`) are
reviewed for relevance and redundancy.

The full inventory is saved to `data/log/feature_file_inventory.csv`,
while a filtered summary of files with shared names is exported to
`to_check/duplicate_vector_summary.csv`. Lower-priority duplicates are
moved to `to_check/duplicates/` for archival and manual review.

``` r
knitr::opts_chunk$set(echo = TRUE)

result_feat_raw <- inventory_feature_data(
  input_dir = here("data/raw"),
  output_dir = here("data/log/raw_feature/")
)
```

    ## ✔ ✅ Feature data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raw_feature/feature_file_inventory.csv'

    ## ℹ → Duplicates summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raw_feature/duplicate_feature_summary.csv'

This step inventories raster files with common geospatial formats,
including `.bil`, `.tif`, `.img`, `.hdr`, and `.stx`. Files are grouped
by their basename to detect potential duplicates, particularly those
with the same name but differing file sizes—an indication of possible
version mismatches or incomplete downloads.

The full inventory of raster files is saved to
`data/log/raster_file_inventory.csv`, with duplicate flags for QA. A
filtered summary of raster files with matching names is prepared for
manual review as `data/log/duplicate_raster_summary.csv`.

### 1.2. Run Raster Inventory Script

``` r
result_rast_raw <- inventory_raster_data(
  input_dir = here("data/raw"),
  output_dir = here("data/log/raw_raster/")
)
```

    ## ✔ ✅ Raster data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raw_raster/raster_data_inventory.csv'

    ## ℹ → Duplicate summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raw_raster/duplicate_raster_data_summary.csv'

### 1.3. Move Archived ZIPs

The following step identifies zip files from subdirectories of
`data/raw/` and relocates to `data/raw/archives`. This ensures that
archived download packages are stored separately from unzipped raster
inputs. The step is not used in the current modeling workflow.

``` r
# move_zip_to_archives()
```

### 1.4. Check Results

UPDATE

``` r
# get feature results
files_raw_vec <- read_csv(here("data/log/raw_feature",
                               "feature_file_inventory.csv"),
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
  mutate(data_type = "vector")

# get raster results
files_raw_rast <- read_csv(here("data/log/raw_raster",
                                "raster_data_inventory.csv"),
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

### 1.5. Remove Unneeded Climate Rasters

The following step identifies legacy koppen-climate rasters representing
time periods prior to 1990. These files are not used in the current
modeling workflow and may be removed following QA and confirmation.

``` r
# This step removes `koppen-climate` raster files for the periods **1901–1930**, # **1931–1960**, and **1961–1990** because the regional skew modeling targets 
# modern climate normals (1990–2020).

# Identify outdated Koppen-Geiger rasters
# koppen_rasters_to_remove <- files_raw_rast %>%
#   filter(
#     folder == "koppen-climate",
#     !str_detect(file, "1990|2000|2010|2020")
#   ) %>%
#   mutate(remove_reason = "outside_target_period")

# (Run Once) Log files marked for removal
# write_csv(koppen_rasters_to_remove,
#          here("data/log/koppen-climate_files_removed.csv"))
```

## Part 2: Inventory Files in data/processed

### 2.1. Run Feature Inventory Script

This step inventories feature data in `data/processed/`, including
vector files (e.g., `.gpkg`, .shp) and tabular outputs (e.g., `.csv`,
`.rds`). The goal is to ensure outputs from earlier data processing
stages are well organized, free of duplicates, and ready for use in
modeling workflows.

As with `data/raw`, files are grouped by basename to identify
duplicates. Files with the same name but different sizes are flagged for
manual review. Preferred formats such as `.gpkg`, `.csv`, and `.rds` are
retained; others are reviewed or archived if redundant.

``` r
result_feat_processed <- inventory_feature_data(
  input_dir = here("data/processed"),
  output_dir = here("data/log")
)
```

    ## ✔ ✅ Feature data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/feature_file_inventory.csv'

    ## ℹ → Duplicates summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/duplicate_feature_summary.csv'

### 2.2. Run Raster Inventory Script

This step inventories raster outputs in `data/processed/`, including
.tif, .bil, .img, and associated header/sidecar files. These may include
climate normals, terrain rasters, or derived surfaces used as
covariates.

``` r
result_rast_processed <- inventory_raster_data(
  input_dir = here("data/processed"),
  output_dir = here("data/log")
)
```

    ## ✔ ✅ Raster data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raster_data_inventory.csv'

    ## ℹ → Duplicate summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/duplicate_raster_data_summary.csv'

## Part 3: Check Results

UPDATE

``` r
# Load feature results
files_processed_vec <- read_csv(here("data/log",
                                     "feature_file_inventory.csv"),
                                show_col_types = FALSE) %>%
  select(file_type, relative_path, possible_duplicate) %>%
  separate(
    col = relative_path,
    into = c("folder", "file"),
    sep = "/",
    extra = "merge",
    fill = "right"
  ) %>%
  arrange(file_type, folder) %>%
  mutate(data_type = "vector")

# Load raster results
files_processed_rast <- read_csv(here("data/log",
                                      "raster_data_inventory.csv"),
                                 show_col_types = FALSE) %>%
  select(file_type, relative_path, possible_duplicate) %>%
  separate(
    col = relative_path,
    into = c("folder", "file"),
    sep = "/",
    extra = "merge",
    fill = "right"
  ) %>%
  arrange(file_type, folder) %>%
  mutate(data_type = "raster")

# Combine and summarize
files_processed_all <- bind_rows(files_processed_vec, files_processed_rast) %>%
  relocate(data_type, file_type, folder, file)

files_processed_summary <- files_processed_all %>%
  count(data_type, folder, file_type, possible_duplicate) %>%
  arrange(folder)

full_summary <- full_join(files_raw_summary, files_processed_summary, 
                  by = join_by(data_type, folder),
                  suffix = c(".raw", ".processed"),
                  relationship = "many-to-many"
                  ) %>%
  select(-starts_with("possible")) %>%
  arrange(folder)

# Save summary
write_csv(full_summary,
          here("data/log/summary_processed_data_files.csv"))
```

USE KABLE HERE

``` r
flowlines <- files_raw_vec %>%
  filter(folder == "nhdphr_flowlines") %>%
  select(file)

catchments <- files_raw_vec %>%
  filter(folder == "nhdphr_catchments")  %>%
  select(file)

dups <- anti_join(flowlines, catchments)
```

    ## Joining with `by = join_by(file)`

CHECK THE CSV DATA – there is a difference in the numbers
