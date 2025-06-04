Covariate Source Inventory
================
Charles Tinant
2025-06-04

- [Spatial Data Preparation
  Checklist](#spatial-data-preparation-checklist)
- [Covariate Source Inventory](#covariate-source-inventory)

## Spatial Data Preparation Checklist

The checklist explains covariate sources and tracks other data

## Covariate Source Inventory

Tables below list datasets used in the regional skew estimation project.
All datasets are publicly available, spatially referenced, and selected
for their hydrologic relevance.

Additional covariate information is located in the [Skew Covariates
Metadata
Schema](data/meta/covariates_metadata_split/covariates_covariate_metadata_schema.csv).

### Table 1: Data sources, Formats, and Resolution

| Dataset Name | Description URL | Orig Format | Resolution | Version / Year | CRS |
|:--:|:--:|:--:|:--:|:--:|:--:|
| Ecoregions | [EPA Ecoregions](https://www.epa.gov/eco-research) | `.shp` | 1:250k | 2010 | NA |
| NHDPlusV21 | [NHDPlusV2](https://nhdplus.com/NHDPlus/) | `.gdb` | 1:100k | NA | NA |
| NHDPlusHD | [NHDPlusHD](https://www.usgs.gov/national-hydrography/nhdplus-high-resolution) | `.gdb` | 1:24k | NA | NA |
| Koppen Geiger | [gloh2o](https://www.gloh2o.org/koppen/) | `.tif` | 36 arcsec | 1991-2020 | NA |
| Plant Hardiness Zone | [PHZM](https://prism.oregonstate.edu/projects/plant_hardiness_zones.php) | `.bil` | 30 arcsec | 1991-2020 | NA |
| NLCD Land Cover | [Multi-Resolution Land Characteristics (MRLC)](https://www.mrlc.gov/) | NA | NA | 2016 | NA |
| NED Elevation | [National Map](https://apps.nationalmap.gov/) | NA | NA | NA | NA |
| PRISM Normals | [PRISM normals](https://prism.oregonstate.edu/normals/) | `.bil` | 30 arcsec | 1991-2020 | NA |
| MODIS | [Land Processes Distributed Active Archive Center (LP DAAC)](https://lpdaac.usgs.gov/) | NA | 2016 | NA | NA |
| STATSGO2 | [STATSGO2 Dataset](https://water.usgs.gov/catalog/datasets/c33ccf12-aede-4c2f-9a46-147cbf0e2ab8/) | NA | 2016 | 1:250k | NA |

### Table 1: Folder Names and Status

|     Dataset Name     |     Folder Name     | Status Code | Last Update | Notes |
|:--------------------:|:-------------------:|:-----------:|:-----------:|:-----:|
|    EPA Ecoregions    |   epa_ecoregions    |     05      |  20250512   |  NA   |
|   USGS NHDPlusV2.1   |         NA          |     00      |     NA      |  NA   |
|    USGS NHDPlusHD    |         NA          |     00      |     NA      |  NA   |
|    Koppen Geiger     |   koppen_climate    |     02      |  20250513   |  NA   |
| Plant Hardiness Zone |        phzm         |     05      |  20250514   |  NA   |
|   NLCD Land Cover    | nlcd_landcover_2016 |     00      |     NA      |  NA   |
|    NED Elevation     |      ned_elev       |     00      |     NA      |  NA   |
|    PRISM Normals     |        prism        |     05      |  20250513   |  NA   |
|        MODIS         |     modis_2016      |     00      |     NA      |  NA   |
|       STATSGO2       |      statsgo2       |     00      |     NA      |  NA   |
|    USGS Stations     |         NA          |     04      |     NA      |  NA   |

### Table 3: Common Status Levels for Data Workflow

| Status Code | Label | Description |
|:--:|:--:|:--:|
| 00 | ❌ Not Started | Task has not been initiated. |
| 01 | ⬇️ Queued for Download | Identified for download; pending execution. |
| 02 | ⬇️ Downloaded | Data successfully downloaded. No prep has started yet. |
| 03 | 🔍 Verified Raw Files | File format, integrity, and metadata validated. |
| 04 | 🧹 Cleaned / Filtered | Unwanted data removed; NA handling, format consistency applied. |
| 05 | 📐 Reprojected | Spatial data reprojected to standard CRS (e. |
| 06 | 🧮 Feature Extraction | Covariates or metrics calculated (e.g., slope, mean temp). |
| 07 | 🧱 Joined to Site Data | Covariates or values joined with site records (e.g., gage locations). |
| 08 | 🧾 Metadata Documented | Dataset and processing steps documented in metadata or data dictionary. |
| 09 | 📦 Finalized & Versioned | Clean, final dataset stored in data/processed/; versioned if needed. |
| 10 | 📊 Used in Modeling | Dataset actively used in modeling or downstream analysis. |

### In-Progress Modifiers

| Modifier |    Status Indicator    |
|:--------:|:----------------------:|
|    \*    |     partially done     |
|    ~     |      needs review      |
|    !     | blocker or known issue |
|    ✓     |    fully validated     |

- **Note:** Control + Command + Spacebar opens the Emoji & Symbols
  viewer
