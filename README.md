Regional Skew Estimation Project
================

- [Overview](#overview)
- [Folder Structure](#folder-structure)
- [Workflow Overview](#workflow-overview)
- [Data Notes](#data-notes)
  - [PRISM Climate Normals](#prism-climate-normals)
  - [USGS Peak Flow Data](#usgs-peak-flow-data)
- [Reproducibility Notes](#reproducibility-notes)
  - [Coordinate Reference Systems
    (CRS)](#coordinate-reference-systems-crs)
- [Dependencies](#dependencies)
- [Citation](#citation)

# Overview

This project supports the development of regional skew estimation for
flood frequency analysis (FFA) across the Great Plains and adjacent
regions. The workflow automates downloading, cleaning, and organizing
USGS and PRISM data for unregulated stream gages with sufficient record
length.

The project follows a reproducible, modular workflow using R and the
`{tidyverse}`.

# Folder Structure

    FFA_regional-skew/
    ├── data/
    │   ├── raw/           # Original downloaded data (PRISM, USGS, ecoregions)
    │   ├── clean/         # Cleaned data ready for modeling
    │   └── meta/          # Metadata for all datasets
    │
    ├── scripts/           # Numbered R scripts for each workflow milestone
    ├── functions/         # Reusable R functions
    ├── README.Rmd         # This file (source)
    ├── README.md          # Rendered output
    └── .gitignore         # Prevents sensitive/local files from being pushed

# Workflow Overview

| Milestone | Script | Purpose | Output(s) |
|----|----|----|----|
| 01 | 01_get_spatial_data.R | Download & prepare spatial data (bounding box, HUC, eco). | `/data/raw/spatial/` shapefiles |
| 02 | 02_get_gage_data.R | Query USGS NWIS peak flow data for all sites in study area. | `/data/raw/sites_all_peak_in_bb.csv` |
| 03 | 03_filter_unregulated_gage_data.R | Filter to unregulated sites with ≥20 years of data. | `/data/clean/data_pk_unreg_gt_20.csv` |
| 04 | 04_find_clean_export_site_summaries.R | Query site metadata from NWIS and WQP, clean, export. | `/data/clean/site_summary_NWIS_clean.csv` |
| 05 | 05_update_problem_sites.R | Remove sites with missing/zero peaks or \<20 observations. | Updated site and data files |
| 06 | 06_calculate_station_skew.R | Calculate log-Pearson III station skew for each site. | `/data/clean/station_skew.csv` |
| 07 | 07_download_climate_covariates.R | Download & extract PRISM climate normals to gage sites. | `/data/clean/data_covariates_climate.csv` |
| 08 | 08_download_terrain_covariates.R | Download & extract elevation & slope covariates (planned). | `/data/clean/data_covariates_terrain.csv` |

# Data Notes

## PRISM Climate Normals

- Source: <https://prism.oregonstate.edu/normals/>
- Resolution: 4km gridded .bil rasters
- Time period: 1991-2020
- Variables:
  - Monthly & Annual Total Precipitation (mm)
  - Monthly & Annual Mean Temperature (°C)

## USGS Peak Flow Data

- Queried via `{dataRetrieval}` package
- Includes:
  - Annual peak flows
  - Site metadata
  - Regulation flags
  - Record length

# Reproducibility Notes

## Coordinate Reference Systems (CRS)

| Dataset       | CRS   | EPSG | Notes                            |
|---------------|-------|------|----------------------------------|
| PRISM         | NAD83 | 4269 | Native raster CRS                |
| USGS Sites    | WGS84 | 4326 | Transformed to NAD83 later       |
| Final Outputs | NAD83 | 4269 | All data harmonized for modeling |

# Dependencies

``` r
library(tidyverse)
library(here)
library(sf)
library(terra)
library(prism)
library(janitor)
library(dataRetrieval)
library(glue)
```

# Citation

> Daly, C., et al. (2008). Physiographically-sensitive mapping of
> temperature and precipitation across the conterminous United States.
> *International Journal of Climatology*, 28(15), 2031-2064.

> USGS NWIS Data retrieved using `{dataRetrieval}` R package.
