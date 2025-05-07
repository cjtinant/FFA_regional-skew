README – FFA Regional Skew Estimation
================

- [Project Description](#project-description)
  - [Overview](#overview)
  - [Goals and Objective](#goals-and-objective)
  - [Layout of Analysis](#layout-of-analysis)
  - [Project Milestones](#project-milestones)
  - [Project Structure (as of v0.3)](#project-structure-as-of-v03)
  - [Getting Started](#getting-started)
  - [Reproducibility](#reproducibility)
  - [Reports and Milestone Logs](#reports-and-milestone-logs)
  - [Covariate Metadata](#covariate-metadata)
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

## Goals and Objective

The primary goal of this phase is to explain spatial variation in
station skew — the log-Pearson Type III skew coefficient estimated at
individual stream gages — using a set of numeric covariates derived from
data related to: Ecological Regions (Ecoregions), Location, Climate,
Topography, Watershed Characteristics, Land Cover Characteristics.

## Layout of Analysis

I adopted a multi-scale hierarchical framework with variables organized
by spatial scale and domain (below). The largest spatial scale is a
custom macroregion based on prairie grassland type, which was derived
from Level II Ecoregions. Other spatial scales include a regional scale
at the Level II Ecoregion extent, a subregional scale at the Level III
Ecoregion extent, and a local catchment level scale at the NHD+ extent
(Figure 2).

| Scale | Extent | Climate | Land Cover | Topography | Watershed | Total |
|:---|:---|---:|---:|---:|---:|---:|
| Macroregional | Custom Macrozone | 3 | 4 | 3 | 3 | 13 |
| Regional | Level II Ecoregion | 4 | 4 | 4 | 5 | 17 |
| Subregional | Level III Ecoregion | 6 | 2 | 4 | 3 | 15 |
| Local | NHD+ catchments | 3 | 2 | 8 | 4 | 17 |

Table: Variable Count

| scale | domain | variable | type | source_dataset |
|:---|:---|:---|:---|:---|
| Macroregional | Ecoregion | Great Plains macrozone (e.g., tallgrass, shortgrass, semiarid) | categorical | Custom classification from Level II ecoregion |
| Macroregional | Location | Gage locations | spatial | Derived from ecoregion shapefiles |
| Macroregional | Climate | Regional climate PC1–PC2 (or Köppen subtype) | numeric / categorical | PRISM / WorldClim / Köppen maps |
| Macroregional | Topography | Mean elevation, broad slope | numeric | NED / DEM elevation raster |
| Macroregional | Watershed | Mean basin area per macrozone | numeric | Derived from basin shapefiles or NHD+ |
| Macroregional | Land Cover | Dominant vegetation / NLCD cover class | categorical | NLCD (National Land Cover Database) |
| Regional | Ecoregion | Level II ecoregion (9.2–9.6) | categorical | EPA Level II ecoregions |
| Regional | Location | Regional centroid or HUC4 region | spatial | USGS Watershed Boundaries / HUC4 |
| Regional | Climate | Seasonal precip/temp normals, precipitation regime (e.g., monsoon index) | numeric | PRISM climate normals |
| Regional | Topography | Slope distribution (e.g., % flat, % steep) | numeric | Derived from elevation (NED) or slope raster |
| Regional | Watershed | Stream density, average flow length | numeric | NHD+ flowlines or catchment shapefiles |
| Regional | Land Cover | Seasonal NDVI or cover change metrics | numeric | MODIS NDVI or seasonal land cover |
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

``` r
source_data <- hierarchical_variables %>%
  select(source_dataset)
```

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

## Reports and Milestone Logs

To explore the evolution of the project structure, covariate design, and
documentation practices, see: 📁
[`reports/README.md`](reports/README.md) — Overview of all milestone
logs, reference tools, and future plans

## Covariate Metadata

This project includes a structured covariate metadata file to support
reproducibility, clarity, and consistency in modeling regional skew. The
metadata defines each covariate’s name, description, units, analytical
resolution, and conceptual grouping.

### Purpose

The covariate metadata documents all variables used in regional skew
modeling and spatial stratification. It is designed to ensure:

- consistent naming across scripts and visualizations,

- interpretable plots and maps,

- scalable use across spatial resolutions and modeling domains.

### Source

The original .xlsx file is stored as:
`docs/skew_covariates_metadata_v01.xlsx`

Older working versions are archived in: `docs/delete_later/`

### Script and Output Location

The script used to generate modular .csv files:
`docs/01_split-xlsx-into-csv.R`

Output .csv files (one per worksheet): `docs/covariates_metadata_split/`

### QA / Validation

A multi-step metadata quality checklist was used to validate content
before export. This includes checks for:

- completeness of key fields,

- consistency in phrasing and formatting,

- conceptual alignment across scales and groups,

- clarity and interpretability of variable description

## Versioning

Tagged versions: - **`v0.3-structure-refactor`** – Major restructure of
project folders and files
