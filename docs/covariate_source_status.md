Covariate Source Inventory
================
CJ Tinant
2025-07-22 07:09:49

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

Commission for Environmental Cooperation (Montréal, Q. and Secretariat,
1997. Ecological Regions of North America: Toward a Common Perspective.
The Commission.

Daly, C., 2013. Descriptions of PRISM Spatial Climate Datasets for the
Conterminous United States. PRISM Doc 14.

Daly, C., M. Halbleib, J.I. Smith, W.P. Gibson, M.K. Doggett, G.H.
Taylor, J. Curtis, and P.P. Pasteris, 2008. Physiographically Sensitive
Mapping of Climatological Temperature and Precipitation across the
Conterminous United States. International Journal of Climatology
28:2031–2064.

Daly, C., G.H. Taylor, and W.P. Gibson, 1997. The PRISM Approach to
Mapping Precipitation and Temperature. Proc., 10th AMS Conf. on Applied
Climatology., pp. 20–23.

Daly, C., M.P. Widrlechner, M.D. Halbleib, J.I. Smith, and W.P. Gibson,
2012. Development of a New USDA Plant Hardiness Zone Map for the United
States. Journal of Applied Meteorology and Climatology 51:242–264.

Davis, W. and T. Simon, 1995. Biological Assessment and Criteria: Tools
for Water Resource Planning and Decision Making.
<doi:10.13140/RG.2.1.4916.2726>.

Dewald, T., 2017. Making the Digital Water Flow: The Evolution of
Geospatial Surface Water Frameworks. USEPA Office of Water: Washington,
DC, USA.

Dewald, T., L. McKay, L. Bondelid, J. Johnston, R. Moore, and A. Rea,
2019. User’s Guide for the National Hydrography Plus (NHDPlus) Version
2. US EPA, 182 Pp. US Environmental Protection Agency (EPA).

Didan, K. and A.B. Munoz, MODIS Vegetation Index User’s Guide (MOD13
Series).

Ecoregions of North America, Ecoregions of North America.
<https://www.epa.gov/eco-research/ecoregions-north-america>.

England Jr, J.F., T.A. Cohn, B.A. Faber, J.R. Stedinger, W.O. Thomas Jr,
A.G. Veilleux, J.E. Kiang, and R.R. Mason Jr, 2019. Guidelines for
Determining Flood Flow Frequency—Bulletin 17c. US Geological Survey.

Gesch, D.B., G.A. Evans, M.J. Oimoen, and S. Arundel, 2018. The National
Elevation Dataset. , pp. 83–110.

Jin, S., C. Homer, L. Yang, P. Danielson, J. Dewitz, C. Li, Z. Zhu, G.
Xian, and D. Howard, 2019. Overall Methodology Design for the United
States National Land Cover Database 2016 Products. Remote Sensing
11:2971.

McMahon, G., S.M. Gregonis, S.W. Waltman, J.M. Omernik, T.D. Thorson,
J.A. Freeouf, A.H. Rorick, and J.E. Keys, 2001. Developing a Spatial
Framework of Common Ecological Regions for the Conterminous United
States. Environmental Management 28:293–316.

Moore, R.B., L.D. McKay, A.H. Rea, T.R. Bondelid, C.V. Price, T.G.
Dewald, and C.M. Johnston, 2019. User’s Guide for the National
Hydrography Dataset Plus (NHDPlus) High Resolution. US Geological
Survey.

NHD Data Dictionary Quick Start Version 2.0, US Geological Survey.
Omernik, J.M., 1987. Ecoregions of the Conterminous United States.
Annals of the Association of American Geographers 77:118–125.

Omernik, J.A., 1993. Ecoregions: A Spatial Framework for Environmental
Management. Book Chapter. Environmental Protection Agency, Corvallis, OR
(United States).

Omernik, J.M., 2004. Perspectives on the Nature and Definition of
Ecological Regions. Environmental Management 34 Suppl 1:S27-38.

Omernik, J.M. and G.E. Griffith, 2014. Ecoregions of the Conterminous
United States: Evolution of a Hierarchical Spatial Framework.
Environmental Management 54:1249–1266.

Primary Distinguishing Characteristics of Level III Ecoregions of the
Continental United States., 2002. US Environmental Protection Agency
(EPA).

Rose, K.C., R.A. Graves, W.D. Hansen, B.J. Harvey, J. Qiu, S.A. Wood, C.
Ziter, and M.G. Turner, 2017. Historical Foundations and Future
Directions in Macrosystems Ecology. Ecology Letters 20:147–157.

Tim Cohn, Bulletin 17B Restudy and Future Updates.

Water Resources Council (U S. ) Hydrology Committee, 1975. Guidelines
for Determining Flood Flow Frequency. U.S. Water Resources Council,
Hydrology Committee.

Wiken, E.D., F.J. Nava, and G. Griffith, 2011. North American
Terrestrial Ecoregions—Level III. Commission for Environmental
Cooperation, Montreal, Canada 149.
