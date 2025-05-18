Milestone 01 — Download and Prepare Covariates
================
C.J. Tinant
May 18, 2025

- [Overview of v0.5](#overview-of-v05)
- [Goals](#goals)
- [Notes](#notes)
- [Standardized Script Naming
  Conventions](#standardized-script-naming-conventions)
- [Project Structure](#project-structure)
- [v0.5 – Download and Prepare
  Covariates](#v05--download-and-prepare-covariates)
- [v0.5 Tasklist](#v05-tasklist)
- [NEXT STEPS](#next-steps)
  - [├── gp_eco_levels.gpkg](#-gp_eco_levelsgpkg)
- [CREATE CUSTOM MACROREGIONS](#create-custom-macroregions)
- [Load Site Locations](#load-site-locations)
- [——————————————————————————](#section)
- [Make PRISM metadata](#make-prism-metadata)
- [accessed from
  https://prism.oregonstate.edu/fetchData.php](#accessed-from-httpsprismoregonstateedufetchdataphp)
- [and fed into ChatGPT](#and-fed-into-chatgpt)

## Overview of v0.5

This document outlines the setup, documentation, and reproducibility
scaffolding established for **Milestone v0.5**, focused on acquiring and
validating spatial covariates for regional skew modeling.

### Summary

Initiate acquisition, validation, and preparation of climate, terrain,
and location-based covariates for use in regional skew estimation
models.

See
[`spatial_data_preparation_checklist.md`](../docs/spatial_data_preparation_checklist.md)
for a reusable checklist used to guide and document preprocessing steps
across spatial layers.

## Goals

**Update the covariate source inventory**

- Downloading and staging spatial datasets (ecoregions, PRISM, NED,
  etc.)

- Documenting file sources and formats in `metadata/` and `docs/`

- Conducting initial QA checks on file completeness and coordinate
  reference systems

- Acquire, check, and document all raw covariate datasets

- Write or Refactor Download Scripts

- Spatial File QA + Metadata Logging

- Version Control & Tagging

## Notes

- This milestone builds on `v0.3-structure-refactor`

- README-style documentation will be embedded in this .Rmd file for
  reproducibility

## Standardized Script Naming Conventions

To improve clarity and reproducibility, scripts follow a standardized
naming format.

See: `R/00_setup/` and `data/raw/` for implementation scripts and
acquired data.

### Subdirectory Naming Convention:

Subdirectories are named to reflect the `workflow stage`, `data source`,
and `data domain or content category`, ensuring a transparent and
reproducible project structure.

Subdirectory naming follows the format: `[stage]/[source]_[category]/`

**Where:**

- `[stage]` – Workflow status or type (e.g., `raw`, `processed`, `meta`,
  `interim`)

- `[source]` – Data provider or system (e.g., `epa`, `prism`, `usgs`,
  `ned`, `nlcd`)

- `[category]` – Broad data content or theme (e.g., `ecoregions`,
  `30yrnormals`, `landcover`, `elev`, `catchments`

### Example Subdirectory Names

| Folder Path | Description |
|----|----|
| `data/meta/epa_ecoregions/` | Metadata or schema for EPA ecoregions shapefiles |

`data/raw/prism_30yrnormals/` \| Raw PRISM precipitation normals \|  
`data/processed/usgs_catchments/` \| Processed USGS NHDPlus catchments
\|

`data/interim/ned_elev/` \| Intermediate elevation surfaces (clipped or
reprojected) \|

### Script Naming Convention

Scripts follow a standardized naming format to promote readability,
automation, and chronological sequencing within the workflow.

`[step#]_[task]_[source].R or .Rmd`

**Where:**

- `[step#]` – A numeric and letter code (e.g., `01a`, `02b`, `03c`)
  indicating the execution order within a milestone.

- `[task]` – The primary action or processing stage (e.g., `download`,
  `check`, `extract`, `join`, `assign`, `summarize`)

- `[source]` – The data domain or specific dataset (e.g., `prism`,
  `gage`, `nlcd`, `elev_slope`, `ecoregion`)

#### Example Scripts:

| Script Name | Description |
|----|----|
| `01a_download_epa_ecoregions.R` | Download raw `peakflow gage` data |
| `01b_download_gage-data.R` | Download raw `peakflow gage` data |
| `01a_download_prism.R` | Download raw `prism` data |
| `01a_download_nlcd.R` | Download raw `nlcd` data |
| `01a_download_ned.R` | Download raw `ned` data |
| `01b_check_vector_sources.Rmd` | QA/QC for vector datasets (e.g., shapefiles) |
| `01c_check_raster_sources.Rmd` | Validate raster coverage, resolution, and projection |
| `01d_data_dictionary_covariates.Rmd` | Generate structured metadata and variable dictionary |
| `02a_download_gage_data.R` | Pull site and peak flow data from NWIS or WQP |
| `03a_extract_covariates_climate_prism.R` | Extract PRISM climate normals to gage locations |
| `03b_extract_covariates_terrain_elev_slope.R` | Extract elevation and slope metrics |
| `03c_assign_macrozone_covariates_L2.R` | Assign each site to a macrozone based on L2 ecoregions |

### Data Naming Convention

- Data naming follows:
  \[source\]*\[layer\]*\[year\|version\]\_\[status\].\[ext\].

**Where:**

- `[source]` – Data provider or domain (e.g., prism, usgs, epa)

- `[layer]` – Thematic content or variable (e.g., ppt, catchments,
  landcover, eco_l1)

- `[year|version]` – Dataset version, publication year, or climatology
  period (e.g., 2021, v21, 30yrnormals)

- `[status]` – Workflow stage (e.g., raw, clean, clipped, joined)

- `[ext]`– File extension (e.g., .shp, .tif, .bil, .csv)

#### Example filenames:

| Filename | Description |
|----|----|
| epa_eco_l1_us_raw.shp | EPA Level I ecoregions (US coverage), raw shapefile |
| prism_ppt_30yrnormals_raw.bil | PRISM precipitation 30-year normals, raw raster |
| usgs_nhdplus_catchments_v21_raw.shp | UUSGS NHDPlus V2.1 catchments, raw shapefile |
| usgs_nlcd_2016_raw.tif | USGS NLCD land cover for 2016, raw raster |

prism_tmean_2020_clipped.tif \| PRISM 2020 mean temperature, clipped to
study area  
ned_elev_2023_clean.tif \| NED elevation, cleaned and reprojected \|

        |        └── prism_ppt_30yrnormals_raw.bil

<!--
&#10;    Commit & Tag When Stable
&#10;        Push milestone script changes and metadata updates
&#10;        Use tags like v0.5-prism-dl or milestone-01-initial
&#10;
Next Steps for Milestone 01 – Download and QA Raw Covariate Data
&#10;📏 Best Practices for Working Across Scales:
Step    Action
1.  Ensure CRS alignment: both raster and vector data should be in the same projection (e.g., Albers or UTM, not lat/lon).
2.  Rasterize zones if needed, using nearest-neighbor or majority rule, to match 1 km grid (if aggregating by raster cell).
3.  Buffer or simplify zone boundaries to reflect their 1:250,000-scale fidelity, especially if comparing to higher-res zones.
4.  Use weighted stats when a raster cell overlaps multiple zones (e.g., exactextractr::exact_extract() in R).
5.  Document the mismatch in scale/resolution in metadata: users should know the raster is finer than the zones.
&#10;
&#10;
&#10;    🔲 Validate reproducibility with here(), glue(), and httr::GET() or download.file()
&#10;    🔲 Save logs or hash summaries to /log/ or /data/meta/
&#10;🔹 03. Spatial File QA + Metadata Logging
&#10;        Check CRS, alignment, bounding box, resolution
        &#10;    Validate spatial integrity (extent, projection, cell size, alignment)
&#10;    Create structured metadata and site-level extracted values
    &#10;    🔲 Write an R/01_download/01x_check_spatial_files.R
&#10;        Confirm CRS, resolution, bounding box, projection units
&#10;        Output to data/meta/spatial_covariate_summary.csv
&#10;🔹 04. Document Progress in milestone_01a_download_scripts.Rmd
&#10;    🔲 Add a short narrative and chunk headers for each dataset
&#10;    🔲 Use params$version to link to tag v0.5 (if applicable)
&#10;🔹 05. Version Control & Tagging
&#10;    🔲 Commit regularly: "Download: Add script for PRISM data and raw file log"
&#10;
## Longer-term Considerations
&#10;    We can build a targets pipeline incrementally if you’d like.
&#10;
Review Gage Locations (Filtered by Macrozone)
&#10;1.  Assign each gage to a macrozone using st_join():
&#10;```         
gages_macrozone <- st_join(gages_sf, macrozone_sf["macrozone"])
```
&#10;2.  gages_macrozone \<- st_join(gages_sf, macrozone_sf["macrozone"])
&#10;gages_macrozone %>%
  group_by(macrozone) %>%
  summarize(across(where(is.numeric), list(mean = mean, sd = sd), na.rm = TRUE))
&#10;
You can visualize macrozones as basemap groups
&#10;Or compute zone-wide summaries for supporting tables or EDA
&#10;
🧭 Bottom Line
&#10;You’re right to go with Use Gage Locations (Filtered by Macrozone) — it's more robust, interpretable, and directly connected to your outcome variable (station skew). Random samples are useful for some exploratory summaries, but not essential here.
&#10;## 🌱 When You’re Ready to Grow Again…
&#10;Here are next-step seeds you might plant: 1. Finalize Milestone 01
&#10;Join covariates to each gage (with macrozone as a group)
&#10;2.  Begin Milestone 03 (Targets or Modeling)
&#10;    Start small: just one covariate, one model
&#10;    Or set up a {targets} pipeline to wrap download → clean → model
&#10;3.  Open a Future Milestone Planning Doc
&#10;You've already created notes/future_milestones.Rmd — that’s your strategic launchpad.
&#10;## Tag when complete
git tag -a milestone-01-complete -m "Milestone 01: Covariate acquisition and QA complete"
git push origin milestone-01-complete
&#10;
-->

# Project Structure

``` text
FFA_regional-skew/
├── .gitignore                    # Prevents sensitive/local files from being pushed
├── arcgis_project/               # Stores `.aprx` and layer files from ArcGIS 
                                  #   Pro workflows

├── data/ 
    ├── meta/                     # Metadata
        ├── prism/
        |   └── ppt_30yrnormals/
        |        └── prism_ppt_30yrnormals_raw.bil
        ├── epa/
        |    └── nlcd_2016/
        │       └── epa_nlcd_2016_raw.tif
        └── usgs/
            └── nhdplus/
            |   └── usgs_nhdplus_catchments_v21_raw.shp
            └── waterdata/
                ├── sites_all_in_bb.csv
                └── sites_all_peak_in_bb.csv

    ├── processed/               # Cleaned, derived datasets
        ├── prism/
        |   └── ppt_30yrnormals/
        |        └── prism_ppt_30yrnormals_raw.bil
        ├── epa/
        |    └── nlcd_2016/
        │       └── epa_nlcd_2016_raw.tif
        └── usgs/
            └── nhdplus/
            |   └── usgs_nhdplus_catchments_v21_raw.shp
            └── waterdata/
                ├── sites_all_in_bb.csv
                └── sites_all_peak_in_bb.csv

    ├── raw/                      # Unmodified input data 
        ├── epa/
        |    └── nlcd_2021/
        │       └── epa_nlcd_2021_raw.tif
        |    └── nlcd_2021/
        │       └── epa_nlcd_2021_raw.tif
        └── usgs/
            └── nhdplus/
            |   └── usgs_nhdplus_catchments_v21_raw.shp
        ├── prism/
        |   └── ppt_30yrnormals/
        |        └── prism_ppt_30yrnormals_raw.bil
            └── waterdata/
                ├── sites_all_in_bb.csv
                └── sites_all_peak_in_bb.csv

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

# v0.5 – Download and Prepare Covariates

# v0.5 Tasklist

| Step      | Task                                                    | Status |
|-----------|---------------------------------------------------------|--------|
| **0.5.1** | Refine the Covariate Inventory                          | \[X\]  |
| 0.5.1.5   | Document inputs, outputs, assumptions                   | \[X\]  |
| **0.5.2** | Update folder structure                                 | \[ \]  |
| 0.5.2.1   | Update folder structure for data/                       | \[ \]  |
| 0.5.2.2   | Update folder structure for utilities scripts           | \[ \]  |
| **0.5.3** | Create downloads scripts for vector and point data      | \[ \]  |
| 0.5.3.1   | Create downloads scripts for EPA ecoregions shapefiles  | \[ \]  |
| 0.5.3.2   | Create downloads scripts for NHD+ data                  | \[ \]  |
| 0.5.3.3   | Create downloads scripts for USGS Station data          | \[ \]  |
| **0.5.4** | Create downloads scripts for raster covariates          | \[ \]  |
| 0.5.4.1   | Create downloads scripts for Köppen Geiger climate grid | \[ \]  |
| 0.5.4.2   | Create downloads scripts for USDA Plant Hardiness Zones | \[ \]  |
| 0.5.4.3   | Create downloads scripts for PRISM 30-yr normals (800m) | \[ \]  |
| 0.5.4.4   | Create downloads scripts for NLCD Land Cover 2016       | \[ \]  |
| 0.5.4.5   | Create downloads scripts for NED Slope                  | \[ \]  |
| 0.5.4.6   | Create downloads scripts for MODIS NDVI 2016            | \[ \]  |
| 0.5.4.7   | Create downloads scripts for STATSGO2                   | \[ \]  |
| 0.5.4.8   | Create downloads scripts for NED Elevation              | \[ \]  |
| **0.5.5** | QAQC for downloads                                      | \[ \]  |
| 0.5.5.1   | Validate spatial coverage, resolution, and CRS          | \[ \]  |
| 0.5.5.2   | Standardize and validate metadata for downloads         | \[ \]  |
| 0.5.5.3   | Validate chunk headers in .Rmd files ({r name, eval=} ) | \[ \]  |
| 0.5.5.4   | Make README-style notes for scripts in milestone folder | \[ \]  |
| 0.5.5.5   | Add file size / resolution audit to .Rmd                | \[ \]  |
| 0.5.5.6   | Add ref. links to documentation e.g., PRISM, USGS, NLCD | \[ \]  |
| **0.5.6** | Knit milestone and data dictionary .Rmd files to PDF    | \[ \]  |
| **0.5.7** | Document changes in 01_download README.Rmd              | \[ \]  |
| **0.5.8** | Commit and tag `v0.5-download-scripts`                  | \[ \]  |

### Step 0.5.1 — Refine the Covariate Inventory

**Actions** - Finalized the list of covariates by domain (climate,
terrain, land cover)

- Documented filenames, expected data sources, priority classification,
  versioning, and download status

- Created reusable documentation for source tracking and spatial QA

**Reason (Before):** The covariate inventory lacked a unified, versioned
reference for dataset origin, naming, and QA status. Metadata was
distributed across exploratory scripts without a centralized schema or
checklist for spatial data preparation.

**Result (After):**

- All covariates included in this milestone are now explicitly
  classified as core inputs for regional skew modeling

- Created `docs/covariate_source_inventory.md` to document dataset
  purpose, source, format, resolution, version, and status

- Created `docs/spatial_data_preparation_checklist.md` with a reusable
  12-step QA framework for processing spatial data

- Updated `data/meta/covariates_metadata_schema.csv` to reflect current
  file expectations and schema details

- Standardized covariate metadata for reproducibility, audit tracking,
  and use in subsequent milestones

### Step 0.5.2 — Update folder structure for utils/ and data/

**Actions**

- Backed up the full project prior to restructuring

- Added new data folders:

-  data/intermediate/

-  data/log/

-  data/meta/

-  data/processed/

-  data/raw/

- Created new folders to organize utility scripts by domain

- Updated folder structure under R/utils/ to include:

-  metadata/ – functions for documenting datasets

-  spatial/ – functions for working with shapefiles and rasters

-  qaqc/ – validation and audit helpers

-  paths/ – reusable path constructors

-  plotting/ – clean, project-specific plot functions

**Reason (Before):** All utility functions were either embedded inline
or scattered across script files, making them harder to test, reuse, or
document. There was no consistent structure for distinguishing between
spatial, metadata, or QAQC-related functions.

**Result (After):** Created reusable, well-scoped functions organized by
purpose within R/utils/. This structure improves script readability,
supports test-driven development, and makes it easier to debug or teach
from individual components.

**Code Used to Create Folder Structure**

``` bash

cd "$(git rev-parse --show-toplevel)"   # get to top level from anywhere

mkdir -p R/utils/{metadata,spatial,qaqc,paths,plotting} # make directories
 
```

### Step 0.5.3 — Create downloads scripts for each domain and covariate

**Actions**

**Reason (Before):**

**Result (After):**

# NEXT STEPS

## ├── gp_eco_levels.gpkg

# CREATE CUSTOM MACROREGIONS

# Load Site Locations

sites \<- read_csv(here(“data/clean/sites_pk_gt_20.csv”)) %\>%
distinct(site_no, dec_lat_va, dec_long_va) %\>% drop_na(dec_lat_va,
dec_long_va)

sites_sf \<- sites %\>% st_as_sf(coords = c(“dec_long_va”,
“dec_lat_va”), crs = 4326)

# ——————————————————————————

# Make PRISM metadata

# accessed from <https://prism.oregonstate.edu/fetchData.php>

# and fed into ChatGPT

prism_metadata \<- tribble( ~variable, ~time_period, ~resolution,
~units, ~description, ~source,

“Precipitation”, “1991-2020 Annual”, “4km”, “Millimeters”, “Average
annual total precipitation derived from monthly grids.”,
“<https://prism.oregonstate.edu/normals/>”,

“Precipitation”, “1991-2020 Monthly”, “4km”, “Millimeters”, “Monthly
total precipitation normals.”,
“<https://prism.oregonstate.edu/normals/>”,

“Temperature (Mean)”, “1991-2020 Annual”, “4km”, “Degrees C”, “Average
annual mean temperature derived from monthly grids.”,
“<https://prism.oregonstate.edu/normals/>”,

“Temperature (Mean)”, “1991-2020 Monthly”, “4km”, “Degrees C”, “Monthly
mean temperature normals.”, “<https://prism.oregonstate.edu/normals/>” )

prism_metadata_spatial \<- tribble( ~attribute, ~value,

“Variable”, “Precipitation & Temperature”, “Time Period”, “1991-2020
Normals”, “Resolution”, “4km (~0.04166667 degrees)”, “Projection”,
“Geographic Coordinate System (Lat/Long)”, “Datum”, “North American
Datum 1983 (NAD83)”, “Ellipsoid”, “Geodetic Reference System 80
(GRS80)”, “Cell Size”, “0.04166667 degrees”, “Extent West”,
“-125.0208333”, “Extent East”, “-66.4791667”, “Extent North”, “49.9375”,
“Extent South”, “24.0625”, “Units Precipitation”, “Millimeters”, “Units
Temperature”, “Degrees Celsius”, “Source”,
“<https://prism.oregonstate.edu/normals/>”, “Method”, “PRISM model -
Parameter-elevation Regressions on Independent Slopes Model (Daly et
al. 2008, 2015)” )

- Updated hardcoded paths in scripts where possible
- Completed Ecoreg dkl –\> Projected to Albers, NAD83

### Step 0.5.4 — Standardize and validate metadata for downloads

**Actions**

**Reason (Before):**

**Result (After):**

### Step 0.5.5 — Create README-style notes for scripts in milestone folder

**Actions**

**Reason (Before):**

**Result (After):**

### Step 0.5.6 — Add reference links to documentation e.g., PRISM, USGS, NLCD

**Actions**

**Reason (Before):**

**Result (After):**

### Step 0.5.7 — Knit milestone and data dictionary .Rmd files to PDF

**Actions**

**Reason (Before):**

**Result (After):**

### Step 0.5.8 — Document changes in 01_download README.Rmd

**Actions**

**Reason (Before):**

**Result (After):**

### Step 0.5.9 — Commit and tag `v0.5-download-scripts`

**Actions**

git tag -a v0.5-download-scripts -m “Milestone 01: Download scripts and
covariate metadata”

git push origin v0.5-download-scripts

**Reason (Before):**

**Result (After):**
