Script Notes and Developer Log
================
C.J. Tinant
October 22, 2025

- [Overview](#overview)
- [Project Notes (General)](#project-notes-general)
- [TODO (General)](#todo-general)
- [Future Ideas](#future-ideas)
- [Notes by Script](#notes-by-script)
- [CHECK INTO DAGS for looking into
  covars.](#check-into-dags-for-looking-into-covars)
  - [Zettelkasten-style markdown](#zettelkasten-style-markdown)
  - [Notes](#notes)

## Overview

This document collects implementation notes, design decisions, and
development comments across scripts used in the regional skew estimation
project. It supports ongoing improvements and serves as a lightweight
developer log.

Use this log to track:

- Known issues or limitations
- Planned improvements (`TODO`)
- Script-specific decisions or reminders
- Ideas for refactoring or cleanup

------------------------------------------------------------------------

## Project Notes (General)

<!--
- PRISM climate data naming should follow convention: `ppt_ann_mm`, `tmean_jan_C`, etc.
- `data/meta/` stores all metadata CSVs, including raster and vector spatial info
- Avoid hardcoded paths or layer names; use dynamic detection when possible
-->

------------------------------------------------------------------------

## TODO (General)

<!--
- [ ] Add version check for `{terra}` to all raster scripts
- [ ] Write a unified function to extract raster metadata to `data/meta/`
- [ ] Add `README.Rmd` to `R/02_process/` with script overview
-->

------------------------------------------------------------------------

## Future Ideas

- Add `docs/variable_scaffold.csv` after covariate extraction to
  distinguish between exploratory output and final cleaned results.

- Adopt a targets-based workflow {targets} after covariate extraction.

<!--
- Add script benchmarking to track execution time across revisions
- Add logging (e.g., `cli::cli_alert()`) for key script actions
- Create a `.Rprofile` project startup file to auto-load common packages
-->

## Notes by Script

### `01a_download_ecoregions.R`

- Original metadata & layer files for each level are downloaded for
  reference.
- Data sources are EPA/CEC shapefiles hosted via AWS links.
- This script assumes internet access and local write permissions.

------------------------------------------------------------------------

### 01b_download_USGS_gage_data.R

- Requires internet access to download data from USGS NWIS.
- Bounding box grid helps avoid request size limitations in NWIS
  queries.
- Uses a batch download approach for peak flow data retrieval.
- Great Plains extent is defined using EPA Level 1 Ecoregion shapefiles.

------------------------------------------------------------------------

### 01d_download_us_peakflow_data.R

- The script inputs data from `01c_download_usgs_gage_metadata.R`
- The script does not apply filtering on regulation, dam failure, or
  record length.
- Filtering occurs in the subsequent script –
  `01e_filter_usgs_peakflow_data.R`

------------------------------------------------------------------------

### 01e_filter_usgs_peakflow_data.R

- Bulletin 17C explicitly recommends using the Multiple Grubbs-Beck Test
  (MGBT) to identify low-end outliers, e.g. zero flows, and near-zero
  flows like 0.01, 0.02, 0.05, etc. MGBT() flags observations below a
  calculated threshold discharge.
- The inclusion of outliers (note in FFA there are only low-end
  outliers) distorts the estimation of the log-Pearson Type III
  distribution, biasing skewness, mean, and standard deviation. PILFs
  tend to skew the lower tail, by underestimating the sample skewness
  and producing unrealistic estimates for rare floods.
- Peak codes are comma-separated and must be parsed for reliable
  flagging
- Skewness is calculated as type = 1, using a method of moments
  estimator which follows the guidances under Bulletin 17C
- Install peakfq directly from USGS GitLab
  `remotes::install_gitlab("water/peakfqr", host = "code.usgs.gov")`

------------------------------------------------------------------------

### 01f_download_nhdplus_v2.R

- The code retrieves flowlines and catchments intersecting the buffered
  AOI
- `get_nhdplus()` loops through 144 tiles that intersect AOI.
  - It fetches data chunk-by-chunk and begins stitching them together.
  - Midway or After Completion: Invalid Geometry Detected
  - The function detects one or more invalid geometries (e.g.,
    self-intersecting polygons or degenerate line segments).
  - It triggers a geometry repair step internally – sf / s2 Geometry
    Repair Mode Kicks In. This temporarily activates s2 geometry engine
    to fix topological errors, which is common in large hydrologic
    datasets. You see:
    - Found invalid geometry, attempting to fix.
    - Spherical geometry (s2) switched on
    - Spherical geometry (s2) switched off
    - Tiles Are downloaded again. The function starts over, reloading
      the same set of tiles (tiles 1–144) with geometry corrections in
      place.
  - This is expected behavior in nhdplusTools when:
    - An invalid feature is encountered (common with complex catchments
      or clipped geometries), and get_nhdplus() must retry with geometry
      repair enabled.

------------------------------------------------------------------------

### 01g_download_nhdplus_hr.R

Key Features of the script: - Idempotent: skips previously downloaded
regions - Geometry-safe: cast, buffer, validate for AOIs - Fuzzy retry
logic: name correction and tile fallback - Transparent logging:
CSV-based log with timestamped status - Interactive QA: mapview preview
of results

------------------------------------------------------------------------

### 01m_download_nlcd_2016.R

The NLCD raster was manually downloaded. Using {FdData} All tile
requests timed out at ~30 seconds. Received over 100–200 MB per tile,
but not enough to complete the download. Then FedData::get_nlcd(),tried
to crop those partial files, which resulted in a crash.

The script inputs the following files and projects the raster to the
vector CRS.

- a raster file: a SpatRaster (e.g., the full NLCD)
- a vector file: a SpatVector (e.g., Great Plains boundary)

Next, the script applies the following functions:

- crop() – Trims the raster extent down to the bounding box of the
  vector geometry (shape). Keeps all raster cells that intersect the box
  — even if they fall outside the exact shape.
- mask() – Replaces all raster cells outside the exact shape with NA.
  Keeps only values within the actual polygon boundary.

Added later: Paying attention to raster type is an important safeguard.
I ran into a time-consuming issue when summarizing raster values for a
categorical classification. The issue was that the raster was being
automatically saved as floating point, FLT4S (see below).

The fix was to redownload the raster and ensure the raster is saved as
INT1U.

The range of NLCD raster integer values should be between 11 to 95,
which represents different types of land cover (see NLCD LUT in /docs).
Thus, saving as ‘INT1U’, an unsigned 8-bit integer raster, enforces that
values stay integers, and it signals downstream tools not to expect
fractions.

The appropriate format for saving an ‘INT1U’ raster is as follows: INT =
integer 1 byte = 8 bits per pixel = e.g. 2^8 = 256, so values range from
0–255 U = unsigned (can’t store negatives)

Other common terra datatypes are: INT1U = unsigned 8-bit integer INT2S =
signed 16-bit integer (–32,768 to 32,767) INT2U = unsigned 16-bit
integer (0 to 65,535) FLT4S = 32-bit float FLT8S = 64-bit float (double
precision)

------------------------------------------------------------------------

### 01n_download_ned.R

**2025-10-07** Fixed issue with mismatched tile grids (different
resolutions/origins) that caused an issue with mosiacing.

*docs/README version*

Source: Elevation fetched via elevatr at zoom 10 (Web-Mercator).

Nominal resolution (z=10) at macrozone latitudes (~35–50°N): ~100–120
m/px.

Warped tile resolution (EPSG:4326) chosen automatically during per-tile
reprojection: ~60–72 m/px (Y) with varying grid origins (see
data/meta/2025-10-07_ned_tiles_resolution_z10.csv).

Analysis grid: Reprojected to EPSG:5070 and resampled to a fixed 90 m
cell size prior to mosaicking and summaries.

*Short Version* The underlying cause of the issue was each of the 36
tiles came back at the same zoom (z = 10) but were each reprojected &
clipped independently. During the per-tile warp from the service’s
native grid to EPSG:4326, GDAL/terra auto-chooses a target cellsize and
grid origin from each tile’s extent. Because each tile sits at a
different latitude and has a slightly different bbox, the result is
tiles with discrete degree-resolutions and origins: the range of the
resulting degree-resolutions was between \[0.000536, 0.000648\] degrees
(see results at data/meta/2025-10-07_ned_tiles_resolution_z10.csv).

*Long Version* The reason for the issue is the source elevation tiles
are served on a Web-Mercator tile pyramid at a fixed zoom z (used z =
10). The tiles were downloaded using EPSG:4326 with clip=“locations”.
Each tile is warped separately to lon/lat and then trimmed to your
polygon. In that warp, the target resolution (in degrees) is computed
automatically to roughly preserve input pixel density. Because meters/px
in Web-Mercator varies with latitude, the degrees/px picked for each
tile ends up slightly different.

Each tile also gets its own grid origin, so even tiles with the same
res_x/res_y won’t line up unless you snap them. Results explained:

- `res_y` values were ~0.000536–0.000648 deg, which is translate to
  ~60–72 m north–south per pixel (1-deg lat ≈ 111,132 m).

- `res_x` values also vary by cos(latitude). At 40 deg N a 0.000613 deg
  longitude pixel is ≈ 0.000613 × 111,320 × cos(40 deg) ≈ 52 m.

For *Web-Mercator* ground resolution at Great Plains latitudes (~35–50
deg N), z = 10 is ~100–120 m/px (not 60–72 m per-tile warp for
EPSG:4326). GDAL/terra auto-picks a denser degree grid for each tile
(oversampling), so the derived meters/px look finer than the z = 10
nominal.

\*Nominal (Web-Mercator) resolution at z=10:

$$
r(z, \phi)=156543.0339 \cdot \cos (\phi) / 2^z \mathrm{~m} / \mathrm{px}
$$

Examples: 40 deg N is ~116.7 m; 45 deg N is ~108.1 m; 49 deg N is ~100.3
m.

Tiles were fetched at z = 10, then reprojected & clipped to lon/lat
independently. In that warp, each tile got its own degree cellsize and
origin to “preserve detail,” often oversampling to ~60–72 m north–south.

**Cellsize decision for macrozones**

For macrozones: I used a z = 10 request and a 90 m cell size, because
the 60–70 m in EPSG:4326 is oversampled, which looks sharper but adds no
new information (false precision from per-tile oversampling). Note, for
finer scale (~60–70 m) output, use a z = 11 request, which will result
in heavier (greater) download density (time) and a greater number of
timeouts.

Slope was calculated using (Fleming & Hoffer / Ritter algorithms), which
use only the four cardinal directions (rook’s case) to produces
smoother, more generalized slope surfaces, which better matches subtle
terrain transitions, especially in agricultural, prairie, or floodplain
contexts.

When clipping I used `expand = 1000` for buffer to help prevent clipping
artifacts near edges

------------------------------------------------------------------------

### 01o_download_modis_ndvi_2016.R

NDVI, or Normalized Difference Vegetation Index is a measure of
photosynthetic activity occurring within a pixel, which is commonly used
to assess the health and density of vegetation. NDVI ranges from \[-1,
+1\], with healthy vegetation typically between \[0.6, 0.9\]. Higher
NDVI values indicate healthier, more vigorous vegetation.

- NDVI = (NIR - Red) / (NIR + Red)

NDVI for the Great Plains ecoregion is calculated from MODIS, or
Moderate Resolution Imaging Spectroradiometer data on the NASA Terra
satellite. The relevant data, 250m resolution, 16-day composites, are
labeled as `MOD13Q1`.

- MOD = MODIS sensor on Terra satellite
- 13 = Product suite 13: Vegetation Indices
- Q1 = 16-day temporal composite
- 061 = Collection 6.1 (latest operational version)

MOD13Q1 tiles contain multiple subdatasets (SDS): - NDVI — Normalized
Difference Vegetation Index - EVI — Enhanced Vegetation Index - VI
Quality — Bit-packed QA layer - Reflectance — Red, NIR, Blue bands used
for index calculation - Day of Year — Date of composite

MODIS data are projected to a sinusoidal projection to preserve the
relative size of land areas on the Earth’s surface. The sinusoidal
projection is an equal-area projection. MODIS tiles are 10-degrees by
10-degrees at the equator, and are named using Cartesian coordinates
such that a tile named like h10v05 indicates the tile is the tenth tile
from the origin in the horizontal direction and the fifth tile in the
vertical direction from the origin (see
<https://modis-land.gsfc.nasa.gov/MODLAND_grid.html>).

NDVI was chosen over EVI or Enhanced vegetation index for the Great
Plains ecoregion. EVI is an index similar to NDVI that reduces the
effects of: canopy background, aerosols (blue-band correction), and soil
brightness, which often improves performance in dense forests. NDVI was
selected for this project for the following reasons:

- Moderate to sparse vegetation: prairie, cropland, rangeland.
- Low cloud/aerosol interference: no need for blue-band correction.
- Wide use in agriculture and rangeland applications, such as crop
  condition, forage productivity, and drought/grazing assessment
  (VegDRI, USDM, NDMC).
- Fewer assumptions and post-processing corrections.

------------------------------------------------------------------------

### 02a_merge_nhdplus_hr_flowlines.R

Type coercion is the process of converting a value or object from one
data type to another. This can occur either automatically (implicitly)
or intentionally (explicitly). Explicitly fixes issues using a
file-reading loop with type coercion and error logging. The loop fixes
the following issues: - Only coerce if possible, using a safe test like
is.integerish(). - Fallback to numeric when needed. - Applies coercion
one column at a time - Skips columns that cause errors (and logs them) -
Prevents across() from failing all at once - Wrap the across() call in
logic that filters to only existing columns. - Fine-grained control:
logs problems per column, per file - Non-blocking: does not interrupt
the whole region’s read if a single column fails - Quiet warnings: keeps
logs readable but still lets you know what happened - coerce fdate to
character safely in all files. Character is the most flexible, readable,
and safest for uncertain timestamp formats.

------------------------------------------------------------------------

### 02b_merge_nhdplus_hr_catchments.R

### 02c_validate_spatial_metadata.R

### 02d_extract_metadata_from_script_names.R

### 02e_gp_parts_qc_and_outline.R

------------------------------------------------------------------------

The original extent for the Great Plains Level 1 Ecoregion contains
small polygons along the Texas-Louisiana Coastal Plain and the disjunct
Texas Blackland Prairies.

The Texas Blackland Prairies region forms a disjunct ecological region,
distinguished from surrounding regions by fine-textured, clayey soils
and predominantly prairie potential natural vegetation. The predominance
of Vertisols in this area is related to soil formation in Cretaceous
shale, chalk, and marl parent materials. Unlike tallgrass prairie soils
that are mostly Mollisols in states to the north, this region contains
Vertisols, Alfisols, and Mollisols.

------------------------------------------------------------------------

### utils/process_geometries.R

Centroid locations, which the function extracts are useful for map
labeling, visualization, and spatial summaries. The function applies
strict checks for geometry validity and centroid coordinate extraction
to avoid errors during plotting or labeling. The safeguards include
checks for NA geometries, checks for empty or NULL centroids, explicit
verification of coordinate matrix structure before extraction. Some
addional details about process_geometries():

**Geometry Validation:** `st_make_valid()` is used to correct any
invalid geometries within the spatial data frame. The function
identifies indices of valid geometries to ensure that centroids and
subsequent operations are only applied to them.

**Centroid Calculation:** `st_centroid()` is applied conditionally only
to valid geometries using ifelse(). If a geometry is invalid, NA is used
as a fallback. st_centroid() is applied only to the valid parts of the
geometry column. Centroids are stored in a list to handle any type of
geometry being returned from st_centroid(). Each geometry is processed
individually within a loop to allow more control over handling each item
and better debugging capabilities if errors occur. !is_empty(centroid)
checks if the centroid is not empty. The function also ensures that
st_coordinates(centroid) actually returns a non-empty data frame before
trying to access its elements.

**Conditional Coordinates Extraction:** The x and y coordinates are
extracted from the centroid. If the centroid is NA (because the geometry
was invalid), the coordinate fields are set to NA. Coordinates are
extracted only if there are valid centroids. This is safeguarded by
checking if there are valid indices before attempting to extract
coordinates. `text_x` and `text_y` are initialized with NA_real\_ to
ensure that the type consistency is maintained for cases where centroids
might not be computable. Before extracting coordinates, the function
checks if the centroid is not NA and contains rows. Then it ensures that
the coordinates can be indexed properly, and has the required number of
columns (at least two, for x and y coordinates).

**Additional checks:** The function has additional checks for NAs and
data structure validity. The function checks if centroid is not NA and
not empty. Then, if coordinates are derived, the function ensures it is
not NA and has the necessary rows and columns. The function avoids
coercion errors by ensuring each part of the conditional is valid before
evaluating the next part, this prevents logical operations on possibly
undefined or inappropriate data types. The function logic is structured
to progressively verify conditions before accessing potentially
problematic attributes like the number of rows or columns. The function
ensures that coords is not null before proceeding to check its
dimensions. This prevents logical errors when coords might be an
unexpected type or structure. Rhe function more reliably ensures the
data structure is correct before attempting to access its elements by
using is.null along with checks for the number of rows and columns in
`coords`

------------------------------------------------------------------------

### 03a_update_covariate_metadata.R

Notes on project data structure: - Project datasets consist of feature
data, vector data, and raster data stored in `~/data/processed/` - The
response variable is station skew, which can be represented as vector
point data. - The 63 initial explanatory variables, i.e. covariates or
‘covar’ in the script below, are structured by hierarchical scale
(ordinal data) and domain (categorical data) - The covariate data are
aggregated at each scale: Hierarchical Scale Aggregated by: 0 - Station
NA 1 - Macroregional Macrozone 2 - Regional Level II Ecoregion 3 -
Subregional Level III Ecoregion 4 - Local NHDPlusHD catchment

Domain Category A - Climate B - Land Cover C - Topography D - Watershed
Metrics

------------------------------------------------------------------------

### 03b_station_covars.R

Station-level (Level 0) data include three location parameters:
longitude, latitude and altitude, and one scale parameter: watershed
area. Altitude and watershed area are reported in SI units and
transformed to EPSG:5070.

The parameters for drainage area and contributing drainage area were
coalesced prior to dropping gages with missing drainage area or altitude
data.

------------------------------------------------------------------------

### 03c_make_macrozone_lut.R

Macrozones, which represent the coarsest analysis scale for the project,
are delineated along a composite gradient of moisture availability, soil
development, and groundwater connectivity. These patterns are broadly
reflected in three macrozones: Tallgrass Prairie, Mixed-Grass Prairie,
and Shortgrass Steppe.

Ecoregion Level designations follow both North American Ecoregion
nomenclature and United States (US) Ecoregion nomenclature. For example,
NA_L3CODE == 9.4.1 refers to: 9 GREAT PLAINS dot 4 SOUTH CENTRAL
SEMI-ARID PRAIRIES dot 1 HIGH PLAINS and correspond with US_L3CODE == 25
High Plains. The L4 designations follow the Level IV Ecoregion
nomenclature (US_L4CODE), e.g. 25b the Rolling Sand Plains L4 Ecoregion
of the High Plains. Macrozones are delineated at the L3 Ecoregion scale,
when possible. Regions with greater variability at the L3 Ecoregion
scale, e.g. the central and southern Great Plains States ,
i.e. Colorado, Kansas, Oklahoma, New Mexico, and Texas, exhibit a one to
many cardinality at the L3 scale, and are delineated at the Level IV
(L4) Ecoregion scale. Vegetative composition described in State-level L4
descriptions by Omerick and others (see Related Files below) was the
primary basis for macrozone classification.

The general characteristics of the custom macrozones are as follows:

The **Tallgrass Prairie Macrozone** is located in the eastern portion of
the Great Plains in the glacial till and loess plains of the Temperate
Prairies Ecoregion, eastern portions of the South Central Semiarid
Plains Ecoregion in the Flint Hills region, where a natural fire
frequency has maintained this tallgrass remnant community. The Tallgrass
Prairie macrozone is an area of higher annual precipitation (typically
\> 850 mm), deep, fertile soils with high water retention, and dense
herbaceous vegetation, and extended baseflow. Characteristic species in
the macrozone include: Andropogon gerardii (Big Bluestem), Panicum
virgatum (Switchgrass), Sorghastrum nutans (Indiangrass).

The **Mixed-Grass Prairie Macrozone** generally marks a transition from
mesic Tallgrass Prairie in the eastern Great Plains and xeric Shortgrass
Steppe in the western portion of the region, and consist of the L2
ecoregions: West Central Semi-Arid Prairies, the Northwestern Glaciated
Plains, central portions of the South Central Semiarid Prairies, eastern
portions of the Central Great Plains, and uplands portions of the
Tamaulipas-Texas Semi-Arid Plains. The macrozone is an area of moderate
precipitation (typically 500–800 mm), and high interannual precipitation
variability, variable soil textures, and a combination of event-driven
flow and baseflow regimes. The macrozone is characterized by a mixture
of tall, mid, and short grass species, including: Schizachyrium
scoparium (Little Bluestem), Bouteloua curtipendula (Sideoats Grama),
Bouteloua gracilis (Blue Grama), and Stipa sp. (Needlegrass species).

The **Shortgrass-Steppe Macrozone** is located in the western portion of
the Great Plains in the western portions of the South Central Semiarid
Prairies, Western High Plains, Central Great Plains, and lowlands
portions of the Tamaulipas-Texas Semi-Arid Plain and Southwestern
Tablelands. The Shortgrass Steppe is characterized by low precipitation,
sparse vegetation, shallow soils with limited infiltration, rapid
surface runoff, a rapid-response, event-driven hydrologic regime, higher
flood skew, driven by reduced canopy structure and limited ET buffering.

### Related Files:

- `l3_ecoregion_descriptions.Rmd`

------------------------------------------------------------------------

### 03d_make_macrozone_layer.R

The Texas-Louisiana Coastal Plain was removed from the analysis prior to
developing custom macrozones. The reasons for removal include a high
degree of fragmentation, a substantially different geography,
e.g. coastal geography and barrier islands. Additionally, polygons less
than 100 square kilometers were merged with nearest neighbors.

Macrozones are generalized following aggregation to remove polygons
smaller than 1,000 sq-km or containing fewer than 30 stream gages were
merged with the most ecologically similar adjacent Level III Ecoregion.
The idea behind generalization is to preserve regional coherence while
improving the gage count and spatial contiguity required for reliable
skew estimation.

The merging process followed a hierarchical decision rule:

- Primary criterion: adjacency with a unit sharing the same Level II
  ecoregion classification

- Secondary criterion: ecological similarity, evaluated using Euclidean
  distance in a multivariate space defined by:

- Land cover composition (e.g., cropland, forest, urban fractions)

- Terrain metrics (mean and standard deviation of slope)

- Vegetation seasonality (NDVI amplitude and timing of peak greenness)

------------------------------------------------------------------------

### Zonal Summaries

Zonal summaries are used to calculate macrozone-scale patterns in
climate, land cover, and topography.

The climate pattern summaries indicate broad-scale climate context,
e.g. humid continental vs. semi-arid, cold hardiness diversity, and cold
tolerance regimes based on minimum winter temperatures.

The scripts call utility scripts prior to calculating zonal summaries.

### Naming convention

|     Short Name     |       Dataset        | Summary Type |   Variable Name    |
|:------------------:|:--------------------:|:------------:|:------------------:|
|    Climate Zone    |    Koppen-Geiger     |   Dominant   |  `kopp_geig_dom`   |
|  PHZM Zone Count   | Plant Hardiness Zone |    Count     |     `phzm_cnt`     |
| PHZM Zone Dominant | Plant Hardiness Zone |   Dominant   |     `phzm_dom`     |
| Cropland Fraction  | NLCD 2016 Land Cover |   Fraction   | `nlcd_crppst_frac` |
|  Forest Fraction   | NLCD 2016 Land Cover |   Fraction   | `nlcd_forst_frac`  |
| Grassland Fraction | NLCD 2016 Land Cover |   Fraction   | `nlcd_grass_frac`  |
|   Urban Fraction   | NLCD 2016 Land Cover |   Fraction   | `nlcd_urban_frac`  |
|     Mean Slope     |      NED Slope       |     Mean     |   `ned_slp_mean`   |
|    Median Slope    |      NED Slope       |    Median    |   `ned_slp_med`    |
|   Altitude Zone    |    NED Elevation     |     Mean     |  `ned_elev_mean`   |

### Generalized Workflow Prior to Performing a Zonal Summary

First, run a pre-flight check with `utils/spatial/assert_inputs_ok.R`
that performs the following: - Verify that rasters can be opened. -
Enforce CRS and polygonal geometry. - Standardize the geometry column as
`geom`. - Guarantees unique, non-NA IDs.

Second, prep and align raster and zone `utils/spatial/prep_and_align.R`.
The function performs the following: - Ensures zones are valid
(optional), converts to SpatVector, and reprojects zones to the raster’s
CRS (no raster warping). - Returns a SpatVector (polygon) in the same
CRS as the raster. - Prep the raster to get zones in the raster CRS. -
Optionally, crop the raster to the zones bbox and mask it to polygon
shapes.

This returns a list that needs to be extracted then converted from a
SpatVector to an sf object prior to {exactextractor} in
`utils/spatial/rast_summ_by_class.R`

### 03e_macrozone_fix_join_key.R

Fix join key to fix an issue with Tallgrass Prairie and provide some
ordinal order.

|         region_name          | macro_id |
|:----------------------------:|:--------:|
|      Shortgrass-Steppe       |    1     |
| Northern Mixed-Grass Prairie |    2     |
| Central Mixed-Grass Prairie  |    3     |
| Southern Mixed-Grass Prairie |    4     |
|      Tallgrass Prairie       |    5     |

------------------------------------------------------------------------

### 03f_covar_macro_koppen_summary.R

Dominant Koppen-Geiger climate classes provides a broad-scale context on
climate, e.g. humid continental vs. semi-arid.

The original Koppen-Geiger summary was a single dominant class. After an
initial analysis, the zonal summary was expanded to the top n classes.
Used n = 3. The original result contains 15 results. This was filtered
using min_frac to minimize the number of categories and the total amount
unexplained. The final result contains nine climate types across five
macrozone categories with 29.9% of the variance unexplained.

**Table of Results of Koppen-Geiger Climate Zonal Summary:**

| n-vals | max_tot_unexpl | min_frac | num_cat |
|:------:|:--------------:|:--------:|:-------:|
|   15   |     0.212      |    NA    |    5    |
|   14   |     0.212      |   0.07   |    5    |
|   13   |     0.212      |   0.08   |    5    |
|   12   |     0.299      |   0.09   |    5    |
|   11   |     0.299      |   0.11   |    5    |
|   10   |     0.299      |  0.135   |    5    |
|   09   |     0.299      |   0.14   |    5    |
|   08   |     0.441      |   0.15   |    5    |
|   07   |     0.441      |   0.25   |    5    |
|   06   |     0.441      |   0.35   |    5    |
|   05   |     0.618      |   0.37   |    5    |

**Table of Results of Koppen-Geiger Climate Zonal Summary:**

| Macrozone | Koppen Climate Type | Description |
|:--:|:--:|:--:|
| Tallgrass Prairie | Dfa | Cold, no dry season, hot summer |
| Northern Mixed-Grass Prairie | Dfa | Cold, no dry season, hot summer |
| Northern Mixed-Grass Prairie | BSk | Arid, steppe, cold |
| Central Mixed-Grass Prairie | Dfa | Cold, no dry season, hot summer |
| Central Mixed-Grass Prairie | Cfa | Temperate, no dry season, hot summer |
| Southern Mixed-Grass Prairie | Cfa | Temperate, no dry season, hot summer |
| Southern Mixed-Grass Prairie | BSh | Arid, steppe, hot |
| Shortgrass-Steppe | BSk | Arid, steppe, cold |

------------------------------------------------------------------------

### 03g_covar_macro_phzm_summary.R

Outputs the top-3 dominant and count of phzm zones, and qa plots as a
sanity check. The top-3 dominant and count of phzm zones indicates a
broad-scale context on climate based on cold tolerance regimes based on
minimum winter temperatures, and cold hardiness diversity. The QA plots
phzm count vs area and phzm count vs latitude. The interpretation of the
QA plots is as follows:

Theb phzm class count reflects both latitudinal span and region size,
but the orientation of the macrozone seems to be the stronger driver,
although the graph is of the centroid of the latitude.:

\_ The southern Mixed Grass Prairie (round) has very few PHZM classes.
The class count increases in a northerly direction. However, this is
because the zones become increasingly oriented in an elongated NS
direction (Tallgrass), and class count jumps. Area effect is layered in:
Tallgrass Prairie has both high NS orientation, a huge area, and the
highest class count (20).

------------------------------------------------------------------------

### 03h_covar_make_NLCD_meta

See docs/metadata/look_up_tables/nlcd_metadata_lut.csv”) Changed
classification to add Rangeland which combines Grassland, Hay/Pasture,
and Shrubland. A substantial fraction of the Southern Mixed-grass
Prairie is Shrubland.

------------------------------------------------------------------------

### 03h_covar_macro_NLCD_meta.R

Split from 03i_covar_macro_landcover_summary to try to fix an issue with
summary creating non_legend NLCD class codes. Found issue was in the way
the raw raster was reprojected in
R/01_download/01m_download_nlcd_2016.R. The refactored code in this
script only makes a LUT.

Merged NLCD Shrub/Scrub (52) with Grassland/Herbaceous (71) and
Pasture/Hay (81)) into a single Rangeland bucket. Hydrologically they
behave more alike than with Forest or Crops, and it avoids a potential
sparse class (Shrubland) which shows up in the southern shortgrass
steppe.

------------------------------------------------------------------------

### 03i_covar_macro_NLCD_summary.R

Land cover proportion summaries include the fraction of cropland,
forest, rangeland, and urban land. Fraction of cropland indicates
anthropogenic land use in agricultural regions associated with increased
runoff, reduced infiltration, and higher ET demand. The fraction of
forested land (cover) enhances interception and storage, which typically
reduces peak flows and lowers skew. The fraction of rangeland moderates
evapotranspiration and infiltration rates, which is especially important
in mixed rangeland systems. The fraction of urban land indicates
increased imperviousness, which is strongly associated with peak flow
generation and positive flood skew.

### NLCD Classes

**Developed**

21 *Developed, Open Space* – areas with a mixture of some constructed
materials, but mostly vegetation in the form of lawn grasses. Impervious
surfaces account for less than 20% of total cover. These areas most
commonly include large-lot single-family housing units, parks, golf
courses, and vegetation planted in developed settings for recreation,
erosion control, or aesthetic purposes.

22 *Developed, Low Intensity* – areas with a mixture of constructed
materials and vegetation. Impervious surfaces account for 20% to 49%
percent of total cover. These areas most commonly include single-family
housing units.

23 *Developed, Medium Intensity* – areas with a mixture of constructed
materials and vegetation. Impervious surfaces account for 50% to 79% of
the total cover. These areas most commonly include single-family housing
units.

24 *Developed High Intensity* – highly developed areas where people
reside or work in high numbers. Examples include apartment complexes,
row houses and commercial/industrial. Impervious surfaces account for
80% to 100% of the total cover.

**Forest**

41 *Deciduous Forest* – areas dominated by trees generally greater than
5 meters tall, and greater than 20% of total vegetation cover. More than
75% of the tree species shed foliage simultaneously in response to
seasonal change.

42 *Evergreen Forest* – areas dominated by trees generally greater than
5 meters tall, and greater than 20% of total vegetation cover. More than
75% of the tree species maintain their leaves all year. Canopy is never
without green foliage.

43 *Mixed Forest* – areas dominated by trees generally greater than 5
meters tall, and greater than 20% of total vegetation cover. Neither
deciduous nor evergreen species are greater than 75% of total tree
cover.

**Grassland**

52 *Shrub/Scrub*- areas dominated by shrubs; less than 5 meters tall
with shrub canopy typically greater than 20% of total vegetation. This
class includes true shrubs, young trees in an early successional stage
or trees stunted from environmental conditions.

71 *Grassland/Herbaceous*- areas dominated by gramanoid or herbaceous
vegetation, generally greater than 80% of total vegetation. These areas
are not subject to intensive management such as tilling, but can be
utilized for grazing.

81 *Pasture/Hay* – areas of grasses, legumes, or grass-legume mixtures
planted for livestock grazing or the production of seed or hay crops,
typically on a perennial cycle. Pasture/hay vegetation accounts for
greater than 20% of total vegetation.

**Planted/Cultivated**

82 *Cultivated Crops* — areas used for the production of annual crops,
such as corn, soybeans, vegetables, tobacco, and cotton, and also
perennial woody crops such as orchards and vineyards. Crop vegetation
accounts for greater than 20% of total vegetation. This class also
includes all land being actively tilled.

------------------------------------------------------------------------

### 03j_covar_NED_summary.R

Fixed many upstream issues prior to getting the script to output
reasonable results.

| Step | Check |
|:--:|:--:|
| Download & Merge | All tiles successfully mosaicked |
| Projection | Reprojected to EPSG:5070 (NAD83 / CONUS Albers) |
| Extent | Clipped cleanly to updated Great Plains outline (no ocean overlap) |
| Slope Calculation | Derived with terra::terrain() and verified quantiles (0–83.6 deg.) |
| Histogram Audit | Distribution centered around ~1–5 deg., plausible for Great Plains |
| Outlier Handling | −133 m min elevation eliminated (buffer error fixed) |
| Compression/Export | Use writeRaster(…, gdal = c(“TILED=YES”,“COMPRESS=LZW”,“BIGTIFF=YES”)) |

------------------------------------------------------------------------

### 03p_covar_lev3_prism_seas_sd_iqr.R

There are several methods to calculate IQR. The script uses type 7,
which is the default method in R.

m = 1-p. p\[k\] = (k - 1) / (n - 1). In this case, p\[k\] =
mode\[F(x\[k\])\].

------------------------------------------------------------------------

# CHECK INTO DAGS for looking into covars.

Topography summaries include mean and median slope and mean altitude.
Mean slope describes average terrain steepness, which helps distinguish
rugged uplands from flatter plains. Median slope is another measure of
average slope, which is more robust to outliers than the mean, and is
useful for evaluating runoff tendency. Mean altitude describes the
elevation regime, which influences climate, snow duration, and runoff
seasonality.

## Zettelkasten-style markdown

Zettelkasten-style markdown refers to using Markdown files to implement
a digital version of the Zettelkasten method—a powerful personal
knowledge management system developed by German sociologist Niklas
Luhmann.

Zettelkasten means “slip box” in German. It’s a system where you:

- Break ideas into atomic notes (each note = one concept or insight)
- Use unique IDs and bi-directional links to connect notes
- Emphasize networked thinking rather than hierarchical folders

In R or code-based workflows, Zettelkasten-style Markdown means using
plain text .md files where each file is a single, focused idea, tagged
and cross-linked like a mini personal wiki.

### Example Folder Structure

``` text
notes/
├── 20250728_gam-vs-ridge.md
├── 20250727_skewness-viz-notes.md
├── 20250721_prism-uncertainty.md
├── index.md  # optional index or dashboard
```

Each note might contain:

``` text
# GAM vs Ridge Regression for Skew Modeling

- Ridge performed best on full covariate set (low MSE)
- GAMs improved interpretability in non-linear effects (e.g. tmean_ann_C)
- TODO: test GAM + macrozone as random effect

Linked notes:
- [[20250721_prism-uncertainty]]
- [[20250727_skewness-viz-notes]]
```

### Core Features of Zettelkasten Markdown Notes

| Feature               | Benefit for Researchers            |
|-----------------------|------------------------------------|
| ✍️ Atomic Notes       | Each `.md` = 1 idea = easier reuse |
| 🔗 Links (`[[...]]`)  | Creates networked ideas, not silos |
| 🗓️ Timestamps / IDs   | Keeps notes organized and unique   |
| 🧠 Emergent Structure | You discover themes organically    |
| 🧾 Markdown Format    | Easy to version, edit, and render  |

### How It Might Help

For your hydrologic and regional skew work, this approach could help:

- Track decisions or insights across milestones
- Store modeling rationale (e.g., why you dropped ecoregions)
- Connect field notes, exploratory thoughts, and literature summaries
- Gradually build a knowledge graph of ideas and results

ChatGPT can generate a Zettelkasten-style notes/ folder with a few seed
notes and a script to open/edit them easily using RStudio.

------------------------------------------------------------------------

## Notes

- Last updated: 2025-10-22 07:59
- Maintained by: CJ Tinant
