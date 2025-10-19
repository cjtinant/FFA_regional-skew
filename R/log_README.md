R Script Folder Log
================

# 📁 `R/` — Script Log

This log tracks major changes, additions, and decisions related to R
scripts in the project. It supplements the global `CHANGELOG.md` by
providing folder-level context for code evolution, script structure, and
workflow logic.

All entries are reverse chronological. Please include the date, your
initials, and a brief summary.

------------------------------------------------------------------------

## 📌 Log Entries

### 2025-08-06 — C.J.T.

`03c_make_macrozone_layer.R` — Aggregate Ecoregions and Generalize
Macrozones

- Aggregates Level IV (L4) Ecoregions into macrozones after combining
  polygons (slivers) of less than 100 sq-km with nearest neighbors.

- Generalizes initial macrozone polygons by combining polygons of less
  than 1,000 sq-km with nearest neighbors.

- - Exported results as:
  - `output/figs/macrozones_map.png`
  - `data/processed/us_ecoregions/macrozones_gp.gpkg`

### 2025-08-05 — C.J.T.

`03b_make_macrozone_lut.R` — Macrozone Look-up Table Creation

- Makes look-up tables to delineate Level IV Ecoregions (L4) into
  Tallgrass, Mixed-Grass, and Shortgrass Prairie macrozones.
  - The tables also contain fields for: estimated_koppen, vege_lnd_use,
    hydrology, terrain, and eco_level.
- - Exported look-up tables as:
  - `docs/metadata/look_up_tables/ecoregion_l3_metadata_lut.csv`
  - `docs/metadata/look_up_tables/ecoregion_l4_metadata_lut.csv`

### 2025-07-29 — C.J.T.

`03a_update_covariate_metadata.R` — Covariate Metadata Cleanup and
Linkage

- Cleaned and standardized covariate metadata for modeling station skew
  values.
- Converted ordinal fields to categorical:
  - `domain_ordinal` -\> `domain_cat`
  - `concept_group_ordinal` -\> `concept_group_cat`
- Updated effective_analytical_resolution and description fields to:
  - Distinguish `NHDPlus v2.1 vs NHDPlusHD`
  - Clarify use of catchments vs flowlines
  - Differentiate NED elevation vs NED slope
- Normalized dataset names using `dataset_normalization_lut` to enforce
  one-to-one joins.
- Joined covariate metadata to:
  - Processed file locations (`data_locs_med_rare`)
  - Zonal summary layers (`zonal_lut`)
- Verified join integrity; resolved many-to-many conflicts.
- Exported cleaned metadata as:
  - `docs/metadata/descriptions/covariate_metadata_v085.csv`
- Archived previous version:
  - `docs/metadata/descriptions/archive/covariate_metadata_v084.csv`

### 2025-07-29 — C.J.T.

- Linked to Milestone 2.3: Improve code documentation and metadata
- Standardized header blocks in all `R/01_download/` scripts
- Updated README.Rmd and knitted to README.md
- Standardized use of `.Rmd` and `.md` across all subfolders
- Added `log_README.Rmd` to document folder-level decisions
- Updated script headers in `R/01_download/` and `R/02_clean_validate/`
  to include milestone cross-references

### 2025-07-22 — C.J.T.

- Improved metadata blocks and dependencies across key scripts in
  `R/01_download/`
- Verified file paths and output locations for reproducibility
- Added `README.Rmd` and knitted to `README.md` for GitHub rendering

------------------------------------------------------------------------

## 🧩 Conventions

- Use `{here}` for all paths.
- Follow naming: `01a_task-name.R`, `02b_task-name.R`, etc.
- Scripts should run independently when possible.
