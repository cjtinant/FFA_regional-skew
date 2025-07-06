Covariate Source Inventory
================
CJ Tinant
2025-07-03 16:31:08

- [Overview](#overview)
- [Covariate Source Inventory](#covariate-source-inventory)
  - [Table 1: Common Status Levels for Data
    Workflow](#table-1-common-status-levels-for-data-workflow)
  - [Table 2: In-Progress Modifiers](#table-2-in-progress-modifiers)
  - [Table 3: Folder Names and Status](#table-3-folder-names-and-status)
  - [Table 4: Data sources, Formats, and
    Resolution](#table-4-data-sources-formats-and-resolution)
  - [Table 5: Download Scripts and Dataset
    Tracking](#table-5-download-scripts-and-dataset-tracking)
  - [Table 6: Metadata and Documentation
    Tracking](#table-6-metadata-and-documentation-tracking)
- [References](#references)
  - [🔗 Related Scripts and Metadata
    Files](#link-related-scripts-and-metadata-files)

## Overview

This document summarizes the status and sources of covariate datasets
used in the regional skew estimation project. It includes a status code
system, modifier definitions, and links to detailed metadata resources
used in modeling, QA/QC, and documentation workflows.

This report also integrates the current download script tracker
(generated from R/01_download/) to reflect implementation status by
dataset.

## Covariate Source Inventory

------------------------------------------------------------------------

### Table 1: Common Status Levels for Data Workflow

| Status Code | Label | Description |
|:--:|:--:|:--:|
| 00 | ❌ Not Started | Task has not been initiated. |
| 01 | ⬇️ Queued for Download | Identified for download; pending execution. |
| 02 | ⬇️ Downloaded | Data successfully downloaded. No prep has started yet. |
| 03 | 🔍 Verified Raw Files | File format, integrity, and metadata validated. |
| 04 | 🧹 Cleaned / Filtered | Unwanted data removed; NA handling, format consistency applied. |
| 05 | 📐 Reprojected | Spatial data reprojected to standard CRS (e.g., NAD83). |
| 06 | 🧮 Feature Extraction | Covariates or metrics calculated (e.g., slope, mean temp). |
| 07 | 🧱 Joined to Site Data | Covariates or values joined with site records (e.g., gage locations). |
| 08 | 🧾 Metadata Documented | Dataset and processing steps documented in metadata or data dictionary. |
| 09 | 📦 Finalized & Versioned | Clean, final dataset stored in data/processed/; versioned if needed. |
| 10 | 📊 Used in Modeling | Dataset actively used in modeling or downstream analysis. |

------------------------------------------------------------------------

### Table 2: In-Progress Modifiers

| Modifier |    Status Indicator    |
|:--------:|:----------------------:|
|    \*    |     partially done     |
|    ~     |      needs review      |
|    !     | blocker or known issue |
|    ✓     |    fully validated     |

- **Note:** Control + Command + Spacebar opens the Emoji & Symbols
  viewer

For detailed field descriptions and spatial resolution, see the [Skew
Covariates Metadata
Schema](../data/meta/covariates_metadata_split/covariates_covariate_metadata_schema.csv).

Tables below list datasets used in the regional skew estimation project.
All datasets are publicly available, spatially referenced, and selected
for their hydrologic relevance.

------------------------------------------------------------------------

### Table 3: Folder Names and Status

Status codes track the current stage of preparation for each dataset
listed above. Values range from “00 — Not Started” to “10 — Used in
Modeling”.

|     Dataset Name     |  Folder Name   | Status Code | Notes |
|:--------------------:|:--------------:|:-----------:|:-----:|
|    EPA Ecoregions    |   ecoregions   |     05      |  NA   |
|    USGS Stations     | peakflow_gages |     02      |  NA   |
|   USGS NHDPlusV2.1   |    nhdplus     |     02      |  NA   |
|    USGS NHDPlusHD    |    nhdplus     |     02      |  NA   |
|    Koppen Geiger     | koppen_climate |     02      |  NA   |
| Plant Hardiness Zone |      phzm      |     05      |  NA   |
|   NLCD Land Cover    |      nlcd      |     02      |  NA   |
|    NED Elevation     |    ned_elev    |     02      |  NA   |
|    PRISM Normals     |     prism      |     05      |  NA   |
|        MODIS         |   modis_2016   |     02      |  NA   |
|       STATSGO2       |    statsgo2    |     02      |  NA   |

------------------------------------------------------------------------

### Table 4: Data sources, Formats, and Resolution

| Dataset Name | Description URL | Orig Format | Resolution | Version / Year |
|:--:|:--:|:--:|:--:|:--:|
| Ecoregions | [EPA Ecoregions](https://www.epa.gov/eco-research) | `.shp` | 1:250k | 2010 |
| USGS Stations | NA | `.csv` | NA | NA |
| NHDPlusV21 | [NHDPlusV2](https://nhdplus.com/NHDPlus/) | `.gdb` | 1:100k | NA |
| NHDPlusHD | [NHDPlusHD](https://www.usgs.gov/national-hydrography/nhdplus-high-resolution) | `.gdb` | 1:24k | NA |
| Koppen Geiger | [gloh2o](https://www.gloh2o.org/koppen/) | `.tif` | 36 arcsec | 1991-2020 |
| Plant Hardiness Zone | [PHZM](https://prism.oregonstate.edu/projects/plant_hardiness_zones.php) | `.bil` | 30 arcsec | 1991-2020 |
| NLCD Land Cover | [Multi-Resolution Land Characteristics (MRLC)](https://www.mrlc.gov/) | NA | NA | 2016 |
| NED Elevation | [National Map](https://apps.nationalmap.gov/) | NA | NA | NA |
| PRISM Normals | [PRISM normals](https://prism.oregonstate.edu/normals/) | `.bil` | 30 arcsec | 1991-2020 |
| MODIS | [Land Processes Distributed Active Archive Center (LP DAAC)](https://lpdaac.usgs.gov/) | NA | 2016 | NA |
| STATSGO2 | [STATSGO2 Dataset](https://water.usgs.gov/catalog/datasets/c33ccf12-aede-4c2f-9a46-147cbf0e2ab8/) | NA | 2016 | 1:250k |

------------------------------------------------------------------------

### Table 5: Download Scripts and Dataset Tracking

The table below is auto-generated from the filenames in `R/01_download/`
and used to track dataset sources, download progress, and implementation
status.

| script | step_id | dataset | last_modified |
|:---|:---|:---|:---|
| 01a_download_us_ecoregions.R | 01a | Ecoregions | 2025-06-30 01:23:02 |
| 01b_download_gage-data.R | 01b | USGS Stations | 2025-06-30 01:34:09 |
| 01c_download_nhdplus_v21_flowlines.R | 01c | NHDPlusV21 | 2025-06-30 01:26:16 |
| 01d_download_nhdplus_hr_flowlines.R | 01d | NHDPlusHD | 2025-06-30 22:02:34 |
| 01e_download_nhdplus_hr_catchments.R | 01e | NHDPlusHD | 2025-06-30 22:02:31 |
| 01f_download_koppen-geiger_climate.R | 01f | Koppen Geiger | 2025-06-30 02:38:47 |
| 01g_download_plant-hardiness-zone-map.R | 01g | Plant Hardiness Zone | 2025-06-30 02:31:08 |
| 01h_download_prism_climate.R | 01h | PRISM Normals | 2025-06-30 02:42:18 |
| 01j_download_nlcd_2016.R | 01j | NLCD Land Cover | 2025-06-30 02:43:36 |
| 01k_download_ned.R | 01k | NED Elevation | 2025-06-30 02:48:26 |
| 01m_download_statsgo2.R | 01m | STATSGO2 | 2025-06-30 22:02:25 |
| 1l_download_modis_2016.R | 1l | MODIS | 2025-06-30 02:52:14 |

data/intermediate/download_script_tracker.csv

------------------------------------------------------------------------

### Table 6: Metadata and Documentation Tracking

The table below is auto-generated from the filenames in R/01_download/
and used to track dataset sources, download progress, and implementation
status.

|    Dataset    |                Metadata                | Documentation  |
|:-------------:|:--------------------------------------:|:--------------:|
|  Ecoregions   |    NA_CEC_Eco_Level1_attributes.csv    | See References |
|  Ecoregions   | NA_CEC_Eco_Level1_spatial_metadata.csv | See References |
|  Ecoregions   |    NA_CEC_Eco_Level2_attributes.csv    | See References |
|  Ecoregions   | NA_CEC_Eco_Level2_spatial_metadata.csv | See References |
|  Ecoregions   |    NA_CEC_Eco_Level3_attributes.csv    | See References |
|  Ecoregions   | NA_CEC_Eco_Level3_spatial_metadata.csv | See References |
|  Ecoregions   |     us_eco_l4_no_st_attributes.csv     | See References |
|  Ecoregions   |  us_eco_l4_no_st_spatial_metadata.csv  | See References |
| USGS Stations |              Circle Back               |                |

------------------------------------------------------------------------

# References

Bailey, R.G., 1976a. Ecoregions of North America - Level I (Map).
Bailey, R.G., 1976b. Ecoregions of North America - Level II (Map).
Bailey, R.G., 1976c. Ecoregions of the United States - Level III (Map).
Bailey, R.G., 1976d. Ecoregions of the United States - Level IV (Map).
Beck, H.E., T.R. McVicar, N. Vergopolan, A. Berg, N.J. Lutsko, A.
Dufour, Z. Zeng, X. Jiang, A.I.J.M. Van Dijk, and D.G. Miralles, 2023.
High-Resolution (1 Km) Köppen-Geiger Maps for 1901–2099 Based on
Constrained CMIP6 Projections. Scientific Data 10:724. Beck, H.E., N.E.
Zimmermann, T.R. McVicar, N. Vergopolan, A. Berg, and E.F. Wood, 2018.
Present and Future Köppen-Geiger Climate Classification Maps at 1-Km
Resolution. Scientific Data 5:180214. BLM-2023-0001-154043_attachment_5,
Ecoregions of North America. Daly, C., M. Halbleib, J.I. Smith, W.P.
Gibson, M.K. Doggett, G.H. Taylor, J. Curtis, and P.P. Pasteris, 2008.
Physiographically Sensitive Mapping of Climatological Temperature and
Precipitation across the Conterminous United States. International
Journal of Climatology 28:2031–2064. Davis, W. and T. Simon, 1995.
Biological Assessment and Criteria: Tools for Water Resource Planning
and Decision Making. <doi:10.13140/RG.2.1.4916.2726>. Ecological Regions
of North America: Toward a Common Perspective, 1997. The Commission,
Montréal, Québec. McMahon, G., S.M. Gregonis, S.W. Waltman, J.M.
Omernik, T.D. Thorson, J.A. Freeouf, A.H. Rorick, and J.E. Keys, 2001.
Developing a Spatial Framework of Common Ecological Regions for the
Conterminous United States. Environmental Management 28:293–316.
Omernik, J.M., 1987. Ecoregions of the Conterminous United States.
Annals of the Association of American Geographers 77:118–125. Omernik,
J.M., 2004. Perspectives on the Nature and Definition of Ecological
Regions. Environmental Management 34 Suppl 1:S27-38. Omernik, J.M. and
G.E. Griffith, 2014. Ecoregions of the Conterminous United States:
Evolution of a Hierarchical Spatial Framework. Environmental Management
54:1249–1266. Rose, K.C., R.A. Graves, W.D. Hansen, B.J. Harvey, J. Qiu,
S.A. Wood, C. Ziter, and M.G. Turner, 2017. Historical Foundations and
Future Directions in Macrosystems Ecology. Ecology Letters 20:147–157.
Water Resources Council (U S. ) Hydrology Committee, 1975. Guidelines
for Determining Flood Flow Frequency. U.S. Water Resources Council,
Hydrology Committee.

------------------------------------------------------------------------

## 🔗 Related Scripts and Metadata Files

- `01_download/` scripts for each dataset
- `data/meta/spatial_validation_summary.csv`
- `data/meta/covariates_metadata_split/`
