Documenting Changes in 02_clean_validate/README.Rmd
================
C.J. Tinant
July 28, 2025

- [Purpose](#purpose)
- [Overview](#overview)
- [Summary of Key Changes](#summary-of-key-changes)

## Purpose

Provide a human-readable summary of scripts in `R/02_clean_validate`,
including their purpose, input/output expectations, status, and key
changes over time. This supports reproducibility and onboarding of new
contributors.

## Overview

This section documents the current structure and status of scripts
responsible for processing files in `data/raw`. Each script is
version-controlled and tied to a specific covariate or source dataset.

## Summary of Key Changes

### Standardized Folder Paths

- Output paths outside of functions use
  `here::here("data", "processed")`

### Consistent CRS

- Spatial outputs reprojected to EPSG:5070 (CONUS Albers Equal Area)

### Modular Design

- Each script targets a single source or covariate
- Utility functions moved to `R/utils/`

### Logging & QA

- Retry attempts, download failures, and chunking behavior logged to
  `.csv` where applicable
- Scripts include `{cli}` alerts for status tracking

### Metadata Documentation

- Consistent headers at the top of each script.
- Script headers ready to be cross-linked to relevant milestone reports
