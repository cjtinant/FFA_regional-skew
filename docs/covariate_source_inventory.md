Covariate Source Inventory
================
CJ Tinant
2025-07-21 14:20:25

- [Overview](#overview)
  - [Table 1: Folder Names and Status](#table-1-folder-names-and-status)
- [References](#references)

## Overview

This document summarizes the status of covariate datasets used in the
regional skew estimation project and references. All datasets are
publicly available, spatially referenced, and selected for their
hydrologic relevance. Data sources are listed in individual scripts in
`R/01_download/`. Metadata for the datasets are provided in
`docs/metadata/`. Detailed descriptions of the units, analytical
resolution, scale, domain, and concept group are provided in
`docs/metadata/descriptions/covariate_metadata.csv` and
`data_dictionary_covariates.pdf`

### Table 1: Folder Names and Status

Status codes track the current stage of preparation for each dataset
listed above. Values range from “00 — Not Started” to “10 — Used in
Modeling”. Data are stored in `data/processed/`. Status codes are
described in `best-practices_reference.md`

|     Dataset Name     |  Folder Name   | Status Code | Notes |
|:--------------------:|:--------------:|:-----------:|:-----:|
|    EPA Ecoregions    | us-ecoregions  |     06      |  NA   |
|    Koppen Geiger     | koppen-climate |     06      |  NA   |
|   MODIS 2016 NVDI    |     modis      |     06      |  NA   |
|         NED          |      ned       |     06      |  NA   |
|     NHDPlusV2.1      |  nhdplus_v21   |     06      |  NA   |
|      NHDPlusHD       |     nhdphd     |     06      |  NA   |
| NLCD 2016 Land Cover |      nlcd      |     06      |  NA   |
| Plant Hardiness Zone |      phzm      |     06      |  NA   |
|   PRISM annual pct   |     prism      |     06      |  NA   |
|  PRISM annual temp   |     prism      |     06      |  NA   |
|   PRISM daily pct    |     prism      |     06      |  NA   |
|   PRISM daily temp   |     prism      |     06      |  NA   |
|  PRISM monthly pct   |     prism      |     06      |  NA   |
|       STATSGO2       |    statsgo2    |     06      |  NA   |
|  USGS Station Data   | peakflow_gages |     06      |  NA   |

------------------------------------------------------------------------

# References

Bailey, R.G., 1976a. Ecoregions of North America - Level I (Map).

Bailey, R.G., 1976b. Ecoregions of North America - Level II (Map).

Bailey, R.G., 1976c. Ecoregions of the United States - Level III (Map).

Bailey, R.G., 1976d. Ecoregions of the United States - Level IV (Map).

Beck, H.E., T.R. McVicar, N. Vergopolan, A. Berg, N.J. Lutsko, A.
Dufour, Z. Zeng, X. Jiang, A.I.J.M. Van Dijk, and D.G. Miralles, 2023.
High-Resolution (1 Km) Köppen-Geiger Maps for 1901–2099 Based on
Constrained CMIP6 Projections. Scientific Data 10:724.

Beck, H.E., N.E. Zimmermann, T.R. McVicar, N. Vergopolan, A. Berg, and
E.F. Wood, 2018. Present and Future Köppen-Geiger Climate Classification
Maps at 1-Km Resolution. Scientific Data 5:180214.

BLM-2023-0001-154043_attachment_5, Ecoregions of North America.

Daly, C., M. Halbleib, J.I. Smith, W.P. Gibson, M.K. Doggett, G.H.
Taylor, J. Curtis, and P.P. Pasteris, 2008. Physiographically Sensitive
Mapping of Climatological Temperature and Precipitation across the
Conterminous United States. International Journal of Climatology
28:2031–2064.

Davis, W. and T. Simon, 1995. Biological Assessment and Criteria: Tools
for Water Resource Planning and Decision Making.
<doi:10.13140/RG.2.1.4916.2726>. Ecological Regions of North America:
Toward a Common Perspective, 1997. The Commission, Montréal, Québec.

McMahon, G., S.M. Gregonis, S.W. Waltman, J.M. Omernik, T.D. Thorson,
J.A. Freeouf, A.H. Rorick, and J.E. Keys, 2001. Developing a Spatial
Framework of Common Ecological Regions for the Conterminous United
States. Environmental Management 28:293–316.

Omernik, J.M., 1987. Ecoregions of the Conterminous United States.
Annals of the Association of American Geographers 77:118–125.

Omernik, J.M., 2004. Perspectives on the Nature and Definition of
Ecological Regions. Environmental Management 34 Suppl 1:S27-38.

Omernik, J.M. and G.E. Griffith, 2014. Ecoregions of the Conterminous
United States: Evolution of a Hierarchical Spatial Framework.
Environmental Management 54:1249–1266.

Rose, K.C., R.A. Graves, W.D. Hansen, B.J. Harvey, J. Qiu, S.A. Wood, C.
Ziter, and M.G. Turner, 2017. Historical Foundations and Future
Directions in Macrosystems Ecology. Ecology Letters 20:147–157.

Water Resources Council (U S. ) Hydrology Committee, 1975. Guidelines
for Determining Flood Flow Frequency. U.S. Water Resources Council,
Hydrology Committee.

<https://catalog.data.gov/dataset/results-of-peak-flow-frequency-analysis-and-regionalization-for-selected-streamgages-in-or>
