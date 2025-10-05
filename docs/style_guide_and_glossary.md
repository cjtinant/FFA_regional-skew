Project Style Guide and Glossary
================
C.J. Tinant
October 05, 2025

- [📖 Style Guide](#open_book-style-guide)
  - [Purpose](#purpose)
  - [Terminology and Naming
    Conventions](#terminology-and-naming-conventions)
  - [Variable Naming](#variable-naming)
  - [Writing Style](#writing-style)
  - [Citation Style](#citation-style)
- [Glossary](#glossary)
  - [Coordinate Reference System (CRS)
    Codes](#coordinate-reference-system-crs-codes)
  - [An Explaination of ID-term in Spatial Data
    Workflows](#an-explaination-of-id-term-in-spatial-data-workflows)

# 📖 Style Guide

## Purpose

This document defines naming, formatting, and style conventions for
reports, scripts, metadata, and documentation used in the project.
Additionally, the document acts as a dictionary of project-specific
vocabulary.

## Terminology and Naming Conventions

### Macrozone Names

|  Macrozone   | Preferred Term      | Notes                                 |
|:------------:|---------------------|---------------------------------------|
| `tallgrass`  | Tallgrass Prairie   | No hyphen; conventional in literature |
|   `mixed`    | Mixed-Grass Prairie | Hyphenated compound modifier          |
| `shortgrass` | Shortgrass-Steppe   | Hyphenated; “Prairie” is redundant    |

Use hyphenated forms when modifying a noun (e.g., “Shortgrass-Steppe
region”), and unhyphenated when used as a noun (e.g., “We sampled the
Shortgrass Steppe”).

## Variable Naming

### General Use Cases

- Use snake_case for all variable names (e.g., `ppt_ann_mm`,
  `slope_pct`)
- Place `site_no`, `latitude`, and `longitude` as the first columns in
  exported datasets
- Use standard units in suffixes (`_mm`, `_C`, `_pct`, `_km2`)

### Specific Use Cases for Spatial Data Workflows

The project strives to use explicitly named, project-specific ID fields,
which are treated as a UID. One qc check on asserting UID status prior
to a join is by using the `assert_inputs_ok()` helper function. The
reason UIDs are important is to ensure one to one cardinality in joining
or merging datasets.

- **site_no** — USGS gage ID (UID, not regenerated).
- **macro_id** — persistent UID for macrozones (sequential, unique).
- **catch_id** — NHDPlus catchment UID.

## Writing Style

- Use full phrases before acronyms on first use (e.g., “Normalized
  Difference Vegetation Index (NDVI)”).
- Follow USGS and EPA naming conventions when describing datasets,
  flowlines, and catchments.
- Avoid unnecessary repetition, in other words tautologies. For example,
  avoid writing “Shortgrass-Steppe Prairie”.

## Citation Style

- Internal datasets: reference relative path in `docs/metadata/`.
- External datasets: provide DOI or citation in README/data dictionary.

------------------------------------------------------------------------

# Glossary

## Coordinate Reference System (CRS) Codes

CRS (Coordinate Reference System) refers to the general concept of a map
coordinate system. A CRS includes: datums, projections, units,
transformations, and other geodetic parameters.

- A datum is an earth model, ellipsoid or spheroid, and the origin point
  for the system
- The map projection describes how the curved Earth is flattened onto
  2D.

EPSG codes are unique numeric identifiers for specific CRS, in other
words,EPSG is a registry and naming system for CRS. EPSG codes are
standardized, unique integer numbers (e.g., EPSG:4326) used to identify
a specific CRS definition. The acronym comes from the EPSG Geodetic
Parameter Dataset, which was originally compiled by the European
Petroleum Survey Group (now defunct) and now maintained by the
International Association of Oil & Gas Producers (IOGP). EPSG codes
provide a consistent way to refer to and specify different CRS and
transformations. Some EPSG codes used in the project include:

- EPSG:4269 – NAD83 / unprojected (GRS 1980 elipsoid) in lat lon.
- EPSG:4326 – WGS84 / unprojected (WGS 1984 elipsoid) in lat lon.
  EPSG:4326 is used by the National Elevation Dataset (NED).
- EPSG:5070 – NAD83 / Conus Albers (GRS 1980 elipsoid) in meters.
  **EPSG:5070 is the project standard EPSG code.**

## An Explaination of ID-term in Spatial Data Workflows

- **ID (Identifier)** is the *generic term* for a field that uniquely
  (or semi-uniquely) identifies records, and often consists of
  sequential integers assigned on export. While it is commonly used in
  shapefiles/GeoPackages (ID, id, FID), it *may not be stable across
  exports or joins*.

- **UID (Unique Identifier)** is a term that explicitly means
  *guaranteed unique* within the dataset. A UID provides a stronger
  guarantee than plain ID, meaning no duplicates and no recycling. A UID
  is often in a UUID/GUID format (e.g.,
  550e8400-e29b-41d4-a716-446655440000) or carefully managed integer
  sequences. UID is *useful when performing merge/join across multiple
  datasets*, and when persistence across time and versions is needed

- **OID (Object ID)** is a term from ESRI geodatabases.and is an
  automatically maintained field (OBJECTID or OID). OID is internal to
  the geodatabase and ensures every feature has a unique row identifier.
  *OID is* **not** *stable upon re-export or recompute*, as Esri may
  regenerate an OID. Therefore, it should not be used as an analysis
  join key in persistent workflows.
