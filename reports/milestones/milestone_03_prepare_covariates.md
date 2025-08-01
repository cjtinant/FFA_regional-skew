Milestone 03 — Prepare Covariates and Modeling Dataset
================

# 🎯 Milestone 03 — Prepare Covariates and Modeling Dataset

**Goal:** Clean, join, and document covariate data for modeling station
skew values. Ensure all numeric predictors are harmonized, standardized,
and traceable.

------------------------------------------------------------------------

## ✅ Objectives

1.  Clean and update covariate metadata

<!--
x. Organize covariate files from climate, terrain, and land cover sources.
&#10;2. Standardize variable names and units for modeling compatibility.
3. Join covariates to site locations (`site_no`, `latitude`, `longitude`).
4. Handle missing values with clear rules and documentation.
5. Create modeling-ready dataset in `data/derived/`.
6. Document updated data dictionary and metadata.
7. Begin exploratory modeling prep (e.g., correlation, distributions, scaling).
-->

------------------------------------------------------------------------

# Project Structure

<!--
Relevant folders and files
-->

``` text
FFA_regional-skew/
  ├── .gitignore               # Prevents sensitive/local files from being pushed
  ├── .lintr.R                 # Configures `lintr` to check for style adherence
  ├── .Rprofile                # Configures project-level settings (renv)
  ├── arcgis_project/          # ArcGIS Pro .aprx project and supporting layers
  ├── CHANGELOG.md             # GitHub-readable changelog from .Rmd
  ├── CHANGELOG.Rmd            # Human-readable changelog (semantic versioning)
  ├── data/                    # Raw, processed, meta, intermediate, and QA data
  ├── DESCRIPTION.txt          # Central repository for project metadata
  ├── docs/                    # Documentation, workflow notes, metadata, checklists
  ├── FFA_regional-skew.Rproj  # RStudio project file (keep in root)
  ├── notebooks/               # Ad hoc .Rmd/.qmd experiments (empty or minimal)
  ├── notes/                   # Team notes, meeting logs, brainstorms
  ├── output/                  # Preliminary results and products from R scripts
  ├── R/                       # Analysis scripts (milestone-organized)
  ├── README_files             # Figures and other files called from README.Rmd
  ├── README.md                # GitHub-readable overview and navigation aid
  ├── README.Rmd               # RMarkdown version of overview and navigation aid
  ├── RELEASE_CHECKLIST.Rmd    # ** not currently being used**
  ├── renv                     # Reproducible package environment (see renv.lock)
  ├── renv.lock                # Records package dependency state at a point in time.
  ├── reports/                 # Knitted .Rmd/.qmd milestone reports
  ├── results/                 # Manuscript-ready figures, models, and outputs
  ├── sandbox/                 # Staging area for files to review
```

## 📁 Expected Outputs

- `docs/metadata/descriptions/covariate_metadata_v085.csv`
- `docs/metadata/descriptions/covariate_metadata_v084.csv` *(archived)*
- `data/meta/data_dictionary_covariates.csv` *(upcoming)*
- `data/derived/skew_modeling_dataset.csv` *(pending)*
- Updated logs in:
  - `docs/metadata/log_README.Rmd` *(upcoming)*
  - `R/log_README.Rmd` *(upcoming)*

<!--
- `data/derived/skew_modeling_dataset.csv`
- `data/meta/data_dictionary.csv` (updated with covariates)
- `data/meta/README_covariates.md`
- Updated logs in:
  - `data/processed/log_README.Rmd`
  - `R/log_README.Rmd`
-->

------------------------------------------------------------------------

## 🔧 Key Scripts

- `R/03a_update_covariate_metadata.R`

<!--
- `03X_join_covariates.R`
- `03b_clean_covariates.R`
- `03c_check_missing_covariates.R`
- `03d_create_modeling_dataset.R`
-->

------------------------------------------------------------------------

## 🧠 Notes

- Use modeling-friendly standardized names (e.g., `ppt_ann_mm`,
  `tmean_jan_C`, `slope_pct`).
- Move `site_no`, `latitude`, `longitude` fields to the front of the
  dataset.
- Track variables dropped due to collinearity or missingness.
- Log all transformation and filtering rules in script headers and
  `log_README.Rmd`.

------------------------------------------------------------------------

## 🔖 Target Version(s)

- Version: **v1.6.0–v1.6.x** for primary milestone tasks
- Follow-up work may extend into **v1.7.x** (exploratory modeling setup)

------------------------------------------------------------------------

## 📝 Task Checklist

| Step | Task                      | Status |
|:----:|:--------------------------|:------:|
| 3.1  | Update covariate metadata | \[X\]  |
| 3.2  | Create macrozone layer    | \[ \]  |

<!--
- [ ] Clean and stack covariate rasters
- [ ] Join raster data to site coordinates
- [ ] Standardize column names and units
- [ ] Remove unnecessary or problematic variables
- [ ] Save modeling-ready `.csv` to `data/derived/`
- [ ] Update data dictionary and README files
- [ ] Write log entries in `log_README.Rmd`
- [ ] Tag release `v1.6.x`
-->

## Description of Tasks Completed or In Progress

### Milestone 3.1 Summary:

- Implemented 03a_update_covariate_metadata.R to standardize and
  document covariate metadata.

- Converted domain and concept group variables from ordinal to
  categorical form for modeling readability.

- Clarified dataset descriptions, distinguishing NHDPlusHD vs. NHDPlus
  v2.1 and catchments vs. flowlines.

- Used a lookup table to normalize dataset names and enforce one-to-one
  relationships between variables and files.

- Linked all covariates to corresponding processed files and zonal
  summary layers.

- Archived previous metadata version (v084) and exported the updated
  covariate_metadata_v085.csv.

- Ensure this update is reflected in `CHANGELOG.md` and `log_README.Rmd`

# Summary

<!--
Retrospective record of key results and an opportunity to reflect on what was
accomplished.
-->

------------------------------------------------------------------------

## 🔁 Summary

Milestone 03.1 established a clean, traceable foundation for covariate
integration by formalizing metadata, resolving many-to-many joins, and
linking each variable to a single, authoritative data source. With the
metadata structure finalized, the next steps will focus on joining
raster data to site locations and preparing a modeling-ready dataset
with standardized variable names, units, and formats.

### Reproducibility Notes

- See DESCRIPTION and renv.lock for project-wide dependencies and
  package versions.
