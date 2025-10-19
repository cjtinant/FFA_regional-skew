README – FFA Regional Skew Estimation
================

- [Project Overview](#project-overview)

# Project Overview

Reproducible R workflow for estimating regional skew coefficients for
Flood Frequency Analysis (FFA) in the Great Plains using multi‑scale
climate, land cover, topography, and watershed covariates.

The project models station skew (Log‑Pearson Type III) for rare‑flood
estimation by integrating long‑term USGS peak‑flow records with
covariates summarized from station to macroregional scales. Implemented
in R, it processes ~1,700 unregulated Great Plains gages to support
robust regional‑skew estimation and clustering of hydrologically similar
sites.

Flood frequency analysis fits probability distributions to annual
peak‑discharge records; short records make extreme‑event metrics
unstable. Consistent with Bulletin 17C’s station‑plus‑regional skew
approach, this workflow uses spatial and climatic predictors—many from
PRISM, MODIS, NLCD, and NED—to stabilize estimates in data‑sparse
settings.

Aligned with Bulletin 17C, leveraging satellite‑derived and other
geospatial datasets, and applying modern small‑sample estimators
(regularization/shrinkage) with scripted QA/QC, the framework is
transparent, extensible, and purpose‑built for flood‑risk decision
support.

<!--
### Quick Start (how to run the workflow)
&#10;### Project Goals (1–2 sentence summary)
&#10;### Core Workflow Diagram or link to “docs/analysis_layout.md”
&#10;### Link to full documentation in docs/
-->
