Milestone 00 — Project Structure Refactor
================
C.J. Tinant
May 10, 2025

- [Overview of v0.4](#overview-of-v04)
  - [Covariate Metadata](#covariate-metadata)
- [Summary of Changes](#summary-of-changes)
- [Project structure (v0.3)](#project-structure-v03)
  - [Original project structure](#original-project-structure)
  - [Updated File Structure (v0.3)](#updated-file-structure-v03)
- [Refactor project structure (v0.4)](#refactor-project-structure-v04)
  - [Migration Checklist – v0.4](#migration-checklist--v04)
  - [v0.3 & v0.4 Step-by-Step Refactor
    Log](#v03--v04-step-by-step-refactor-log)

# Overview of v0.4

This document describes the structure and metadata setup completed for
**Milestone v0.4**.

This document tracks the **project structure refactor** for a project to
estimate regional skew of the annual flood series for the Great Plains
ecoregion. The reorganization improves clarity, modularity, and
reproducibility by aligning files with milestone workflows and standard
naming conventions.

Additionally, this document tracks the **development of a structured
covariate metadata file** to support reproducibility, clarity, and
consistency in modeling regional skew. The metadata defines each
covariate’s name, description, units, analytical resolution, and
conceptual grouping.

## Covariate Metadata

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

# Summary of Changes

This milestone documents a major restructuring of the project folder
hierarchy, archiving legacy files, and organizing scripts into modular
milestone-based subfolders. Additionally, this milestone introduces the
hierarchical covariate framework and macrozone classification for Great
Plains analysis and develops covariate metadata. The following changes
were made to the project:

- Soft-archived old scripts and notebooks

- Modularized `R/` folder structure with numbered milestones

- Consolidated utility functions into a reusable location

- Moved and modularized R scripts into milestone-based folders

- Moved and renamed and organized shapefiles for clarity

- Reorganized this Rmd to improved clarity

- Identified and documented covariates with metadata

- Replaced legacy `.gitignore` with spatial-aware template

- Standardized naming tp improve long-term maintainability

- Developed a consistent naming strategy for data folders and files

- Refactored this milestone – moved download-related steps to
  milestone_01

------------------------------------------------------------------------

# Project structure (v0.3)

## Original project structure

``` text
    FFA_regional-skew/
    ├── arcgis_project/    # ArcGIS files
    ├── data/
    │   ├── raw/           # Raw downloads (PRISM, USGS, etc.)
    │   ├── clean/         # Cleaned covariate & skew datasets
    │   ├── meta/          # # Metadata for reproducibility
    │   └── spatial/       # Spatial data for ecoregions (EPA)
    ├── figures/           # Plots and heatmaps
    ├── functions/         # Reusable R functions
    ├── references_pdfs/   # Background readings
    ├── model_summaries/   # CSVs of model coefficients, VIFs, etc.
    ├── results/           # Rmd files from prior EDA
    ├── scripts/           # Modular R scripts by milestone
    ├── README.Rmd         # Workflow overview (editable)
    ├── README.md          # Rendered Markdown output
    └── .gitignore         # Prevents sensitive/local files from being pushed
```

## Updated File Structure (v0.3)

``` text
FFA_regional-skew/
├── .gitignore                    # Prevents sensitive/local files from being pushed
├── arcgis_project/               # Stores `.aprx` and layer files from ArcGIS 
                                  #   Pro workflows

├── data/ 
│   ├── raw/                      # Unmodified input data 
                                  #   e.g., shapefiles, CSVs, rasters
│   │   ├── elevation_ned.tif
│   │   ├── sites_all_in_bb.csv
│   │   ├── sites_all_peak_in_bb.csv
│   │   ├── raster_raw/          # PRISM rasters
│   │   └── vector_raw/          # Shapefiles (unprojected/unprocessed)
│   │       ├── ecoregions_orig/
│   │       ├── ecoregions_unprojected/
│   │       ├── koppen-climate-classification/
│   │       ├── us_eco_lev01/ through us_eco_lev04/
│   │       └── misc shapefiles/

│   ├── processed/               # Cleaned, derived datasets

│   │   ├── spatial/             # Ready-to-use shapefiles and rasters
│   │   │   ├── us_eco_lev01/
│   │   │   ├── us_eco_lev02/
│   │   │   ├── us_eco_lev03/
│   │   │   ├── us_eco_lev04/
│   │   │   ├── koppen_climate/
│   │   │   ├── tl_state_boundaries/
│   │   │   └── derived_products/
│   └── meta/                    # CRS info, variable scaffold, project metadata
│       └── variable_scaffold.csv

├── docs/                     # Project documentation, e.g., final reports, 
                              #   manuscripts, proposal materials. 
                              # Reference documentation like README-style guides. 
                              # Metadata crosswalks and data dictionaries
                              # review or publication. 
                              # Files you reference in Quarto/PDF reports or posters

├── FFA_regional-skew.Rproj   # RStudio project file for launching the 
                              # workspace. Keep this in the root.
├── log/                      # For shell logs or targets progress reports 
├── notebooks/                # For ad hoc .Rmd or .qmd experiments 
├── notes/                    # Personal or team notes, meeting logs, brainstorms
                              #   Could be transitioned to Markdown or Quarto as
                              #   the project matures

├── output/                   # Intermediate outputs (e.g., `.Rds`, `.csv`, `.tif`)
                              # Next Steps: Add subfolders like `extracted/`,
                              #   `joined/`, or date-stamped folders |
│   ├── figs/                 # Plots and maps
│   ├── models/               # Model objects (.rds)
│   └── tables/               # Summary tables (.csv, .html)

├── R/                        # All analysis scripts (milestone-organized)
│   ├── 01_download/          # NWIS, PRISM, Ecoregions
│   ├── 02_clean/             # Filtering, QA, station skew
│   ├── 03_covariates/        # Climate, topography, land cover
│   ├── 04_modeling/          # GAMs, Elastic Net, correlation
│   ├── 05_eval/              # Model diagnostics, residuals, validation
│   └── utils/                # Reusable functions
│       └── f_process_geometries.R

├── README.md                     # Rendered Markdown output.  GitHub-compatible
                                  #   plain-text overview. Use for quick 
                                  #   navigation, build instructions, etc. 
├── README.Rmd                    # Workflow overview (editable).  Richer,
                                  #   knit-ready documentation with figures, 
                                  #  tables, and references. Can generate 
                                  #   HTML/PDF documentation from this file

├── reports/                      # analysis narratives, usually knitted `.Rmd` 
                                  #   or `.qmd` output. Next Steps: Consider 
                                  #   `reports/final/`, `reports/draft/` 
                                  #   structure if versioning

├── results/                      # Manuscript-ready outputs, model metrics, 
                                  #   final figures, tables, model outputs for 
                                  #   publication or reporting Next Steps: 
                                  #   Organize by milestone or product:
                                  #     `maps/`, `tables/`, `models/`
│   ├── posterdown/                 # Poster files and assets
│   └── slides/                     # Slide decks or visualizations

├── to_check/                    # Temporary holding area for uncertain or 
                                 #   transitional files needing review or QA. 
                                 # Next Steps: Consider renaming to `sandbox/` 
                                 # and clearing regularly.
```

------------------------------------------------------------------------

# Refactor project structure (v0.4)

## Migration Checklist – v0.4

| Step      | Task                                                  | Status |
|-----------|-------------------------------------------------------|--------|
| 0.3.1     | Soft archive old files                                | \[X\]  |
| 0.3.2     | Create folders for each milestone step                | \[X\]  |
| 0.3.3     | Move functions/ to R/utils/ and source with source()  | \[X\]  |
| 0.3.4     | Rename scripts/ to R/ and split by milestone function | \[X\]  |
| 0.3.5     | Move raw shapefiles to data/raw/spatial_raw/          | \[X\]  |
| 0.3.6     | Move cleaned shapefiles to spatial/                   | \[X\]  |
| \* 0.4 \* | Identified a need to update covariates                | \[X\]  |
| 0.4.1     | Reorganize this Rmd                                   | \[X\]  |
| 0.4.2     | Identify and document covariates                      | \[X\]  |
| 0.4.3     | Validate and document Notes folder                    | \[X\]  |
| 0.4.4     | Update raw data/ folder structure / naming strategy   | \[X\]  |
| 0.3.7     | \*\* Updated \*\* Move steps to milestone_01          | \[X\]  |
| 0.3.8     | Update GitHub Milestone and Issue                     | \[X\]  |
| 0.3.9     | Document final changes in this .Rmd                   | \[X\]  |
| 0.3.10    | Document final changes in README.Rmd                  | \[X\]  |
| 0.3.11    | Tag this commit in Git as v0.3-structure-refactor     | \[X\]  |

## v0.3 & v0.4 Step-by-Step Refactor Log

### Step 0.3.1 - Soft archive old files

- **Action:** Move unverified/legacy files to to_check/ or delete/ with
  caution.

- **Before:** Unorganized files that may or may not be aligned with
  current project workflow.

- **Reason:** Improves clarity, modularity, and reproducibility of
  workflow.

- **After:** Cleaner directory structure.

### Step 0.3.2 — Create files for each milestone step

- **Reason:** Improves clarity, modularity, and reproducibility of
  workflow.

- **Before:** Files partially aligned with milestone workflows. Ad hoc
  naming convention.

- **After:** Separate raw/, clean/, meta/, functions/, and output/.
  Spatial data organized and modularized.

### Step 0.3.3 - Move functions into a unified utils/ folder

- **Reason:** Centralize and reuse processing functions.

- **Before:** functions/f_process_geometries.R

- **After:** R/utils/f_process_geometries.R

- **Scripts affected:** Any sourcing functions/; update to
  source(“R/utils/…”)

### Step 0.3.4 — Split and organize scripts/ into milestone-based folders

- **Reason:** Improves modularity and tracks workflow by purpose.

- **Before:** All code in scripts/

- **After:** R/utils/f_process_geometries.R

``` text
R/
├── 01_download/
├── 02_clean/
├── 03_covariates/
├── 04_modeling/
├── 05_eval/
```

- **Scripts affected:** All main workflow scripts.

### Step 0.3.5 — Move raw spatial and climate data into data/raw/

- **Reason:** Distinguish between raw inputs and processed outputs.

- **Before:** data/spatial/ held both raw and derived data

- **After:** R/utils/f_process_geometries.R

``` text
data/
├── raw/
│   ├── raster_raw/       # Ecoregions, Koppen, PHZM, etc.
│   ├── vector_raw/
```

- **Folders moved:** ecoregions, koppen-climate-classification, phzm,
  us_eco

### Step 0.3.6 — Promote Processed Spatial Layers to /spatial/

- **Reason:** Maintain easy access to ready-to-use shapefiles.

- **Before:** Mixed with raw

- **After:** R/utils/f_process_geometries.R

``` text
spatial/
├── us_eco_lev01/
├── us_eco_lev02/
├── koppen_cleaned/
```

### Step 0.4.1 — Update project structure refactor report

- **Action:** Update project structure refactor report (this Rmd).
  Tasks: Reorganize report sections. Update file folder structure
  metadata. Create missing file folders in FFA.

- **Reason/Before:** Unclear project workflow and documentation.
  Differences between project file structure and file structure
  metadata.

- **After:** Improves readability, clarity, consistency of report.
  Provides consistent naming across project

### Step 0.4.2 — Identify and document covariates

- **Action:** Identify covariates. Create and validate covariate
  metadata,

- **Reason/Before:** Covariates not structured spatially or by domain.

- **After:** The covariate framework is hierarchically organized across
  five spatial scales, ranging from station-level (scale 0) to local,
  subregional, regional, and macroregional levels (scales 1–4), and four
  major domains: Climate, Land Cover, Topography, and Watershed Metrics.
  The covariate metadata documents all variables used in regional skew
  modeling and spatial stratification.

| Level | Scale | Extent | Climate | Land Cover | Topography | Watershed | Total |
|---:|:---|:---|---:|---:|---:|---:|---:|
| 0 | Station-level | Point-derived | 2 | 0 | 1 | 1 | 4 |
| 1 | Macroregional | Custom Macrozone | 3 | 4 | 3 | 0 | 10 |
| 2 | Regional | Level II Ecoregion | 4 | 4 | 4 | 5 | 17 |
| 3 | Subregional | Level III Ecoregion | 6 | 2 | 4 | 3 | 15 |
| 4 | Local | NHD+ catchments | 3 | 2 | 8 | 4 | 17 |

Table: Covariate Count Organized by Domain and Scale

### Step 0.4.3 — Validate and document Notes folder

- **Action:** Added notes folder to Git

- **Before/Reason:** Notes folder was not included in Git, as clear
  notes on method had not been compiled

- **After:** Notes folder contains discussion how zonal statistics will
  be calculated and other notes regarding covariates.

### Step 0.4.4 — Document raw data/ folder structure / naming strategy

- **Action:** Documented a naming strategy in
  reports/milestones_01_download scripts

- **Before/Reason:** Inconsistent naming strategy – led to a lot of
  confusion

- **After:** Adopted a Subdirectory Strategy for folders and a
  [source](#source)*\[layer\]*\[year\|version\]\_\[status\].\[ext\]
  strategy for naming.

### Step 0.3.7 – Refactor and Modularize

- **Action:** Created sub-issue `v0.4` under Milestone 00. Moved
  script-related steps (e.g., downloading covariate data) to **Milestone
  01 – Data Download and Preparation**. Closed the sub-issue after
  restructuring.

- **Reason (Before):** Covariate identification and metadata creation
  required their own distinct milestone. The original milestone was too
  broad.

- **Result (After):** Project structure is now better modularized by
  task and milestone. Documentation and code are easier to maintain.

### Step 0.3.8 – Update GitHub Milestone

- **Action:** Updated GitHub Milestone 00 title and description to
  reflect changes in scope and tagging.

### Step 0.3.9 – Final Edits to Documentation

- **Action:** Updated this .Rmd file with a GitHub-friendly YAML header.
  Ensured clarity, TOC, and version parameter (params\$version: “v0.4”).

### Step 0.3.10 – README Update

- **Action:** Edited README.Rmd and README.md to reflect the current
  project structure and metadata paths.

### Step 0.3.11 – Git Commit and Tag

- **Action:** Committed changes to Git, including output and
  documentation files. Tagged the repository as v0.4.
