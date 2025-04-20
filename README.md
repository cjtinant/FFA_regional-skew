Regional Skew Estimation Project
================

- [Overview](#overview)
- [Layout of Analysis](#layout-of-analysis)
- [Planned Next Steps](#planned-next-steps)
- [Project Structure](#project-structure)
- [Workflow Overview](#workflow-overview)
- [Modeling Approach and Rationale](#modeling-approach-and-rationale)
- [Data Notes](#data-notes)
- [Ecological Regions of North
  America](#ecological-regions-of-north-america)
- [Level II Ecoregions of the Great
  Plains](#level-ii-ecoregions-of-the-great-plains)
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

## Layout of Analysis

To explore the spatial and temporal drivers of flood skewness across
diverse landscapes and climates, we adopt a multi-scale hierarchical
framework. Variables are organized by spatial-temporal scale, ecological
domain, and data type.

| scale | domain | variable | type | source_dataset |
|:---|:---|:---|:---|:---|
| Macro-regional (within GP) | Ecoregion | Great Plains macrozone (e.g., tallgrass, shortgrass, semiarid) | categorical | Custom classification (e.g., prairie types) from Level II ecoregion |
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

## Planned Next Steps

### Ecological Regions Updates

1.  Update Ecological Regions (above) with hyperlinks to maps

2.  Complete Information for Level III Ecoregions of the Great Plains

3.  Add references from above.

4.  Level III Ecoregions of the Great Plains metadata

### Circle back

1.  Download

### Document findings and modeling decisions in the README and manuscript materials.

7.  Compare performance between Generalized Additive Models (GAM) and
    Elastic Net regression.

8.  Use last_fit() for test-set evaluation of model performance.

9.  Perform cross-validation to assess generalizability and avoid
    overfitting.

10. Evaluate residual spatial autocorrelation (e.g., Moran’s I) to
    assess spatial structure not explained by the model.

11. Visualize prediction surfaces to explore spatial patterns in
    regional skew.

12. Generate clean model summaries and figures for communication and
    documentation.

13. Document findings and modeling decisions in the README and
    manuscript materials.

Future work will expand the covariate dataset to include:

- Watershed characteristics (e.g., drainage area)

- Categorical variables derived from:

  - Ecoregion membership (Levels I–IV)

  - Landscape descriptors (e.g., glaciation history, soil texture)

Subsequent analysis will explore classification approaches to group
sites into hydrologically similar regions, ultimately supporting the
development of regional skew coefficients for improved FFA applications.

- Compare performance between Generalized Additive Models (GAM) and
  Elastic Net regression.

- Use last_fit() for test-set evaluation of model performance.

- Perform cross-validation to assess generalizability and avoid
  overfitting.

- Evaluate residual spatial autocorrelation (e.g., Moran’s I) to assess
  spatial structure not explained by the model.

- Visualize prediction surfaces to explore spatial patterns in regional
  skew.

- Generate clean model summaries and figures for communication and
  documentation.

------------------------------------------------------------------------

## Project Structure

    FFA_regional-skew/
    ├── R/                        # All analysis scripts (formerly scripts/)
    │   ├── 01_download/         # NWIS, PRISM, Ecoregions
    │   ├── 02_clean/            # Processing & QA
    │   ├── 03_covariates/       # Climate, topo, landcover
    │   ├── 04_modeling/         # GAMs, Elastic Net, comparison
    │   ├── 05_eval/             # Model diagnostics, residuals
    │   └── utils/               # Functions (move from /functions)
    │       └── f_process_geometries.R
    │
    ├── data/
    │   ├── raw/                 # Unmodified downloads
    │   │   ├── prism/           # PRISM climate rasters
    │   │   └── spatial_raw/     # Shapefiles, unprocessed
    │   ├── processed/           # Cleaned tabular & spatial files
    │   └── meta/                # CRS, variable scaffold, README tables
    │       └── variable_scaffold.csv
    │
    ├── spatial/                 # Derived spatial data, ready for use
    │   ├── us_eco_lev01/
    │   ├── us_eco_lev02/
    │   ├── us_eco_lev03/
    │   ├── us_eco_lev04/
    │   ├── koppen_climate/
    │   ├── tl_state_boundaries/
    │   └── derived_products/
    │
    ├── output/
    │   ├── figs/                # Plots, maps
    │   ├── models/              # Saved model objects (.rds)
    │   └── tables/              # CSV or HTML tables (e.g., `kable`)
    │
    ├── results/                 # Final outputs: manuscript-ready summary tables, stats
    ├── reports/
    │   ├── README.Rmd                            # Full project structure and logic
    │   ├── 03c_macrozone_covariates_l2.Rmd       # Milestone structure and logic
    │   ├── posterdown/                           # Poster content
    │   └── slides/                               # Presentation files
    │
    ├── .gitignore
    ├── FFA_regional-skew.Rproj
    └── to_check/                # Keep for now, clean up later
    ├── README.Rmd         # Workflow overview (editable)
    ├── README.md          # Rendered Markdown output
    └── .gitignore         # Prevents sensitive/local files from being pushed

``` r
# hierarchical_variables <- tibble::tibble(
#   scale = c(
#     rep("Macro-regional (within GP)", 6),
#     rep("Regional (Level II)", 6),
#     rep("Subregional (Level III)", 6),
#     rep("Local (Level IV / catchments)", 6)
#   ),
#   domain = c(
#     rep(c("Ecoregion", "Location", "Climate", "Topography", "Watershed", "Land Cover"), 4)
#   ),
#   variable = c(
#     # Macro-regional
#     "Great Plains macrozone (e.g., tallgrass, shortgrass, semiarid)",
#     "Macrozone centroid or bounding box",
#     "Regional climate PC1–PC2 (or Köppen subtype)",
#     "Mean elevation, broad slope",
#     "Mean basin area per macrozone",
#     "Dominant vegetation / NLCD cover class",
# 
#     # Regional
#     "Level II ecoregion (9.2–9.6)",
#     "Regional centroid or HUC4 region",
#     "Seasonal precip/temp normals, precipitation regime (e.g., monsoon index)",
#     "Slope distribution (e.g., % flat, % steep)",
#     "Stream density, average flow length",
#     "Seasonal NDVI or cover change metrics",
# 
#     # Subregional
#     "Level III ecoregion",
#     "Station-specific coordinates",
#     "Monthly precip/temp normals, Köppen subtype",
#     "Topo roughness, elev range, TWI",
#     "NHD+ catchment metrics (e.g., area, stream order)",
#     "Land use diversity index (Shannon, Simpson)",
# 
#     # Local
#     "Level IV ecoregion",
#     "Site and catchment spatial footprint",
#     "Submonthly anomalies, snowmelt indicators",
#     "Curvature, slope aspect, local ruggedness",
#     "Local runoff potential or soil permeability",
#     "MODIS land cover diversity (TBD)"
#   ),
#   type = c(
#     # Macro-regional
#     "categorical", "spatial", "numeric / categorical", "numeric", "numeric", "categorical",
#     # Regional
#     "categorical", "spatial", "numeric", "numeric", "numeric", "numeric",
#     # Subregional
#     "categorical", "numeric", "numeric / categorical", "numeric", "numeric", "numeric",
#     # Local
#     "categorical", "spatial", "numeric", "numeric", "numeric", "categorical"
#   )
# )


   
    # "Level I ecoregion",
    # "Centroid lat/lon",
    # "Annual precip/temp normals, Köppen group",
    # "Coarse slope, elevation",
    # "Drainage area",
    # "NLCD % cover (unsure)",
    # 
    #   "Level II ecoregion",
    # "Regional centroid or bounding box (TBD)",
    # "Seasonal precip/temp normals, Köppen subgroup",
    # "Fine slope/elev",
    # "Drainage density or flow path",
    # "NLCD seasonal % change (TBD)",
    # 
    # "Level III ecoregion",
    # "Station lat/lon",
    # "Monthly precip/temp normals, Köppen subgroup (e.g. Dfb)",
    # "Topo roughness, elev range, TWI",
    # "NHD+ catchment attributes, stream order",
    # "Land use diversity index",
    # 
    # "Level IV ecoregion",
    # "Fine-scale spatial (TBD)",
    # "Submonthly climate indicator (TBD)",
    # "Curvature/aspect, microzones",
    # "Local runoff potential",
    # "MODIS class diversity (TBD)"

#   ),
#   type = c(
#     "categorical", "numeric", "numeric/categorical", "numeric", "numeric", "categorical",
#     "categorical", "spatial/numeric", "numeric/categorical", "numeric", "numeric", "categorical",
#     "categorical", "numeric", "numeric/categorical", "numeric", "numeric", "numeric",
#     "categorical", "spatial", "numeric", "numeric", "numeric", "categorical"
#   )
# )
```

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
| 11c | `11c_model_evaluation.R` | Evaluate model metrics, residuals, and spatial structure |
| 12 | `12_validate_and_interpret_models.R` | Cross-validate, compare final models, create prediction surfaces |

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

### Model Refinement Workflow

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

This section summarizes progress made toward the project’s modeling and
evaluation goals.

- Model selection guided by AIC reduction and parsimony.
- Visual diagnostics (smooth terms) confirmed non-linear relationships.
- Deviance explained: ~15%  
- Adj. R²: ~12-13%  
- Residual diagnostics were reasonable, with minor structure remaining.

1.  Model Comparison: GAM vs. Elastic Net

We compared the performance of a refined Generalized Additive Model
(GAM) and a tuned Elastic Net regression model: Model RMSE R² MAE GAM
0.588 0.135 0.449 Elastic Net 0.612 0.063 0.467

    Interpretation: The GAM outperformed the Elastic Net across all metrics. It explained slightly more variation in station skew (R² = 13.5%) and yielded lower error.

2.  Residual Diagnostics for GAM

    Histogram of residuals: Residuals appear reasonably centered around
    zero with slight skewness.

    Residuals vs Fitted: No major heteroskedasticity observed.

    Moran’s I Test: Statistically significant positive spatial
    autocorrelation in residuals:

         Moran’s I = 0.069

         p-value < 0.000001

    This suggests that while the GAM captures some spatial variation,
    important spatial structure remains unexplained — motivating further
    spatial exploration or the inclusion of spatial terms in future
    models.

3.  Deliverables Generated

    results/model_summaries/model_metrics_comparison.csv

    results/figures/obs_vs_pred_gam.png

    results/figures/obs_vs_pred_enet.png

    results/figures/resid_gam_hist.png

    results/figures/resid_gam_vs_fitted.png

    results/model_summaries/moran_gam_residuals.csv

------------------------------------------------------------------------

## Data Notes

### Spatial Data Projection

All spatial data are projected into EPSG:5070 – Albers Equal Area prior
to analysis

1.  Area, Distance, and Geometry Are Meaningful

- EPSG:4326 (lat/lon) is angular — great for global referencing but not
  suitable for accurate measurements.

- EPSG:5070 is a projected CRS in meters, ideal for:

- Calculating area, length, or spatial relationships

- Modeling variables like slope, catchment area, stream density, or
  precipitation per unit area

2.  Exploratory Data Analysis (EDA)

- Many visualization or analysis techniques (e.g., PCA, GAM, k-means,
  heatmaps) assume Euclidean geometry

- Using lat/lon introduces distortion — e.g., 1 degree longitude ≠
  constant distance across latitude

3.  Machine Learning / Modeling

- Models behave better when x/y coordinates are in consistent units

- For example, using decimal degrees for longitude and latitude while
  other variables are in meters can distort distance-based calculations

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

## Ecological Regions of North America

Ecological regions are areas of general similarity in ecosystems and in
the type, quality, and quantity of environmental resources. They serve
as a spatial framework for the research, assessment, management, and
monitoring of ecosystems and ecosystem components. They are effective
for national and regional state of the environment reports,
environmental resource inventories and assessments, setting regional
resource management goals, determining carrying capacity, as well as
developing biological criteria and water quality standards. The
development of a clear understanding of regional and large continental
ecosystems is critical for evaluating ecological risk, sustainability,
and health.

The maps shown **here** represent a second attempt to holistically
classify and map ecological regions across the North American continent
(*Commission for Environmental Cooperation Working Group, 1997*). The
mapping from 1997 and 2006 was built upon earlier efforts that had begun
individually in all three countries (e.g., *Wiken 1986*, *Omernik
1987*). These approaches recognized the need to consider a full range of
physical and biotic characteristics to explain ecosystem regions
(*Omernik 2004*). Equally, they recognized that the relative importance
of each characteristic varies from one ecological region to another
regardless of the hierarchical level. In describing ecoregionalization
in Canada, Wiken (*1986*) stated:

> Ecological land classification is a process of delineating and
> classifying ecologically distinctive areas of the Earth’s surface.
> Each area can be viewed as a discrete system which has resulted from
> the mesh and interplay of the geologic,landform, soil, vegetative,
> climatic, wildlife, water and human factors which may be present. The
> dominance of any one or a number of these factors varies with the
> given ecological land unit. This holistic approach to land
> classification can be applied incrementally on a scale related basis
> from very site-specific ecosystems to very broad ecosystems.

Determining ecological regions at a continental level is a challenging
task. It is difficult, in part, because North America is ecologically
diverse and because a nation’s territorial boundaries can be a hindrance
to seeing and appreciating the perspectives across the land-mass of
three countries. Developing and refining a framework of North American
ecological regions has been the product of research and consultation
between federal, state, provincial and territorial agencies. These
agencies were often government departments, but the initiative also
involved nongovernmental groups, universities and institutes. The
Commission for Environmental Cooperation (CEC) was instrumental in
bringing these groups together. The CEC was established in 1994 by
Canada, Mexico, and the United States to address environmental concerns
common to the three countries. The CEC derives its formal mandate from
the North American Agreement on Environmental Cooperation (NAAEC), the
environmental side accord to the North American Free Trade Agreement
(NAFTA).

These maps represent the working group’s best consensus on the
distribution and characteristics of major ecosystems on all three levels
throughout the three North American countries. The methodology
incorporated these points in mapping ecological regions:

- Ecological classification incorporates all major components of
  ecosystems: air, water, land, and biota, including humans.

- It is holistic (“the whole is greater than the sum of its parts”).

- The number and relative importance of factors that are helpful in the
  delineation process vary from one area to another, regardless of the
  level of generalization.

- Ecological classification is based on hierarchy—ecosystems are nested
  within ecosystems as mapped, although in reality, they may not always
  nest.

- Such classification integrates knowledge; it is not an overlay
  process.

- It recognizes that ecosystems are interactive—characteristics of one
  ecosystem blend with those of another.

- Map lines depicting ecological classification boundaries generally
  coincide with the location of zones of transition. A Roman numeral
  hierarchical scheme has been adopted for different levels of
  ecological regions.

Level II ecoregions are intended to provide a more detailed description
of the large ecological areas nested within the level I regions. Level
II ecological regions are useful for national and subcontinental
overviews of ecological patterns. Level II ecological regions provide
national and subcontinental overviews of ecological patterns:
topography, climate, and land cover type.

Level III ecoregions are smaller ecological areas nested within level II
regions. These smaller divisions enhance regional environmental
monitoring, assessment and reporting, as well as decision-making.
Because level III regions are smaller, they allow locally defining
characteristics to be identified, and more specifically oriented
management strategies to be formulated.

- At level III, the continent currently contains 182 ecological regions.

- The level III ecological region map depicts revisions and subdivisions
  of earlier level I, II, and III ecological regions (CEC 1997, McMahon
  et al., 2001, Omernik 1987, USEPA 2006; Wiken 1986, Wiken et al.,
  1996).

## Level II Ecoregions of the Great Plains

The Great Plains are one of 15 broad, level I ecological regions. Level
I ecological regions highlight major ecological areas and provide a
broad backdrop to the ecological mosaic of the continent, putting it in
context at global or intercontinental scales. Viewing the ecological
hierarchy at this scale provides a context for seeing global or
intercontinental patterns.

DESCRIBE THE GREAT PLAINS

### The Temperate Prairies (9.2)

### The West-Central Semiarid Praries (9.3)

The West-Central Semi-Arid Prairies are a large region in the
northwestern part of the Great Plains. It extends roughly
northwest-southeast, and occupies most of Montana, the western portion
of the Dakotas, northeastern Wyoming, and much of northern Nebraska.

The topography is fairly diverse, ranging from flat to tablelands and
badlands, with some sand dunes. The climate is a semi-arid continental
climate. There is significant seasonality of precipitation, with the wet
season usually being May-July. Locally-originating streams are mostly
seasonal or intermittent, but there are also perennial streams
originating uphill in the Western Cordillera. Seasons are well-defined,
with hot summers and cold winters. As one moves west, rainfall
decreases, but the coldest winter temperatures are also reduced slightly
due to increased distance from the cold air masses that often penetrate
furthest close to the center of the continent.

This area was historically covered by short- and mixed-grass prairie.
Nowadays there is significant agriculture in the region, although less
than the more fertile lands to the east. Use of land for grazing animals
is more common than for cropland. Agricultural use of the grasslands in
this region is expected to increase.

Most of this region is sparsely populated, and it does not contain any
large cities.

In Wyoming, to the southwest, this regions transitions gradually into
the Cold Deserts. To the west, and also at a few isolated regions of
higher altitude, this region borders the Western Cordillera. Most of
this region, however, is surrounded by more of the Great Plains. To the
north and east, it transitions to the slightly moister Temperate
Prairies, and to the south, the South-Central Semi-Arid Prairies
(<https://bplant.org/region/37?utm_source=chatgpt.com>)

### The South Central Semiarid Prairies (9.4)

### The Texas-Louisiana Coastal Plain (9.5)

### The Tamaulipas-Texas Semiarid Plain (9.6)

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

> Commission for Environmental Cooperation Working Group (1997).
> Ecological regions of North America – toward a common perspective:
> Montreal, Commission for Environmental Cooperation, 71 p.

> Daly, C., et al. (2008). Physiographically-sensitive mapping of
> temperature and precipitation across the conterminous United States.
> *International Journal of Climatology*, 28(15), 2031-2064.

> McMahon, G., Gregonis, S.M., Waltman, S.W., Omernik, J.M., Thorson,
> T.D., Freeouf, J.A., Rorick, A.H., and Keys, J.E., 2001, Developing a
> spatial framework of common ecological regions for the conterminous
> United States: Environmental Management, v. 28, no. 3, p. 293-316.

> Omernik, J.M., 1987, Ecoregions of the conterminous United States (map
> supplement): Annals of the Association of American Geographers, v. 77,
> no. 1, p. 118-125, scale 1:7,500,000.

> Omernik, J.M., 2004, Perspectives on the nature and definition of
> ecological regions: Environmental Management, v. 34, Supplement 1,
> p. s27-s38.

> U.S. Environmental Protection Agency, 2006, Level III ecoregions of
> the continental United States (revision of Omernik, 1987): Corvallis,
> Oregon, USEPA – National Health and Environmental Effects Research
> Laboratory, Map M-1, various scales.

> Wiken, E.B., 1986, Terrestrial ecozones of Canada: Ottawa, Ontario,
> Environment Canada, Ecological Land Classification Series no. 19, 26
> p.

> Wiken, E.B., Gauthier, D., Marshall, I.B., Lawton, K., and Hirvonen,
> H, 1996, A perspective on Canada’s ecosystems: An overview of the
> terrestrial and marine ecozones: Ottawa, Ontario, Canadian Council on
> Ecological Occasional Paper No. 14, 95 p.

> USGS NWIS Data retrieved using `{dataRetrieval}` R package.
