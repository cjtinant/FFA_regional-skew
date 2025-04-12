# Overview

This project supports the development of regional skew estimation for
flood frequency analysis using USGS NWIS data. The workflow automates
data download, cleaning, and preparation of stream gage records with ≥20
years of unregulated peak flow data.

------------------------------------------------------------------------

# Folder Structure

FA\_regional-skew/ ├── data/ \# Raw & processed data outputs │ ├──
spatial/ \# Spatial shapefiles + related data │ ├── raw/ \# Raw pulled
data (NWIS, WQP, etc) │ ├── clean/ \# Clean/filtered outputs ready for
analysis │ └── meta/ \# Metadata, reference tables, lookup codes │ ├──
scripts/ \# Main project scripts │ ├── 01\_get-spatial-data.R │ ├──
02\_get-gage-data.R │ ├── 03\_filter\_unregulated\_gage\_data.R │ └──
04\_find\_clean\_export\_site\_summaries.R │ ├── functions/ \# Custom
reusable R functions │ └── f\_process\_geometries.R │ ├── output/ \#
Maps, figures, tables for reporting │ ├── docs/ \# README files, project
documentation │ ├── .gitignore ├── README.md ├── README.Rmd \# R
Markdown file to generate project documentation └──
FFA\_regional-skew.Rproj \# RStudio project file

------------------------------------------------------------------------

# Workflow Summary

<table>
<colgroup>
<col style="width: 16%" />
<col style="width: 21%" />
<col style="width: 24%" />
<col style="width: 37%" />
</colgroup>
<thead>
<tr class="header">
<th>Step</th>
<th>Script</th>
<th>Purpose</th>
<th>Key Outputs</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>01</td>
<td>01_get-spatial-data.R</td>
<td>Download and clean spatial data (HUCs, ecoregions, state
boundaries)</td>
<td>data/spatial/</td>
</tr>
<tr class="even">
<td>02</td>
<td>02_get-gage-data.R</td>
<td>Download peak flow records for USGS gages in study area</td>
<td>data/raw/sites_all_peak_in_bb.csv,
data/raw/data_all_peak_in_bb.csv</td>
</tr>
<tr class="odd">
<td>03</td>
<td>03_filter_unregulated_gage_data.R</td>
<td>Filter to unregulated sites with ≥20 years of peak flow record</td>
<td>data/clean/data_pk_unreg_gt_20.csv, sites_pk_gt_20.csv,
sites_reg_or_lt_20.csv</td>
</tr>
<tr class="even">
<td>04</td>
<td>04_find_clean_export_site_summaries.R</td>
<td>Query NWIS &amp; WQP for site metadata, clean and export</td>
<td>data/clean/site_summary_NWIS_clean.csv,
site_summary_WDP_clean.csv</td>
</tr>
<tr class="odd">
<td>05</td>
<td>05_update_problem_sites.R</td>
<td>Remove sites with all missing/zero peak_va or &lt;20 usable
records</td>
<td>Updated site lists and problem site tracking</td>
</tr>
<tr class="even">
<td>06</td>
<td>06_calculate_station_skew.R</td>
<td>Calculate station skew (log-Pearson III) for each gage</td>
<td>data/clean/station_skew.csv</td>
</tr>
</tbody>
</table>

------------------------------------------------------------------------

# Data Notes

-   `/data/raw/` — Raw API downloads (unaltered)
-   `/data/clean/` — Final cleaned datasets for analysis
-   `/data/spatial/` — GIS boundaries, shapefiles, geospatial data
-   All scripts numbered to reflect workflow sequence
-   Custom functions modularized in `/functions/`

# Workflow Steps

## 01\_get-spatial-data.R

Download and prepare spatial data: - USGS HUC boundaries - Ecoregions -
State boundaries

Outputs: - `data/spatial/*`

------------------------------------------------------------------------

## 02\_get-gage-data.R

Download USGS peak flow data from NWIS: - All sites within bounding
box - All annual peak flow records

Outputs: - `data/raw/sites_all_peak_in_bb.csv` -
`data/raw/data_all_peak_in_bb.csv`

------------------------------------------------------------------------

## 03\_filter\_unregulated\_gage\_data.R

Filter peak flow data to: - Remove regulated/affected observations -
Keep unregulated sites only - Retain sites with ≥20 years of record

Outputs: - `data/clean/data_pk_unreg_gt_20.csv` -
`data/clean/sites_pk_gt_20.csv` - `data/clean/sites_reg_or_lt_20.csv`

------------------------------------------------------------------------

## 04\_find\_clean\_export\_site\_summaries.R

Query site metadata from: - NWIS (location, drainage area) - WQP (data
availability)

Outputs: - `data/clean/site_summary_NWIS_clean.csv` -
`data/clean/site_summary_WDP_clean.csv`

------------------------------------------------------------------------

## 05\_update\_problem\_sites.R

Identify and remove sites with: - All missing or all zero peak values -
Fewer than 20 usable observations

Update site lists and site summary data.

Outputs: - Updated `data/clean/*.csv` files - Problem site info: -
`data/clean/problem_sites_skew.csv` -
`data/clean/data_problem_sites_skew.csv`

------------------------------------------------------------------------

## 06\_calculate\_station\_skew.R

Calculate log-Pearson III station skew for each site: - Requires ≥20
usable peak flows - Excludes sites with all NA or all zero values -
Includes site coordinates in output - Provides summary stats and
visualization

Outputs: - `data/clean/station_skew.csv`

------------------------------------------------------------------------

# Next Steps

-   Calculate station skew
-   Explore spatial patterns in station skew
-   Fit potential explanatory variables to station skew

------------------------------------------------------------------------

# Dependencies

\`\`\`r library(tidyverse) library(dataRetrieval) library(here)
library(glue)
