Changelog
================
CJ Tinant
2025-08-06

- [Changelog](#changelog)
  - [\[Untracked\]](#untracked)
  - [\[v1.6.1\] — 2025-08-06](#v161--2025-08-06)
  - [\[v1.6.0\] — 2025-08-01](#v160--2025-08-01)
  - [\[v1.5.3\] — 2025-07-29](#v153--2025-07-29)
  - [\[v1.5.2\] — 2025-07-29](#v152--2025-07-29)
  - [\[v1.5.1\] — 2025-07-29](#v151--2025-07-29)
  - [\[v1.5.0\] — 2025-07-28](#v150--2025-07-28)
  - [\[v1.4.8\] — 2025-07-22](#v148--2025-07-22)
  - [\[v1.4.0\] - 2025-07-22](#v140---2025-07-22)
  - [\[v1.3.0\] - 2025-06-30](#v130---2025-06-30)
  - [\[v1.2.5\] - 2025-05-08](#v125---2025-05-08)
  - [\[v1.2.0\] - 2025-05-08](#v120---2025-05-08)

# Changelog

This changelog tracks notable updates to the Regional Skew Estimation
project.

*This project strives to follow [Semantic
Versioning](https://semver.org) and the [Keep a
Changelog](https://keepachangelog.com/) format.*

------------------------------------------------------------------------

## \[Untracked\]

### In Progress

## \[v1.6.1\] — 2025-08-06

### Added

- `03b_make_macrozone_lut.R` to create
  `docs/metadata/look_up_tables/ecoregion_l3_metadata_lut.csv` and
  `docs/metadata/look_up_tables/ecoregion_l4_metadata_lut.csv`. The
  look-up tables are used to delineate Level IV Ecoregions (L4) into
  Tallgrass, Mixed-Grass, and Shortgrass Prairie macrozones. The tables
  also contain fields for: estimated_koppen, vege_lnd_use, hydrology,
  terrain, and eco_level.
- Implemented `03c_make_macrozone_layer.R` and the look-up tables above
  to
  - create initial macrozones after merging small polygons of less than
    100 sq-km with a nearest neighbor.
  - Generalize macrozones by merging polygons of less than 1,000 sq-km
    with a nearest neighbor.
- `docs/style_guide.md` — Naming and Terminology Reference
  - Created project-wide style guide for terminology, naming, and
    formatting
  - Standardized macrozone names:
    - Tallgrass Prairie (no hyphen)
    - Mixed-Grass Prairie (hyphenated)
    - Shortgrass-Steppe (hyphenated; omit “Prairie”)
  - Added conventions for:
    - snake_case variable naming
    - units in variable suffixes (e.g., \_mm, \_pct, \_C)
    - column order for modeling datasets
    - usage of acronyms and modifiers
  - Linked to README.md and relevant metadata documentation

## \[v1.6.0\] — 2025-08-01

### Added

- `milestone_03_prepare_covariates.Rmd` in `reports/milestones/`
- `data/covariates/` folder for joined covariates
- Added Reproducibility Notes sections to
  `milestone_02_documentation.pdf` and
  `milestone_03_prepare_covariates.pdf`
- `Script 03a_update_covariate_metadata.R` to clean, normalize, and
  document covariate metadata used for modeling station skew.
  - Lookup table (`dataset_normalization_lut`) ensures one-to-one joins
    between covariates and data sources.

### Changed

- Moved legacy `03_covariate` scripts to `sandbox`
- Updated `milestone_03_prepare_covariates.Rmd` Project Structure
  - Converted `domain_ordinal` -\> `domain_cat` and
    `concept_group_ordinal` -\> `concept_group_cat` to improve
    categorical clarity.
  - Updated metadata fields to clarify distinctions between:
    - NHDPlus v2.1 vs. NHDPlusHD
    - Catchments vs. Flowlines
    - NED slope vs. NED elevation
  - Normalized dataset names and descriptions for consistency and
    traceability.
  - Joined covariate metadata with:
    - Processed dataset locations (`data_locs_med_rare`)
    - Zonal summary spatial layers (`zonal_lut`)

### Removed

- Many-to-many relationships between covariate variables and dataset
  sources through normalization.

### Archived

- Moved `covariate_metadata_v084.csv` to
  `docs/metadata/descriptions/archive/`
- Exported updated metadata as `covariate_metadata_v085.csv`

## \[v1.5.3\] — 2025-07-29

### Changed

- Linked folder-level `README.Rmd` and `log_README.Rmd` files to project
  milestones for improved documentation traceability.
- Added milestone references to `R/log_README.Rmd` based on recent
  updates (Milestone 2.3).

### Completed Milestones

- **Milestone 2.8**: Standardize use of `.Rmd` and `.md` for all folders
- **Milestone 2.9**: Develop `log_README.md` templates in `R/` and
  `data/`

**This closes Milestone 2**

## \[v1.5.2\] — 2025-07-29

### Added

- `log_README.Rmd` to `R/` for tracking script-level changes and
  workflow decisions.
- `log_README.Rmd` to `data/processed/` for documenting processed
  dataset origins, transformations, and spatial coverage.
- Initial log entries based on recent work in Milestones 2.2 and 2.3.
- Folder-level conventions and documentation practices to improve
  transparency and reproducibility.

### Changed

- Standardized documentation workflow by ensuring consistent use of
  `.Rmd` and `.md` files across all major project folders.
  - Added or updated `README.Rmd` files to document workflows in `R/`,
    `data/`, `notes/`, and `reports/`.
  - Knitted corresponding `README.md` files for GitHub-friendly
    rendering.
  - Removed outdated `.md` files that were not backed by `.Rmd` sources.
  - Verified reproducibility and knit-cleanliness of all `.Rmd` files.

### Completed Milestones

- **Milestone 2.5**: Review `docs/metadata` covariates
- **Milestone 2.6**: Standardize use of `.Rmd` and `.md` for all folders
- **Milestone 2.7**: Develop `log_README.md` templates in `R/` and
  `data/`

## \[v1.5.1\] — 2025-07-29

### Added

- Created `DESCRIPTION` file to document base project dependencies.
- Initialized `renv` and snapshot to create `renv.lock` for reproducible
  package versions.
- Cleaned syntax issues in `01g_download_nhdplus_hr_catchments.R` and
  `02a_merge_nhdplus_hr_flowlines.R` flagged by `renv::init()`.
- Updated all active packages in `renv.lock` via `renv::snapshot()`.

### Changed

- Updated script headers in affected `.R` files to remove trailing
  commas and clarify `file.path()` usage.
- Updated Milestone 02 documentation to include reproducibility tools.
- Updated scripts to use here() for all file paths, applied tidyverse
  style with {styler}, minimized hard-coded paths.

### Completed Milestones

- **Milestone 2.3**: Ensure all scripts are self-contained
- **Milestone 2.4**: Review document dependencies

## \[v1.5.0\] — 2025-07-28

### Added

- README.pdf and README.md in `notes/`
- README.pdf and README.md in `reports/`
- README.pdf and README.md in `R/01_download/`
- README.pdf and README.md in `R/02_clean_validate/`

### Changed

- Standardized script headers in `R/01_download/`, `R/02_clean_verify/`,
  and `R/utils/`
- Integrated `notes/future_milestones.md` into
  `notes/script-notes_and_developer-log.md`
- Emptied `sandbox/` and migrated remaining files to `notes/to_process/`
- Reorganized `reports/`:
  - Moved pilot project files to `reports/20250415_pilot/`
  - Moved milestone reports to `reports/milestones/`
- Reorganized `results/` by moving pilot outputs to
  `results/20250415_pilot/`

### Completed Milestones

- **Milestone 2.1**: Improve script and metadata documentation for
  spatial downloads
- **Milestone 2.2**: Document QA of tabular and raster input files

------------------------------------------------------------------------

## \[v1.4.8\] — 2025-07-22

### Added

- README.Rmd for R/01_download/ to document spatial data download
  scripts and workflows.
- Workflow summaries and output descriptions to all major download
  scripts.
- Manually added milestone cross-references to script headers in
  R/01_download/

### Changed

- Standardized headers, metadata blocks, and dependencies in:
  - 01g_download_nhdplus_hr.R
  - 01h_download_koppen-geiger_climate.R
  - 01k_download_prism_climate.R
- Improved clarity and reproducibility of output file paths and export
  logic.
- Minor cleanup and consistency improvements across R/01_download.

## \[v1.4.0\] - 2025-07-22

### Added

- Created git_changelog_workflow_reference.Rmd to document versioning
  and commit practices
- Drafted structured README content for `docs/` folder organization and
  contents
- Converted spatial_data_preparation_checklist.md to RMarkdown with
  interactive checkboxes
- Added YAML header with github_document output and floating TOC for
  checklist rendering
- Added 01c_download_usgs_site_metadata.R to query and export detailed
  metadata for USGS peak flow gages filtered within the Great Plains
  Level I Ecoregion
- Added 01e_filter_peakflow_data.R script to apply staged filtering of
  peak flow data, including:
  - Filtered USGS peak flow data for usable records (≥10 years)
  - Applied MGBT to flag and remove PILFs
  - Tiered sites into 3 categories based on regulation and record length
  - Calculated LP3-compatible sample skewness per Bulletin 17C
  - Cleaned and joined gage attributes; removed unused/constant fields
  - Exported results to GeoPackage (gage_summary_skew.gpkg), CSV, and
    metadata dictionary
- Added/renamed docs/review_data_files to inventory downloads in
  data/raw/ and compare with data/processed/ to flag missing processing
  steps and unused files
- Combined and validated NHDPlus HR catchments with chunked geometry
  repair
- Recreated and enhanced 01h_download_nhdplus_hr_flowlines.R to download
  and QA NHDPlus HR flowlines for Great Plains L4 Ecoregions:
  - Restored functionality from deleted prior version
  - Standardized output file names via region_name_to_filename()
  - Switched output path to data/raw/nhdphr_flowlines/ for
    reproducibility
  - Added CLI status updates via {cli}
  - Logged retry attempts with buffer distance in nhdphr_retry_log.csv
  - Generated diagnostics for NULL AOIs with sliver flag logic and QA
    map
  - Exported null_aoi_summary.csv and
    null_aois_diagnostics_facet_map.png for review
- Added script 02g_extract_summary_metadata_raster.R
  - Extracts raster-level summary metadata (CRS, extent, resolution,
    dimensions, band names)
  - Captures band-level data types for all layers
  - Outputs written to:
  - koppen-geiger_summary_metadata_v01.csv
  - koppen-geiger_band_metadata_v01.csv
  - Stored in docs/metadata/raster-data-summaries/

### Changed

- Metadata Restructure and Cleanup (v0.3.0)
  - Reorganized metadata files into subdirectories:
    - dictionaries/
    - descriptions/
    - look-up-tables/
    - raster-data-summaries
  - Cleaned and renamed README.Rmd and README.md for docs/metadata/
  - Removed redundant files (e.g., .csv.csv extensions)
  - Added support tools:
  - metadata_manual_cleaning_tools.R
  - split-xlsx-into-csv.R
- Updated changelogs and improved file naming consistency
- Changed 01b_download-gage-data.R outputs: Removed tile_id, queryTime,
  ecoregion level, and unused fields from final CSVs
- Updated docs/README.md to include spatial checklist as a key reference
- Started reviewing and inventorying reports/ folder for milestone logs
  and modeling notes
- Grouped finalized .Rmd logs and narrative summaries by milestone in
  `reports/`
- Moved zipped files to data/raw/archives/
- Updated `inventory_feature_data.R output` to permanently log results
  to `data/log`
- Moved possible duplicate flowlines files from `/data/raw/` to data to
  `to_check/nhdphd_flowlines_dups/`
- Moved `data/intermediate` to `to_check/`
- Moved human-readable metadata to docs/metadata/
- Completed audit for duplicate or outdated files in:
  - `/docs`
- Migrated internal process documentation and QA/QC templates into
  `docs/`
- Integrate finalized workflow references into
  `docs/best-practices_reference`
- Audit for duplicate or outdated files across documentation folders:
  - data/
  - docs/
- Tag report .Rmd files with chunk header cleanup ({r name, eval=}) for
  reproducibility

## \[v1.3.0\] - 2025-06-30

### Added

- Created modular download scripts under `R/01_download/`:
  - `01a_download_ecoregions.R`
  - `01b_download_gage-data.R`
  - `01c`–`01e` for NHDPlus v2 and HR flowlines and catchments
  - `01f`–`01g` for Köppen-Geiger and Plant Hardiness Zones
  - `01h`–`01m` for raster datasets: PRISM, NLCD 2016, NED, MODIS NDVI,
    STATSGO2
- Standardized naming conventions and folder structure for `data/raw/`,
  `data/processed/`, and `data/intermediate/`
- Created MODIS HDF tile overlay grids for spatial clipping and download
  coordination

### Changed

- Renamed and refactored download scripts into alphabetical modular
  format
- Reorganized folder hierarchy for clarity and reproducibility
- Updated milestone tracker to reflect completion status for vector
  (0.5.3) and raster (0.5.4) download tasks

### Fixed

- Resolved `st_layers()` and `st_read()` issues with geopackage inputs
  (e.g., ecoregions)
- Corrected CRS and clipping mismatches for MODIS NDVI and NED elevation
  inputs

## \[v1.2.5\] - 2025-05-08

### Added

- PRISM metadata extraction for spatial extent and resolution
- Standardized variable names for climate covariates
- Section on covariate metadata in `README.Rmd`

### Changed

- Reorganized milestone folder structure
- Renumbered Milestone 13 → Milestone 12c for consistency

### Fixed

- Silenced UTF-8 encoding warnings in `.Rmd` rendering

------------------------------------------------------------------------

## \[v1.2.0\] - 2025-05-08

### Added

- Cleaned PRISM climate normals and extracted values to site locations
- Created `regional_skew_covariates_metadata_by_scale_v01.csv`
- LaTeX export of covariate metadata tables with `kableExtra`

### Changed

- Reprojected all site and covariate data to NAD83
- Improved visual maps with consistent basemap and coordinate systems

### Fixed

- Alignment issue in elevation raster extraction
