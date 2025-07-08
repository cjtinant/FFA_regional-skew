Check Raw Data Files
================
CJ Tinant
2025-07-08 13:49:00

- [Overview](#overview)
- [Goals](#goals)
- [Workflow Part 1: Deduplication of Vector Spatial
  Files](#workflow-part-1-deduplication-of-vector-spatial-files)
  - [1. Inventory Vector Files](#1-inventory-vector-files)
  - [2. Summarize by Name and Size](#2-summarize-by-name-and-size)
  - [3. Save Results to CSV](#3-save-results-to-csv)
  - [4. Draft Cleanup Plan](#4-draft-cleanup-plan)
  - [5. Documentation](#5-documentation)
  - [Run Vector Deduplication Inventory
    Function](#run-vector-deduplication-inventory-function)
  - [Move Zipped Files to Archives](#move-zipped-files-to-archives)
- [Workflow Part 2: Deduplication of Vector Spatial
  Files](#workflow-part-2-deduplication-of-vector-spatial-files)
  - [1. Inventory Raster Files](#1-inventory-raster-files)
  - [2. Save Results to CSV](#2-save-results-to-csv)
  - [3. Draft Cleanup Plan](#3-draft-cleanup-plan)
  - [4. Documentation](#4-documentation)
  - [Run Raster Deduplication Inventory
    Function](#run-raster-deduplication-inventory-function)

## Overview

This document supports QA of raw spatial inputs used for regional skew
modeling. The goal is to inventory, validate, and deduplicate vector and
raster files within the data/raw/ directory prior to covariate
extraction.

## Goals

- ✅ Identify and remove duplicate files from data/raw
- ✅ Deduplicate and standardize raster inputs in data/raw/
- 🗂️ Organize spatial datasets by relevance, format, and source
- 📝 Document retained files in data/meta/spatial_source_checklist.csv

## Workflow Part 1: Deduplication of Vector Spatial Files

### 1. Inventory Vector Files

- List vector files recursively and flag potential duplicates

### 2. Summarize by Name and Size

- Group by basename
- Highlight different file sizes as potential version conflicts
- Flag preferred formats (e.g., keep .gpkg, review .shp)

### 3. Save Results to CSV

**Exported outputs:** - to_check/vector_file_inventory.csv – full file
list with duplicate flags - to_check/duplicate_vector_summary.csv –
filtered table of same-name files

### 4. Draft Cleanup Plan

- Move lower-priority duplicates to to_check/duplicates/
- Confirm projections and attribute consistency before deletion

### 5. Documentation

- Add exploratory summaries and notes on retained files
- Optionally create data/meta/spatial_source_checklist.csv
- Tag major cleanup step as v0.3.1-dedup-raw-vector
- Append to milestone_02_documentation.Rmd

### Run Vector Deduplication Inventory Function

``` r
result <- dedup_vector_inventory()
```

    ## ✔ ✅ Inventory complete. CSVs written to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/to_check'

### Move Zipped Files to Archives

``` r
source(here("R/utils/clean_organize_spatial_data/move_zip_to_archives.R"))
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

## Workflow Part 2: Deduplication of Vector Spatial Files

### 1. Inventory Raster Files

- Search .bil, .tif, .img, .zip, .hdr, .stx

- Flag files with same name and different sizes

- Group by basename and detect variations

### 2. Save Results to CSV

**Exported outputs:** - to_check/raster_file_inventory.csv – full file
list with duplicate flags - to_check/duplicate_vector_summary.csv –
filtered table of same-name files

### 3. Draft Cleanup Plan

- Move lower-priority duplicates to to_check/duplicates/
- Confirm projections and attribute consistency before deletion

### 4. Documentation

- Add exploratory summaries and notes on retained files
- Optionally create data/meta/spatial_source_checklist.csv
- Tag major cleanup step as v0.3.1-dedup-raw-vector
- Append to milestone_02_documentation.Rmd

### Run Raster Deduplication Inventory Function

``` r
source(here("R/utils/clean_organize_spatial_data/dedup_raster_inventory.R"))

result_ras <- dedup_raster_inventory()
```

    ## ✔ ✅ Inventory and duplicates written to '/Users/cjtinant/Documents/Rprojects_not-class/FFA_regional-skew/to_check'
