Milestone 01 — Download and Prepare Covariates
================
C.J. Tinant
May 11, 2025

- [Overview of v0.5](#overview-of-v05)
- [Notes](#notes)
- [Project Structure](#project-structure)
- [v0.5 – Download and Prepare
  Covariates](#v05--download-and-prepare-covariates)
- [v0.5 Tasklist](#v05-tasklist)

## Overview of v0.5

This document describes the structure and metadata setup completed for
**Milestone v0.5**.

### Summary

Initiate acquisition, validation, and preparation of climate, terrain,
and location-based covariates for use in regional skew estimation
models.

See
[`spatial_data_preparation_checklist.md`](../docs/spatial_data_preparation_checklist.md)
for a reusable checklist used to guide and document preprocessing steps
across spatial layers.

### Goals

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

### Naming convention:

- Subdirectory naming follows as shown in **Project Structure**. Example
  folder names:

  - /data_raster_raw/epa_landcover_2016/

  - /data_raster_raw/usgs_nhdplusv2/

  - /data_raw/prism_ppt_normals/

  - Script naming follows: `milestone + domain + covariate + source`

- Data naming follows:
  \[source\]*\[layer\]*\[year\|version\]\_\[status\].\[ext\]. Example
  filenames:

  - prism_ppt_30yrnormals_raw.bil

  - usgs_nhdplus_catchments_v21_raw.shp

  - epa_nlcd_2021_raw.tif

  - census_county_boundaries_2020_raw.gpkg

See: `R/00_setup/` and `data/raw/` for implementation scripts and
acquired data

<!--
&#10;    Commit & Tag When Stable
&#10;        Push milestone script changes and metadata updates
&#10;        Use tags like v0.5-prism-dl or milestone-01-initial
&#10;## Tag when complete
git tag -a milestone-01-complete -m "Milestone 01: Covariate acquisition and QA complete"
git push origin milestone-01-complete
&#10;Next Steps for Milestone 01 – Download and QA Raw Covariate Data
&#10;🔹 02. Write or Refactor Download Scripts
&#10;.... Look through 01_get_spatial...R
&#10;    Begin modular scripts for each covariate domain.
&#10;    Optional: log intermediate outputs in data/meta/.
&#10;    🔲 Break scripts into modular chunks by source:
&#10;        01a_get_prism.R
&#10;        01b_get_nlcd.R
&#10;        01c_get_ned_elev.R
&#10;        01d_get_stream_networks.R, etc.
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
&#10;-->

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
        ├── prism/
        |   └── ppt_30yrnormals/
        |        └── prism_ppt_30yrnormals_raw.bil
        ├── epa/
        |    └── nlcd_2021/
        │       └── epa_nlcd_2021_raw.tif
        └── usgs/
            └── nhdplus/
            |   └── usgs_nhdplus_catchments_v21_raw.shp
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

| Step    | Task                                                      | Status |
|---------|-----------------------------------------------------------|--------|
| 0.5.1   | Refine the Covariate Inventory                            | \[ \]  |
| 0.5.1.5 | Document inputs, outputs, assumptions                     | \[ \]  |
| 0.5.2   | Update folder structure for data/                         | \[ \]  |
| 0.5.3   | Create downloads scripts for each domain and covariate    | \[ \]  |
| 0.5.3.5 | Validate chunk headers in .Rmd files ({r name, eval=} )   | \[ \]  |
| 0.5.4   | Standardize and validate metadata for downloads           | \[ \]  |
| 0.5.4.5 | Validate spatial coverage and CRS for covariates          | \[ \]  |
| 0.5.5   | Create README-style notes for scripts in milestone folder | \[ \]  |
| 0.5.5.5 | Add file size / resolution audit to .Rmd                  | \[ \]  |
| 0.5.6   | Add ref. links to documentation e.g., PRISM, USGS, NLCD   | \[ \]  |
| 0.5.7   | Knit milestone and data dictionary .Rmd files to PDF      | \[ \]  |
| 0.5.8   | Document changes in 01_download README.Rmd                | \[ \]  |
| 0.5.9   | Commit and tag `v0.5-download-scripts`                    | \[ \]  |

### Step 0.5.1 — Refine the Covariate Inventory

**Actions**

- Final list of covariates by domain (climate, terrain, land cover)

- Document Filenames, expected sources, priority, and version tracking

**Reason (Before):**

**Result (After):**

1.  Added docs/spatial_data_preparation_checklist.md.

2.  Updated: `data/meta/covariates_metadata_schema.csv`

3.  All covariates included in this phase are considered core inputs for
    regional skew modeling. These variables—derived from climate,
    terrain, and location data—were selected based on prior studies,
    ecological relevance, and data availability. No optional or
    exploratory variables have been included in this milestone.

4.  Created: `docs/spatial_data_preparation_checklist.md`

5.  Created: `docs/covariate_source_inventory.md`

### Step 0.5.2 — Update folder structure for data/

**Actions**

- Consider backing up entire project before file moves

- Update any hardcoded paths in scripts

**Reason (Before):**

**Result (After):**

### Step 0.5.3 — Create downloads scripts for each domain and covariate

**Actions**

**Reason (Before):**

**Result (After):**

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

**Reason (Before):**

**Result (After):**
