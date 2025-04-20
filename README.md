README – FFA Regional Skew Estimation
================

- [Project Description](#project-description)
  - [Overview](#overview)
  - [Current Objective](#current-objective)
  - [Layout of Analysis](#layout-of-analysis)
  - [Project Milestones](#project-milestones)
  - [Project Structure (as of v0.3)](#project-structure-as-of-v03)
  - [Getting Started](#getting-started)
  - [Reproducibility](#reproducibility)
  - [Versioning](#versioning)

# Project Description

## Overview

This project supports the estimation of regional skew coefficients for
flood frequency analysis in the Great Plains. It emphasizes
reproducibility, modular data workflows, and the integration of spatial
and climatic covariates.

The workflow uses R and {tidyverse} tools to automate the download,
cleaning, joining, and modeling of covariate data associated with gage
locations. Covariates include climate normals, terrain characteristics,
and site location variables.

## Current Objective

The primary goal of this phase is to explain spatial variation in
station skew — the log-Pearson Type III skew coefficient estimated at
individual stream gages — using a set of numeric covariates derived
from:

- Climate normals (precipitation and temperature)

- Terrain data (elevation and slope)

- Site location (latitude and longitude)

## Layout of Analysis

To explore the spatial and temporal drivers of flood skewness across
diverse landscapes and climates, we adopt a multi-scale hierarchical
framework. Variables are organized by spatial-temporal scale, ecological
domain, and data type.

| scale | domain | variable | type | source_dataset |
|:---|:---|:---|:---|:---|
| Macro-regional (within GP) | Ecoregion | Great Plains macrozone (e.g., tallgrass, shortgrass, semiarid) | categorical | Custom classification from Level II ecoregion |
| Macro-regional (within GP) | Location | Macrozone centroid or bounding box | spatial | Derived from ecoregion shapefiles |
| Macro-regional (within GP) | Climate | Regional climate PC1–PC2 (or Köppen subtype) | numeric / categorical | PRISM / WorldClim / Köppen maps |
| Macro-regional (within GP) | Topography | Mean elevation, broad slope | numeric | NED / DEM elevation raster |
| Macro-regional (within GP) | Watershed | Mean basin area per macrozone | numeric | Derived from basin shapefiles or NHD+ |
| Macro-regional (within GP) | Land Cover | Dominant vegetation / NLCD cover class | categorical | NLCD (National Land Cover Database) |
| Regional (Level II) | Ecoregion | Level II ecoregion (9.2–9.6) | categorical | EPA Level II ecoregions |
| Regional (Level II) | Location | Regional centroid or HUC4 region | spatial | USGS Watershed Boundaries / HUC4 |
| Regional (Level II) | Climate | Seasonal precip/temp normals, precipitation regime (e.g., monsoon index) | numeric | PRISM climate normals |
| Regional (Level II) | Topography | Slope distribution (e.g., % flat, % steep) | numeric | Derived from elevation (NED) or slope raster |
| Regional (Level II) | Watershed | Stream density, average flow length | numeric | NHD+ flowlines or catchment shapefiles |
| Regional (Level II) | Land Cover | Seasonal NDVI or cover change metrics | numeric | MODIS NDVI or seasonal land cover |
| Subregional (Level III) | Ecoregion | Level III ecoregion | categorical | EPA Level III ecoregions |
| Subregional (Level III) | Location | Station-specific coordinates | numeric | Gage lat/lon from NWIS |
| Subregional (Level III) | Climate | Monthly precip/temp normals, Köppen subtype | numeric / categorical | PRISM monthly normals / Köppen subtypes |
| Subregional (Level III) | Topography | Topo roughness, elev range, TWI | numeric | DEM-derived terrain metrics (TWI, roughness) |
| Subregional (Level III) | Watershed | NHD+ catchment metrics (e.g., area, stream order) | numeric | NHD+ catchment summary table |
| Subregional (Level III) | Land Cover | Land use diversity index (Shannon, Simpson) | numeric | Calculated from NLCD or MODIS classifications |
| Local (Level IV / catchments) | Ecoregion | Level IV ecoregion | categorical | EPA Level IV ecoregions |
| Local (Level IV / catchments) | Location | Site and catchment spatial footprint | spatial | Catchment or HUC12 boundary polygons |
| Local (Level IV / catchments) | Climate | Submonthly anomalies, snowmelt indicators | numeric | PRISM or downscaled model products |
| Local (Level IV / catchments) | Topography | Curvature, slope aspect, local ruggedness | numeric | Terrain analysis (curvature, aspect) |
| Local (Level IV / catchments) | Watershed | Local runoff potential or soil permeability | numeric | SSURGO / STATSGO soils or DEM runoff index |
| Local (Level IV / catchments) | Land Cover | MODIS land cover diversity (TBD) | categorical | MODIS / NLCD land cover composition |

Table: Hierarchical Variable Scaffold for Skew Modeling in the Great
Plains

## Project Milestones

Current version: v0.3 – Refactored Project Structure See
[milestone_00_project_structure_refact.Rmd](reports/milestone_00_project_structure_refact.Rmd)
for detailed changelog.

------------------------------------------------------------------------

## Project Structure (as of v0.3)

    FFA_regional-skew/ 
    ├── R/01_download/              # Raw data scripts (e.g., NWIS, PRISM) 
    ├── R/02_clean/                 # QA/QC and filtering 
    ├── R/03_covariates/            # Covariate derivation (e.g., climate, terrain) 
    ├── R/04_modeling/              # Elastic Net, GAMs 
    ├── R/05_eval/                  # Model validation 
    ├── R/utils/                    # Shared helper functions 
    ├── data/
    │ ├── data/meta/                # metadata on original data
    │ ├── data/raw/                 # Original shapefiles, PRISM data, etc. 
    │ ├── data/processed/           # Cleaned spatial and tabular data 
    ├── output/                     # Model objects, plots, tables 
    ├── results/                    # Final publication outputs 
    ├── reports/                    # Poster, slides, milestone logs 
    ├── to_check/                   # Temporary drafts 
    ├── FFA_regional-skew.Rproj 
    ├── README.Rmd                  # Workflow overview (editable)
    ├── README.md                   # Rendered Markdown output
    └── .gitignore                  # Prevents sensitive/local files being pushed

## Getting Started

Run scripts in order within the `R/` folder. For example:

    source("R/01_download/01_get_spatial_data.R")
    source("R/02_clean/03_filter_unregulated_gage_data.R")

All scripts assume R project is opened at the repository root (e.g.,
using .Rproj file).

------------------------------------------------------------------------

## Reproducibility

This project uses: - `.gitignore_spatial_template.txt` to exclude large
geospatial files - `git_commit_reference_card.txt` for consistent commit
messages - Modular milestone logs (see `reports/`) to track key
development stages

## Versioning

Tagged versions: - **`v0.3-structure-refactor`** – Major restructure of
project folders and files
