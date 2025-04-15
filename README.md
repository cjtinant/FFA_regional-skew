Regional Skew Estimation Project
================

- [Overview](#overview)
- [Planned Next Steps](#planned-next-steps)
- [Project Structure](#project-structure)
- [Workflow Overview](#workflow-overview)
- [Modeling Approach and Rationale](#modeling-approach-and-rationale)
- [Data Notes](#data-notes)
- [Reproducibility Notes](#reproducibility-notes)
- [Note on Outlier Removal: Slope Outlier
  Site](#note-on-outlier-removal-slope-outlier-site)
- [Coordinate Reference Systems
  (CRS)](#coordinate-reference-systems-crs)
- [Dependencies](#dependencies)
- [Citations](#citations)

## Overview

This project develops a reproducible, data-driven workflow to support
regional skew estimation for flood frequency analysis (FFA) at USGS
stream gage sites across the Great Plains ecoregion.

The workflow uses R and {tidyverse} tools to automate the download,
cleaning, joining, and modeling of covariate data associated with gage
locations. Covariates include climate normals, terrain characteristics,
and site location variables. Current Objective

The primary goal of this phase is to explain spatial variation in
station skew — the log-Pearson Type III skew coefficient estimated at
individual stream gages — using a set of numeric covariates derived
from:

- Climate normals (precipitation and temperature)

- Terrain data (elevation and slope)

- Site location (latitude and longitude)

## Planned Next Steps

Future work will expand the covariate dataset to include:

- Watershed characteristics (e.g., drainage area)

- Categorical variables derived from:

  - Ecoregion membership (Levels I–IV)

  - Landscape descriptors (e.g., glaciation history, soil texture)

Subsequent analysis will explore classification approaches to group
sites into hydrologically similar regions, ultimately supporting the
development of regional skew coefficients for improved FFA applications.

------------------------------------------------------------------------

## Project Structure

    FFA_regional-skew/
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

## Workflow Overview

| Milestone | Script(s) | Purpose |
|---:|:---|:---|
| 01 | `01_get-spatial-data.R` | Download and clean HUCs, ecoregions, and gage shapefiles |
| 02 | `02_get-gage-data.R` | Download USGS annual peak flows |
| 03 | `03_filter_unregulated_gage_data.R` | Filter to unregulated sites with ≥20 years |
| 04 | `04_find_clean_export_site_summaries.R` | Query and export NWIS/WQP metadata |
| 05 | `05_update_problem_sites.R` | Remove sites with unusable peak data |
| 06 | `06_calculate_station_skew.R` | Compute log-Pearson III station skew |
| 07 | `07_download_climate_covariates.R` | Download PRISM climate normals (monthly + annual) |
| 08 | `08_download_terrain_covariates.R` | Extract elevation and slope from NED raster |
| 09 | `09_join_covariates_for_modeling.R` | Join all covariates and remove outlier site |
| 10a | `10a_exploratory_modeling_initial_checks.R` | Clean for modeling (drop NA/duplicates) |
| 10b | `10b_exploratory_modeling_correlation_reduction.R` | Heatmap of numeric covariate relationships |
| 10c | `10c_exploratory_modeling_models.R` | Fit exploratory MLR and GAMs |
| 10d | `10d_exploratory_modeling_variable-prep.R` | Calculate seasonal covariates and subset variables |
| 11a | `11a_fit_lm_models.R` | Fit and tune Elastic Net model (MLR) |
| 11b | `111b_fit_gam_models.R` | Fit and tune GAM model |

------------------------------------------------------------------------

### Highlights from Exploratory Modeling

- **No single covariate** explains station skew on its own.
- **Annual temperature and spring/winter precipitation** show strong
  non-linear effects (from GAMs).
- **Latitude** consistently adds explanatory power; elevation and slope
  are weaker.
- Pairwise correlations showed **collinearity among monthly climate
  variables**.
- Seasonal summaries (spring, winter, etc.) reduce dimensionality while
  preserving signal.

------------------------------------------------------------------------

### Model Tuning Summary (Elastic Net)

- **Best RMSE (10-fold CV):** ~0.615  
- **Best configuration:** ridge-like (mixture = 0), with small penalty  
- **Tuning method:** `tune_grid()` over regular grid of 5 × 5 (penalty,
  mixture)

Results exported to:

- `results/model_summaries/` (summary CSVs)
- `results/figures/` (pair plots, correlation heatmaps)

------------------------------------------------------------------------

## Modeling Approach and Rationale

### Generalized Additive Models (GAM)

Initial modeling explored relationships between station skew and
climate, terrain, and location-based covariates using Generalized
Additive Models (GAM) implemented with `{mgcv}`.

The GAM framework was selected to allow for flexible, non-linear
relationships between covariates and station skew — a reasonable
expectation given hydrologic processes in the Great Plains.

#### Model Refinement Workflow

1.  **Simple Model:** Location & Terrain only (`dec_long_va`, `elev_m`,
    `slope_deg`)
2.  **Full Climate Model:** Added seasonal precipitation and January
    mean temperature
3.  **Stepwise Refinement:**
    - Removed `ppt_summer_mm` (non-significant, minimal contribution)
    - Removed `elev_m` (non-significant after accounting for other
      terms)

#### Final Refined Model Terms

| Covariate | Rationale |
|----|----|
| dec_long_va | Captures spatial trend east-west |
| slope_deg | Weak but retained for terrain influence |
| ppt_spring_mm | Important in driving peak flow magnitude |
| ppt_winter_mm | Significant influence, possibly related to snow accumulation/melt |
| tmean_m01_c | January mean temperature as indicator of winter severity |

#### Model Evaluation

- Model selection guided by AIC reduction and parsimony.
- Visual diagnostics (smooth terms) confirmed non-linear relationships.
- Deviance explained: ~15%  
- Adj. R²: ~12-13%  
- Residual diagnostics were reasonable, with minor structure remaining.

------------------------------------------------------------------------

### Next Steps

- Compare performance with Elastic Net regression.
- Use `last_fit()` for test-set evaluation
- Evaluate residual spatial autocorrelation
- Cross-validate final model(s) to assess predictive performance.
- Explore prediction surfaces for regional skew estimation.
- Create clean summaries and plots of best models
- Document findings

------------------------------------------------------------------------

## Data Notes

### PRISM Climate Normals

- Source: <https://prism.oregonstate.edu/normals/>
- Resolution: 4km gridded .bil rasters
- Time period: 1991-2020
- Variables:
  - Monthly & Annual Total Precipitation (mm)
  - Monthly & Annual Mean Temperature (°C)

### USGS Peak Flow Data

- Queried via `{dataRetrieval}` package
- Includes:
  - Annual peak flows
  - Site metadata
  - Regulation flags
  - Record length

## Reproducibility Notes

- PRISM rasters are stored in `.bil` format at 4km resolution
- Elevation rasters downloaded from USGS NED via `{elevatr}`
- Scripts use `{here}`, `{tidymodels}`, `{terra}`, and `{sf}`
- Site coordinates use **WGS84**; rasters use **NAD83**

## Note on Outlier Removal: Slope Outlier Site

During Milestone 09, an exploratory analysis of terrain covariates
identified a single gage site with an unusually high slope value
relative to the surrounding landscape of the Great Plains Level I
Ecoregion, where terrain is generally low relief and slope values are
typically small.

Specifically: - Site Number: `06192500` - Slope: 25.48 degrees
(substantially higher than the regional norm) - Location: Perched at the
abrupt edge of a significant elevation transition zone (e.g., mountain
front)

The slope value derived from a coarse-resolution elevation raster (z =
8, ~1 km), near a sharp elevation break.Slope estimation in these
transitional zones is highly sensitive to raster resolution and gage
placement relative to topography.

Given the magnitude of this outlier, and its likely geologic
distinctiveness compared to the majority of sites in this study area,
this site was removed from subsequent exploratory analysis and modeling
datasets.

The site was retained in the raw terrain covariate dataset
(`data/clean/data_covariates_terrain.csv`) for transparency, but
excluded from the final modeling dataset
(`data/clean/data_covariates_modeling.csv`).

### Rationale for removal:

- Prevent undue influence of a single geologically distinct site on
  model fit.

- Focus on generalizing skew relationships for typical Great Plains
  terrain settings.

- Outlier removal was fully documented in:

  - `09_join_covariates_for_modeling.R` (script)
  - `data/meta/data_covariates_modeling.csv` (metadata)

A map of the outlier location is provided in:

`results/figures/slope_outlier.png`

## Coordinate Reference Systems (CRS)

| Dataset       | CRS   | EPSG | Notes                            |
|---------------|-------|------|----------------------------------|
| PRISM         | NAD83 | 4269 | Native raster CRS                |
| USGS Sites    | WGS84 | 4326 | Transformed to NAD83 later       |
| Final Outputs | NAD83 | 4269 | All data harmonized for modeling |

## Dependencies

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

## Citations

> Daly, C., et al. (2008). Physiographically-sensitive mapping of
> temperature and precipitation across the conterminous United States.
> *International Journal of Climatology*, 28(15), 2031-2064.

> USGS NWIS Data retrieved using `{dataRetrieval}` R package.
