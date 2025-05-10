README – FFA Regional Skew Estimation
================

- [Project Overview](#project-overview)
- [Phase Objectives](#phase-objectives)
- [Analysis Layout](#analysis-layout)
  - [Study Domain](#study-domain)
  - [Nested Scale Design Framework](#nested-scale-design-framework)
  - [Environmental Covariate
    Descriptions](#environmental-covariate-descriptions)
- [Methods Notes](#methods-notes)
  - [Rationale for Using 2016 as the Reference
    Year](#rationale-for-using-2016-as-the-reference-year)
  - [Spatial Unit Merging Procedure](#spatial-unit-merging-procedure)
  - [Prairie Macrozone Delineation](#prairie-macrozone-delineation)
- [Project Structure (as of v0.4)](#project-structure-as-of-v04)
- [Project Milestones](#project-milestones)
  - [Milestone 00 – Project
    Initialization](#milestone-00--project-initialization)
- [Other Notes](#other-notes)
  - [Getting Started](#getting-started)
  - [Reproducibility](#reproducibility)
  - [Reports and Milestone Logs](#reports-and-milestone-logs)
  - [Footnotes](#footnotes)

# Project Overview

This project supports the estimation of regional skew coefficients for
flood frequency analysis (FFA) in the Great Plains. It emphasizes:

- Reproducibility through scripted, transparent workflows

- Modular data processing for climate, terrain, and hydrography

- Integration of spatial covariates to improve estimation accuracy

Flood frequency analysis estimates the magnitude and frequency of peak
flow events by fitting a probability distribution to the annual maximum
instantaneous discharge recorded at streamflow gaging stations. These
estimates are foundational for risk-based hydrologic design, including
delineation of the 100-year floodplain.

One of the core challenges in FFA is that short periods of record often
result in unstable or biased flood magnitude estimates—especially for
rare events. To mitigate this, Bulletin 17C recommends combining the
station skew (based on site-specific data) with a regional skew
coefficient to stabilize flood estimates *see footnote 1*.

However, standardized procedures for calculating robust regional skew
coefficients remain underdeveloped. This project addresses that gap by
integrating spatial and climatic covariates into a reproducible modeling
workflow designed to improve regional estimation.

# Phase Objectives

The primary goals of this phase are twofold:

- To explain spatial variation in station skew, defined as the skew
  coefficient of the Log-Pearson Type III distribution estimated at
  individual stream gages. This is accomplished by modeling skew as a
  function of numeric covariates. These covariates are primary derived
  from raster data aggregated by Level II, III Ecoregions (ecological
  and physiographic classifications), or NHD+ catchments. The covariates
  include:

  - Geographic Location (latitude and longitude)

  - Climate (e.g., precipitation and temperature normals)

  - Topography (elevation, slope, and terrain indices)

  - Watershed Characteristics (drainage area, shape, etc.)

  - Land Cover (vegetation, impervious surfaces, etc.)

- To identify clusters of gaging stations with similar characteristics
  based on these covariates. These clusters will serve as the basis for
  calculating regional skew coefficients tailored to stream discharge
  gages on Tribal lands within the Great Plains ecoregion.

# Analysis Layout

This project is implemented in R using the {tidyverse} and related tools
to automate a reproducible workflow for downloading, cleaning, joining,
and modeling covariate data associated with stream gage locations.

## Study Domain

The study focuses on stream gaging stations within the Great Plains
ecoregion. An initial inventory included approximately 11,000 stations
across the contiguous U.S. After filtering out sites with flow
regulation, water withdrawals, or insufficient record length, a final
set of ~1,100 gages was retained for analysis. Each of these stations
has more than 20 years of peak flow data and meets data quality criteria
suitable for estimating flood skew.

## Nested Scale Design Framework

Covariates span four major domains:

- Climate (e.g., precipitation, temperature normals)

- Land Cover (e.g., impervious surface fraction, vegetation types)

- Topography (e.g., elevation, slope, terrain curvature)

- Watershed Metrics (e.g., drainage area, shape indices)

To capture spatial heterogeneity and support robust regionalization,
covariates are organized into a hierarchical, multi-scale framework.
Variables are calculated at five spatial scales:

- Scale 0: Station-specific (point-level)

- Scale 1: Local (NHD+ catchment)

- Scale 2: Subregional (EPA Level III Ecoregions)

- Scale 3: Regional (EPA Level II Ecoregions)

- Scale 4: Macroregional (custom prairie macrozones derived from Level
  II groupings)

The table below summarizes the number of covariates at each spatial
scale and domain:

| Scale | Extent | Climate | Land Cover | Topography | Watershed | Total |
|:---|:---|---:|---:|---:|---:|---:|
| Station-specific | Point-level | 2 | 0 | 1 | 1 | 4 |
| Macroregional | Custom Macrozone | 3 | 4 | 3 | 0 | 10 |
| Regional | Level II Ecoregion | 4 | 4 | 4 | 5 | 17 |
| Subregional | Level III Ecoregion | 6 | 2 | 4 | 3 | 15 |
| Local | NHD+ catchments | 3 | 2 | 8 | 4 | 17 |

Table: Variable Count

The design balances resolution across spatial and temporal scales.
Macroregional-scale drivers reflect long-term, broad-context influences
such as climate zones, dominant land cover fractions, and large-scale
ecological patterns. These variables provide stable background
conditions that shape hydrologic and geomorphic processes over decadal
to centennial timeframes. Regional-scale drivers capture intermediate
temporal patterns and spatial detail, including climate normals (e.g.,
mean temperature and precipitation), seasonal storm characteristics, and
watershed properties such as stream order, terrain complexity, soil
texture, and net primary productivity. These factors influence annual to
decadal variability in hydrologic response. Subregional-scale drivers
emphasize short-term temporal dynamics and finer spatial heterogeneity,
incorporating intra-annual climate variability (e.g., seasonal
precipitation metrics), localized land use patterns (e.g., MODIS land
cover fractions and diversity indices), and terrain–hydrology
interactions (e.g., soil permeability, runoff class, topographic wetness
index, and flow accumulation). Fine-scale metrics—including climate
intensity, dominant land use, terrain morphology, watershed geometry,
and network structure—support physically based interpretation of runoff
generation mechanisms and hydrograph response characteristics.

![](README_files/figure-gfm/scale_diagram-1.png)<!-- -->

## Environmental Covariate Descriptions

| Scale | Temporal Range | Spatial Focus | Representative Variables | Hydrologic Relevance |
|:---|:---|:---|:---|:---|
| Macroregional | Decades to centuries | Continental to subcontinental | Climate zones, dominant land cover, ecoregion class | Broad climate context, vegetation regime |
| Regional | Annual to decadal | Multi-state to watershed | Climate normals, storm seasonality, stream order, terrain complexity, net primary productivity | Watershed-scale flow patterns and variability |
| Subregional | Seasonal to annual | Sub-watershed or HUC-12 | Seasonal precipitation metrics, MODIS land cover %, soil texture, runoff class, TWI, flow accumulation | Runoff potential, localized hydrologic processes |
| Fine-scale | Event to seasonal | Field-scale to catchment | Precipitation intensity, land use class, terrain morphology, watershed geometry, stream network structure | Runoff generation, hydrograph response |

Summary of Covariate Scales

### Station-Level Environmental Covariates

These point-based covariates describe intrinsic site characteristics
that serve as fixed inputs in hydrologic modeling:

- Longitude and Latitude capture spatial position, often used to model
  climatic or physiographic gradients across the study domain.

- Station Altitude represents elevation above sea level, influencing
  temperature regime, snow persistence, and runoff timing.

- Watershed Area defines the total upstream contributing area and is a
  key spatial predictor in flood frequency analysis and hydrologic
  scaling.

### Macroscale Environmental Covariates (Prairie Macrozones)

These covariates provide broad contextual information at the
macroregional scale, capturing dominant environmental regimes:

- Climate Zone and PHZM Zone (Dominant) describe prevailing climatic and
  cold-hardiness conditions.

- PHZM Zone Count reflects climate transition diversity across zones.

- Land Cover Fractions—including Cropland, Forest, Grassland, and
  Urban—represent land use intensity and vegetative cover, informing
  evapotranspiration, infiltration, and surface runoff.

- Terrain attributes, such as Mean Slope, Median Slope, and Altitude
  Zone, describe large-scale elevational patterns and slope regimes that
  shape snow accumulation, melt timing, and runoff velocity.

### Regional Environmental Covariates (Level II Ecoregions)

These covariates represent regionally coherent environmental conditions:

- Annual Temperature and Annual Precipitation establish baseline thermal
  and moisture regimes.

- Warm-season precipitation (Pct May–Aug) captures convective storm
  patterns and seasonality.

- Vegetation dynamics—via NDVI Amplitude, IQR, Peak NDVI, and Growing
  Season Length—reflect primary productivity and climatic
  responsiveness.

- Terrain complexity is quantified by Mean Slope, Slope Skewness, and
  Slope Variability, indicating energy for runoff and erosive potential.

- Soil Texture Fractions (Clay, Silt, Sand) influence infiltration rates
  and runoff production.

- Stream Order (Median and Max) characterizes the scale and branching
  complexity of river networks within the region.

### Subregional Environmental Covariates (Level III Ecoregions)

At the subregional scale, these covariates emphasize intra-annual
variability and land-use heterogeneity:

- Seasonal precipitation metrics (Fall, Winter, Spring, Summer Precip;
  Seasonal StDev; IQR) describe moisture availability and flood timing
  potential.

- MODIS Land Cover % and Diversity Index quantify vegetation type and
  fragmentation.

- Soil Permeability and Runoff Class characterize surface infiltration
  and hydrologic response potential.

  Topographic Wetness Index (TWI)—represented by Mean, Modal, and
  Class—describes terrain–moisture interactions relevant to saturation
  and runoff.

- Flow Accumulation indicates upslope contributing area, offering
  insight into drainage convergence and flood-prone zones.

### Local Hydrologic and Terrain Covariates (Catchment Scale)

These high-resolution variables, derived at the catchment scale (~1–5
km²), characterize detailed physiographic and hydrologic conditions:

- Climatic intensity metrics such as Freeze–Thaw Days, Precipitation
  Intensity, and Wet Day Frequency capture small-scale climatic
  variability.

- NLCD Land Cover % and Diversity Index describe dominant land use and
  fragmentation effects on hydrologic processes.

- Terrain morphology, including Elevation Range, Aspect (Cos/Sin),
  Curvature (Planform, Profile, IQR), and Relief Ratio, defines slope,
  concavity, and potential energy gradients.

- Watershed geometry via Elongation Ratio and Circularity Ratio provides
  insight into hydrograph timing and flood peak characteristics.

- Drainage network structure is described by Stream Density, Flow
  Length, and Stream Slope, which together determine runoff velocity,
  timing, and erosive potential.

# Methods Notes

## Rationale for Using 2016 as the Reference Year

The year 2016 was selected as the reference year for environmental
covariates due to its widespread use and stability in environmental
modeling. Key justifications include:

- It lies near the midpoint of the 1991–2020 climatological normal
  period, making it representative of typical conditions.

- Data for 2016—such as MODIS NDVI, NLCD land cover, and PRISM climate
  products—are:

  - Publicly available

  - Pre-processed and high quality

  - Free of major anomalies or interruptions

- Unlike years affected by extreme events (e.g., megadroughts or
  COVID-19), 2016 offers a stable baseline for reproducibility.

- It is also commonly adopted by agencies such as NASA, USGS, and NOAA
  as a benchmark year for geospatial and ecological analysis.

By standardizing on 2016, this project supports consistent, comparable
modeling across datasets and scales.

## Spatial Unit Merging Procedure

To ensure statistical robustness in regional analyses, polygons smaller
than 1,000 km² or containing fewer than 30 stream gages were merged with
the most ecologically similar adjacent Level III ecoregions. The merging
process followed a hierarchical decision rule:

- Primary criterion: adjacency with a unit sharing the same Level II
  ecoregion classification

- Secondary criterion: ecological similarity, evaluated using Euclidean
  distance in a multivariate space defined by:

- Land cover composition (e.g., cropland, forest, urban fractions)

- Terrain metrics (mean and standard deviation of slope)

- Vegetation seasonality (NDVI amplitude and timing of peak greenness)

This approach preserved regional coherence while improving the gage
count and spatial contiguity required for reliable skew estimation.

## Prairie Macrozone Delineation

The delineation of prairie macrozones (Tallgrass, Mixed-Grass, and
Shortgrass) in this study is based on aggregations of EPA Level III and
IV Ecoregions1, guided by ecological, climatic, and physiographic
criteria. Boundaries were refined using expert knowledge of prairie
vegetation transitions, precipitation gradients, soil characteristics,
and land use patterns.

*Where necessary, Level IV subdivisions were used to capture ecological
nuance within broader Level III units.* The classification emphasizes
hydrologically relevant differences in vegetation structure,
infiltration dynamics, and climate variability, consistent with
literature on prairie ecosystem function and landscape hydrology. This
approach allows spatial generalization while preserving ecologically
meaningful variability across the Great Plains region.

The grouping captures regions with similar hydroclimatic dynamics and
strong surface–subsurface hydrologic connectivity, important for flood
response and baseflow recharge.

#### Tallgrass Prairie Macrozone Description

The Tallgrass Prairie macrozone represents the mesic end of the prairie
continuum, with:

- High annual precipitation (typically \> 850 mm)

- Deep, fertile soils with high water retention

- Dense herbaceous vegetation, including:

  - Andropogon gerardii (Big Bluestem)

  - Panicum virgatum (Switchgrass)

  - Sorghastrum nutans (Indiangrass)

Hydrologically, this zone exhibits strong vegetation–soil feedbacks:

- strong surface–subsurface hydrologic connectivity,

- high infiltration capacity,

- and extended baseflow.

Level III and IV ecoregions in the Tallgrass Prairie macrozone include
U.S portions of Level II ecoregions, the Temperate Prairies (9.2),
western portions of the South Central Semiarid Plains (9.4), and the
Texas-Louisiana Coastal Plain (9.5).

- 9.2.1 Northern Glaciated Plains (US 46): Flat to gently rolling
  landscape composed of glacial till,

- 9.2.2 Lake Agassiz Plain (US 48): Flat thick beds of lake sediments on
  top of glacial till.

- 9.2.3 Western Corn Belt Plains (US 47): Nearly flat to gently rolling
  glaciated till plains and hilly loess plains,

- 9.2.4 Central Irregular Plains (US 40): Rolling and irregular plains
  with loess overlying glacial till in the north,

- 9.4.4 Flint Hills (US 28): Steep terrain with shallow limestone soils;
  fire-maintained tallgrass remnant.

- 9.5.1 Western Gulf Coastal Plain (US 34): Nearly flat coastal plain.

#### Mixed-Grass Prairie Macrozone Description

The Mixed-Grass Prairie macrozone is a transitional zone between the
wetter Tallgrass systems and the drier Shortgrass steppes characterized
by:

- Moderate precipitation (typically 500–800 mm)

- strong interannual precipitation variability,

- A mixture of tall, mid, and short grass species, including

  - Schizachyrium scoparium (Little Bluestem)

  - Bouteloua curtipendula (sideoats grama),

  - Bouteloua gracilis (sideoats grama),

  - Stipa sp. (Needlegrass species)

Hydrologic behavior in this macrozone is a spatially heterogeneous
hydrologically dynamic system with moderate infiltration and runoff, and
variable soil texture.

Level III and IV ecoregions in the Mixed-Grass Prairie macrozone include
U.S portions of Level II ecoregions: the West Central Semi-Arid Prairies
(9.3), central portions of the South Central Semiarid Prairies (9.4),
and uplands portions of the Tamaulipas-Texas Semi-Arid Plain (9.6).

- 9.3.1 Northwestern Glaciated Plains (US 42): a transitional region
  between Northern Glaciated Plains and the Northwestern Great Plains
  with a moderately high concentration of Prairie Potholes

<!--
**9.3.2** Piedmont
-->

- 9.3.3 Northwestern Great Plains (US 43): Rolling plain of shale and
  sandstone punctuated by occasional buttes, and

- 9.3.4 Nebraska Sand Hills (US 44): Grass stabilized sand dunes.

- 9.4.1 Western High Plains (US 25) eastern subregions:

  - Rolling Sand Plains (25b) and 

  - Flat to Rolling Plains (25d).

- 9.4.2 Eastern portions of the Central Great Plains (US 27).

- 9.6.1 Southwestern Tablelands (US 26) upland areas

  - Canadian/Cimarron Breaks (26a)

  - Semiarid Canadian Breaks (26d)

#### Shortgrass Prairie Macrozone Description

The Shortgrass Prairie macrozone marks the xeric end of the gradient,
characterized by:

- Low precipitation

- Sparse vegetation

- Shallow soils and limited infiltration

Level III and IV ecoregions in the Shortgrass Prairie macrozone include
portions of Level II ecoregions: western portions of the South Central
Semiarid Prairies (9.4), and lowlands portions of the Tamaulipas-Texas
Semi-Arid Plain (9.6).

- 9.4.1 Western High Plains (US 25) western subregions (25a, 25c, 25e to
  25l)

- 9.4.2 Central Great Plains (US 27): western extents with lower
  rainfall and shortgrass cover.

- 9.6.1 Southwestern Tablelands (US 26) lowlands areas (25b, 25c, 25e to
  25q)

Hydrologic behavior in this macrozone is dominated by rapid surface
runoff and higher flood skew, driven by reduced canopy structure and
limited ET buffering.

------------------------------------------------------------------------

# Project Structure (as of v0.4)

    FFA_regional-skew/
    ├── .gitignore                 # Ignore local/sensitive files
    ├── arcgis_project/           # ArcGIS Pro project files
    ├── data/
    │   ├── meta/                 # Metadata inputs
    │   │   ├── prism/
    │   │   │   └── ppt_30yrnormals/
    │   │   │       └── prism_ppt_30yrnormals_raw.bil
    │   │   ├── epa/
    │   │   │   └── nlcd_2021/
    │   │   │       └── epa_nlcd_2021_raw.tif
    │   │   └── usgs/
    │   │       ├── nhdplus/
    │   │       │   └── usgs_nhdplus_catchments_v21_raw.shp
    │   │       └── waterdata/
    │   │           ├── sites_all_in_bb.csv
    │   │           └── sites_all_peak_in_bb.csv
    │   ├── processed/            # Cleaned, derived datasets
    │   └── raw/                  # Unmodified source data
    ├── docs/                     # Reports, metadata, README guides
    ├── FFA_regional-skew.Rproj  # RStudio project launcher
    ├── log/                     # Logs and progress traces
    ├── notebooks/               # Exploratory .Rmd or .qmd drafts
    ├── notes/                   # Internal notes or meeting logs
    ├── output/                  # Intermediate model/data outputs
    │   ├── figs/
    │   ├── models/
    │   └── tables/
    ├── R/                       # All analysis code
    │   ├── 01_download/
    │   ├── 02_clean/
    │   ├── 03_covariates/
    │   ├── 04_modeling/
    │   ├── 05_eval/
    │   └── utils/
    ├── README.md                # GitHub-facing overview
    ├── README.Rmd               # Full workflow documentation
    ├── reports/                 # Knitted reports (.Rmd/.qmd)
    ├── results/                 # Final outputs for publication
    │   ├── posterdown/
    │   └── slides/
    ├── to_check/                # Staging area for review

# Project Milestones

## Milestone 00 – Project Initialization

This milestone establishes the foundation for reproducible regional skew
estimation through:

- Defining a modular and transparent directory structure  
- Establishing consistent naming conventions for raw, interim, and
  processed data  
- Creating a metadata inventory for raw covariates, including source
  documentation, units, spatial scale, and data format

Remaining tasks—such as dataset downloads, QA of spatial files, and
extraction of site-level covariates—have been deferred to **Milestone 01
– Download and Prepare Data** for clarity and project tracking.

**Git tag:** `milestone-00-complete`  
**Related script:**
`R/01_download/01c_data_dictionary_for_covariates.Rmd`  
**Metadata location:** `data/meta/covariates_metadata_split/`, which
contains the schema, color palette, and quality-check metadata derived
from `skew_covariates_metadata_v01.xlsx`.

### Tagged Versions

| Tag | Description |
|----|----|
| `milestone-00-complete` | Completion of Milestone 00 – Project Initialization |
| `v0.3-refactor` | Refactor (general) prior to structuring milestone folders |
| `v0.3-structure-refactor` | Major folder and file restructure |
| `v0.3.2-cleanup-vector-files` | Vector file cleanup and QA pass |
| `v0.3.3-fix-index-cleanup` | Index fix and additional cleanup tasks |
| `v0.3.4-finalize-vector-cleanup` | Final round of vector cleanup and reorganization |

# Other Notes

## Getting Started

Run scripts in order within the `R/` folder. For example:

    source("R/01_download/01_get_spatial_data.R")
    source("R/02_clean/03_filter_unregulated_gage_data.R")

All scripts assume R project is opened at the repository root (e.g.,
using .Rproj file).

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

## Footnotes

    U.S. Geological Survey, Guidelines for Determining Flood Flow Frequency—Bulletin 17C, https://doi.org/10.3133/tm4B5 ↩


    U.S. Environmental Protection Agency (2013). Level III and IV Ecoregions of the Continental United States. https://www.epa.gov/eco-research/ecoregions ↩

    PRIMARY DISTINGUISHING CHARACTERISTICS OF LEVEL III ECOREGIONS OF THE CONTINENTAL UNITED STATES ftp://ftp.epa.gov/wed/ecoregions/us/
