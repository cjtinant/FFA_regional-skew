Milestone 01 — Download and Prepare Covariates
================
C.J. Tinant
July 22, 2025

- [Overview of v1.4](#overview-of-v14)
  - [Goals](#goals)
- [Project Structure](#project-structure)
- [v1.4 – Download and Prepare
  Covariates](#v14--download-and-prepare-covariates)
- [v1.4 Tasklist](#v14-tasklist)
- [Changelog Format: Per-Step
  Narrative](#changelog-format-per-step-narrative)

# Overview of v1.4

This document outlines the setup, documentation, and reproducibility
scaffolding established for **Milestone v1.4**, focused on acquiring and
validating spatial covariates for regional skew modeling.

This milestone builds on `v0.3-structure-refactor`.

### Summary

Initiate acquisition, validation, and preparation of climate, terrain,
and location-based covariates for use in regional skew estimation
models.

------------------------------------------------------------------------

## Goals

**Update the covariate source inventory:**

- Write or refactor download scripts  
- Document file sources and formats  
  [`covariate_source_inventory.md`](../docs/covariate_source_inventory.md)  
- Prepare spatial data  
  [`spatial_data_preparation_checklist.md`](../docs/spatial_data_preparation_checklist.md)  
- Acquire and clean metadata  
  [`metadata`](../data/meta)  
- Apply version control and tagging

# Project Structure

``` text
FFA_regional-skew/
├── .gitignore                    # Prevents sensitive/local files from being pushed
├── arcgis_project/              # ArcGIS Pro .aprx project and supporting layers
├── CHANGELOG.Rmd                # Human-readable changelog (semantic versioning)
├── data/                        # Raw, processed, meta, intermediate, and QA data
├── docs/                        # Documentation, workflow notes, metadata, checklists
├── FFA_regional-skew.Rproj      # RStudio project file (keep in root)
├── notebooks/                   # Ad hoc .Rmd/.qmd experiments (empty or minimal)
├── notes/                       # Team notes, meeting logs, brainstorms (convert to .md/.qmd)
├── R/                           # Analysis scripts (milestone-organized)
│   ├── 01_download/             # Download raw data
│   │   ├── _latex_preamble.tex                   # LaTeX preamble for PDF reports
│   │   ├── 01a_download_ecoregions.R             # Download U.S. ecoregions
│   │   ├── 01b_download_USGS_gage_data.R         # Download raw peak flow site data
│   │   ├── 01c_download_usgs_gage_metadata.R     # Download USGS site metadata
│   │   ├── 01d_download_usgs_peakflow_data.R     # Download peak flow data
│   │   ├── 01e_filter_usgs_peakflow_data.R       # Filter peak flow data
│   │   ├── 01f_download_nhdplus_v21_flowlines.R
│   │   ├── 01g_download_nhdplus_hr_catchments.R
│   │   ├── 01h_download_nhdplus_hr_flowlines.R
│   │   ├── 01j_download_koppen_geiger_climate.R
│   │   ├── 01k_download_plant_hardiness_zone_map.R
│   │   ├── 01l_download_prism_climate.R
│   │   ├── 01m_download_nlcd_2016.R
│   │   ├── 01n_download_ned.R
│   │   ├── 01o_download_modis_2016.R
│   │   └── 01p_download_statsgo2.R
│   ├── 02_clean_validate/      # QA scripts and validation checks
│   ├── 03_covariates/          # Covariate extraction: climate, terrain, land cover
│   ├── 04_modeling/            # Statistical modeling (GAMs, Elastic Net, etc.)
│   ├── 06_eval/                # Model diagnostics, residuals, validation
│   └── utils/                  # Reusable functions (organized by domain)
│       ├── metadata/
│       ├── spatial/
│       ├── qaqc/
│       ├── paths/
│       └── plotting/
├── README.md                   # GitHub-readable overview and navigation aid
├── README.Rmd                  # Editable RMarkdown version with richer formatting
├── reports/                    # Knitted .Rmd/.qmd milestone reports
│                               # Next: consider `reports/final/` and `reports/draft/`
├── results/                    # Manuscript-ready figures, models, and outputs
│   ├── maps/
│   ├── tables/
│   ├── models/
│   ├── posterdown/             # Poster files and assets
│   └── slides/                 # Slide decks and presentation visuals
├── sandbox/                    # Staging area for review
```

# v1.4 – Download and Prepare Covariates

# v1.4 Tasklist

| Step      | Task                                                 | Status |
|-----------|------------------------------------------------------|--------|
| **1.4.1** | Refine the Covariate Inventory                       | \[X\]  |
| **1.4.2** | Update folder structure                              | \[X\]  |
| **1.4.3** | Create / update download scripts for vector data     | \[X\]  |
| **1.4.4** | Create downloads script for raster covariates        | \[X\]  |
| **1.4.5** | QAQC for downloads                                   | \[X\]  |
| **1.4.6** | Knit milestone and data dictionary .Rmd files to PDF | \[X\]  |
| **1.4.7** | Document changes in 01_download README.Rmd           | \[X\]  |
| **1.4.8** | Commit and tag `v1.4-download-scripts`               | \[X\]  |

# Changelog Format: Per-Step Narrative

### Step 1.4.1 — Refine the Covariate Inventory

**Actions:**

- Finalized covariate list by domain (climate, terrain, land cover)
- Documented filenames, source URLs, formats, versioning, and priority
- Created reusable QA checklists and source tracking templates

**Reason (Before):**

The project lacked a centralized, versioned inventory of covariates.
Metadata was fragmented across exploratory scripts with no QA framework.

**Result (After):**

- Created `docs/covariate_source_inventory.md`
- Created `docs/spatial_data_preparation_checklist.md` for 12-step QA
- Updated `data/meta/covariates_metadata_schema.csv`
- Standardized metadata for reproducibility and audit tracking

------------------------------------------------------------------------

### Step 1.4.2 — Update Folder Structure for `utils/` and `data/`

**Actions:**

- Backed up project before restructuring
- Created new subfolders under `data/`: `raw/`, `processed/`, `meta/`,
  `log/`, `intermediate/`
- Created new utility folders in `R/utils/` for:
  - `metadata/`  
  - `spatial/`  
  - `qaqc/`  
  - `paths/`  
  - `plotting/`

**Reason (Before):**

Functions were embedded in monolithic scripts or scattered, limiting
reuse and debugging.

**Result (After):**

Utility functions are modular, testable, and purpose-scoped. Folder
structure supports test-driven development and script clarity.

------------------------------------------------------------------------

### Step 1.4.3 — Create / Update Download Scripts for Vector Data

**Actions:**

- Updated ecoregions, USGS gage, NHDPlus, and STATSGO2 download scripts
- Harmonized all vector outputs to EPSG:5070
- STATSGO2 spatial queries now chunked and geometry-validated

**Reason (Before):**

Inconsistent file structures, missing scripts, and fragile STATSGO2
queries.

**Result (After):**

All vector datasets reproducibly downloaded, spatially filtered to Great
Plains AOI, and exported to `data/raw/` and `data/processed/`. STATSGO2
joins are verified by `mukey`.

------------------------------------------------------------------------

### Step 1.4.4 — Create Download Scripts for Raster Covariates

**Actions:**

- Created modular download and processing scripts for:
  - Köppen-Geiger
  - USDA Plant Hardiness Zones
  - PRISM climate normals (via `{prism}`)
  - NLCD 2016
  - NED elevation and slope (via `{terra}`)
  - MODIS NDVI 2016 (via `{MODISTools}`)
- Standardized reprojection (EPSG:5070), clipping, and export

**Reason (Before):**

Raster layers were manually downloaded, inconsistently named, or lacked
projections.

**Result (After):**

All rasters downloaded, cleaned, and saved to `data/processed/` with
consistent filenames, formats, and CRS. Metadata written to
`data/meta/`.

------------------------------------------------------------------------

### Step 1.4.5 — QAQC for Downloads

**Actions:**

- Validated CRS, resolution, and extent across all vector and raster
  layers
- Created summary metadata export including layer name, type, CRS,
  resolution, extent, and notes
- Tagged `.Rmd` files with `{r name, eval=}` chunk headers for
  reproducibility
- Documented internal workflow in:
  - `git_changelog_workflow_reference.Rmd`
  - `spatial_data_preparation_checklist.Rmd`

**Reason (Before):**

Unvalidated spatial layers posed a risk of alignment errors.
Documentation was scattered or incomplete.

**Result (After):**

All layers validated for modeling compatibility. Scripts are now
reproducible, documented, and version-controlled. Project directories
are aligned with workflow logic and audit-ready.

------------------------------------------------------------------------

### Steps 1.4.6 to 1.4.8

**Actions**

This update focused on documenting and standardizing the spatial data
download scripts housed in R/01_download/. A new README.Rmd was created
to summarize the purpose, inputs, outputs, and dependencies of each
script. Workflow summaries and milestone cross-references were added to
all major download scripts to improve clarity and reproducibility.

**Reason (Before):**

Script headers were standardized to include consistent metadata and
dependency blocks. Export paths and file-saving logic were refined for
transparency, and minor cleanup was applied to ensure consistency across
the download workflow.

**Result (After):**

These updates improve maintainability and prepare the scripts for
downstream integration in covariate processing and modeling steps.
