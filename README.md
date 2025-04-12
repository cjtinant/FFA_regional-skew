## Overview

This project supports the development of regional skew estimation for
flood frequency analysis. The workflow automates data download,
cleaning, and organization of USGS NWIS and WQP data for unregulated
stream gages with sufficient record length.

## Project Structure

    FFA_regional-skew/
    ├── data/
    │   ├── raw/           # Original input data from USGS/NWIS/WQP
    │   ├── clean/         # Cleaned and processed data ready for analysis
    ├── functions/         # Custom R functions used across scripts
    ├── scripts/           # R scripts for data processing workflows
    ├── README.Rmd         # R Markdown file to generate project documentation
    ├── README.md          # Auto-generated Markdown documentation

## Workflow Overview

<table>
<colgroup>
<col style="width: 39%" />
<col style="width: 28%" />
<col style="width: 32%" />
</colgroup>
<thead>
<tr class="header">
<th>Milestone</th>
<th>Script</th>
<th>Purpose</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>01</td>
<td>01_get-spatial-data.R</td>
<td>Download and clean HUC, ecoregion, and gage spatial data.</td>
</tr>
<tr class="even">
<td>02</td>
<td>02_get-gage-data.R</td>
<td>Query peak flow records for all USGS sites in bounding box.</td>
</tr>
<tr class="odd">
<td>03</td>
<td>03_filter_unregulated_gage_data.R</td>
<td>Filter gages to unregulated sites with ≥20 years of data.</td>
</tr>
<tr class="even">
<td>04</td>
<td>04_find_clean_export_site_summaries.R</td>
<td>Query NWIS and WQP for site metadata, clean, and export site
summaries.</td>
</tr>
</tbody>
</table>

## Data Notes

-   `/data/raw/` contains raw unprocessed data pulled directly from
    APIs.
-   `/data/clean/` contains final processed data used in analysis.
-   All scripts are named and numbered to reflect the workflow order.
-   Custom helper functions are in `/functions/`.
