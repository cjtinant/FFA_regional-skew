Review and Inventory of Spatial and Tabular Data
================
CJ Tinant
2025-07-21 10:19:05

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
- [Part 4: Validate Metadata](#part-4-validate-metadata)
  - [Validate Spatial Data](#validate-spatial-data)

## Overview

The goal is to inventory, validate, and document feature (vector and
tabular) and raster datasets stored in the data/ directory, with a focus
on identifying duplicates, standardizing file structure, and preparing
inputs for covariate extraction in the regional skew model. Output from
code-chunks are used by scripts in `R/02_clean_validate`

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
knitr::opts_chunk$set(echo = FALSE)

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

    ## ✔ ✅ Raster data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raw_raster/raster_data_inventory.csv'

    ## ℹ → Duplicate summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raw_raster/duplicate_raster_data_summary.csv'

### 1.3. Move Archived ZIPs

The following step identifies zip files from subdirectories of
`data/raw/` and relocates to `data/raw/archives`. This ensures that
archived download packages are stored separately from unzipped raster
inputs. The step is not used in the current modeling workflow.

### 1.4. Check Results

### 1.5. Remove Unneeded Climate Rasters

The following step identifies legacy koppen-climate rasters representing
time periods prior to 1990. These files are not used in the current
modeling workflow and may be removed following QA and confirmation.

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

    ## ✔ ✅ Feature data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/feature_file_inventory.csv'

    ## ℹ → Duplicates summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/duplicate_feature_summary.csv'

### 2.2. Run Raster Inventory Script

This step inventories raster outputs in `data/processed/`, including
.tif, .bil, .img, and associated header/sidecar files. These may include
climate normals, terrain rasters, or derived surfaces used as
covariates.

    ## ✔ ✅ Raster data inventory complete.

    ## ℹ → Full inventory saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/raster_data_inventory.csv'

    ## ℹ → Duplicate summary saved to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/data/log/duplicate_raster_data_summary.csv'

## Part 3: Check Results

This section loads saved logs and summarises results

## Part 4: Validate Metadata

### Validate Spatial Data

This step validates CRS, resolution, and spatial extent of raster and
vector files in `data/processed/`. The script that creates the output is
`02e_validate_spatial_metadata.R`
