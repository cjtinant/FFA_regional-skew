Analysis Layout
================
CJ Tinant
2025-08-29

- [Overview](#overview)
- [Study Domain](#study-domain)
- [Nested Scale Design Framework](#nested-scale-design-framework)
  - [Variable counts by scale](#variable-counts-by-scale)
- [Covariate Descriptions](#covariate-descriptions)
- [Reference Year](#reference-year)
- [Supporting Scripts](#supporting-scripts)

# Overview

The workflow is implemented in R using {tidyverse} and related packages
to reproducibly download, clean, join, and model covariate data for
stream gage locations.

### Primary objectives

1.  **Model spatial variation in station skew** — the skew coefficient
    (Log-Pearson Type III) using numeric covariates derived primarily
    from rasters aggregated by Level II/III ecoregions and NHD+
    catchments.

2.  **Identify clusters of gaging stations** with similar covariate
    profiles to support calculation of regional skew coefficients for
    the Great Plains ecoregion.

# Study Domain

The study focuses on USGS streamflow gaging stations in the **Great
Plains ecoregion**.

- **Initial inventory:** All USGS streamflow gaging stations in the
  region ~11,000 stations.
- **Final analysis set:** ~1,700 unregulated stations with at least 20
  years of peak-flow data that meet Bulletin 17C quality criteria for
  skew estimation.

# Nested Scale Design Framework

Covariates span four domains:

- **Climate** (e.g., precipitation, temperature normals)
- **Land Cover** (e.g., cultivated fraction, vegetation types)
- **Topography** (e.g., elevation, slope, terrain curvature)
- **Watershed Metrics** (e.g., drainage area, shape indices)

To capture spatial heterogeneity and support robust regionalization,
variables are calculated at five spatial scales:

| Scale | Extent           | Sources                                      |
|:-----:|:-----------------|:---------------------------------------------|
| **0** | Station‑specific | Gage coordinates, elevation, drainage area   |
| **4** | Macroregional    | Aggregated EPA L3 to L4 Ecoregion boundaries |
| **3** | Regional         | EPA L2 Ecoregion boundaries                  |
| **2** | Subregional      | EPA L3 Ecoregion boundaries                  |
| **1** | Local            | NHDPlusHD (1:24,000) catchment boundaries    |

## Variable counts by scale

<table class="table" style="width: auto !important; margin-left: auto; margin-right: auto;">

<caption>

Table 1. Covariate counts by scale and domain.
</caption>

<thead>

<tr>

<th style="text-align:left;">

Scale
</th>

<th style="text-align:left;">

Extent
</th>

<th style="text-align:right;">

Climate
</th>

<th style="text-align:right;">

Land Cover
</th>

<th style="text-align:right;">

Topography
</th>

<th style="text-align:right;">

Watershed
</th>

<th style="text-align:right;">

Total
</th>

</tr>

</thead>

<tbody>

<tr>

<td style="text-align:left;">

0
</td>

<td style="text-align:left;">

Station-specific
</td>

<td style="text-align:right;">

2
</td>

<td style="text-align:right;">

0
</td>

<td style="text-align:right;">

1
</td>

<td style="text-align:right;">

1
</td>

<td style="text-align:right;">

4
</td>

</tr>

<tr>

<td style="text-align:left;">

4
</td>

<td style="text-align:left;">

Macroregional
</td>

<td style="text-align:right;">

3
</td>

<td style="text-align:right;">

4
</td>

<td style="text-align:right;">

3
</td>

<td style="text-align:right;">

0
</td>

<td style="text-align:right;">

10
</td>

</tr>

<tr>

<td style="text-align:left;">

3
</td>

<td style="text-align:left;">

Regional
</td>

<td style="text-align:right;">

4
</td>

<td style="text-align:right;">

4
</td>

<td style="text-align:right;">

4
</td>

<td style="text-align:right;">

5
</td>

<td style="text-align:right;">

17
</td>

</tr>

<tr>

<td style="text-align:left;">

2
</td>

<td style="text-align:left;">

Subregional
</td>

<td style="text-align:right;">

6
</td>

<td style="text-align:right;">

2
</td>

<td style="text-align:right;">

4
</td>

<td style="text-align:right;">

3
</td>

<td style="text-align:right;">

15
</td>

</tr>

<tr>

<td style="text-align:left;">

1
</td>

<td style="text-align:left;">

Local
</td>

<td style="text-align:right;">

3
</td>

<td style="text-align:right;">

2
</td>

<td style="text-align:right;">

8
</td>

<td style="text-align:right;">

4
</td>

<td style="text-align:right;">

17
</td>

</tr>

</tbody>

</table>

# Covariate Descriptions

### Station-specific (Scale 0)

Station specific covariates are point-data at the location of the gage,
and include:

- **Longitude / Latitude** — spatial position, climate & physiographic
  gradients
- **Altitude** — influences temperature, snow persistence, runoff timing
- **Watershed Area** — key hydrologic scaling predictor

### Macroregional (Scale 4)

Macroregional-scale covariates are aggregated at the L3 to L4 Ecoregion
levels to create Tallgrass Prairie, Mixed-Grass Prairie, and
Shortgrass-Steppe custom macrozones, and include:

- **Climate Zone, PHZM Zone (Dominant)** — prevailing climate,
  cold-hardiness
- **PHZM Zone Count** — climate transition diversity
- **Land Cover Fractions** — cropland, forest, grassland, urban
- **Terrain Metrics** — mean & median slope, altitude zone

For additional details on aggregation, refer to:
`output/generalized_macroregions_map.png`, and
`output/final_macroregions_map.png`)

### Regional (Scale 3)

Regional scale covariates are aggregated at the L2 Ecoregion scale:

- **Annual Temperature / Precipitation** — baseline thermal & moisture
  regime
- **Pct May–Aug Precipitation** — storm seasonality
- **NDVI Metrics** — amplitude, IQR, peak NDVI, growing season length
- **Terrain Complexity** — slope mean/skewness/variability
- **Soil Texture Fractions** — clay, silt, sand
- **Stream Order** — median & max

### Subregional (Scale 2)

Regional scale covariates are data aggregated at the L3 Ecoregion scale:

- **Seasonal Precipitation Metrics** — fall, winter, spring, summer;
  stdev; IQR
- **MODIS Land Cover % / Diversity Index**
- **Soil Permeability, Runoff Class**
- **Topographic Wetness Index (TWI)** — mean, modal, class
- **Flow Accumulation** — drainage convergence

### Local (Scale 1)

Local or catchment scale covariates are aggregated at a NHD+ HD
(1:24,000) resolution level, and include:

- **Climatic Intensity** — freeze–thaw days, Precipitation intensity,
  wet-day frequency
- **NLCD Land Cover % / Diversity Index**
- **Terrain Morphology** — elevation range, aspect, curvature, relief
  ratio
- **Watershed Geometry** — elongation ratio, circularity ratio
- **Drainage Network** — stream density, flow length, stream slope

# Reference Year

All covariates use 2016 as the reference year because it lies near the
midpoint of the 1991–2020 normals, is broadly available at high quality
(PRISM, MODIS, NLCD), and avoids major anomalies—supporting consistent,
comparable modeling across datasets and scales.

# Supporting Scripts

`R/01_download/01b_download_USGS_gage_data.R` – Download & filter gage
sites for Great Plains.

`R/01_download/01d_download_usgs_peakflow_data.R` – Download annual
peak‑flow values with batching/retry.

`R/03c_make_macrozone_lut.R` and `R\03d_make_macrozone_layer.R` –
Delineate L2 to L4 Ecoregions

See `docs/download_scripts.md` for the full script index and status.
