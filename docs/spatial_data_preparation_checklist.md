Spatial Data Preparation Checklist
================
Charles Tinant
2025-05-11

- [Spatial Data Preparation
  Checklist](#spatial-data-preparation-checklist)

## Spatial Data Preparation Checklist

This reusable checklist guides preprocessing of spatial covariates:

| Step | Task | Description | \[x\] |
|----|----|----|----|
| 1 | **Acquire** | Download data from trusted source (USGS, PRISM, EPA, etc.) | ☐ |
| 2 | **Inspect** | Check format, projection, geometry type, extent | ☐ |
| 3 | **Clean** | Remove empty, invalid, or duplicate geometries | ☐ |
| 4 | **Reproject** | Convert all data to a common CRS (e.g., NAD83 / UTM zone) | ☐ |
| 5 | **Clip / Mask** | Clip to study boundary or watershed extent (optional) | ☐ |
| 6 | **Filter** | Subset by attribute or spatial filter (e.g., perennial streams only) | ☐ |
| 7 | **Join Attributes** | Join tabular metadata to spatial features by ID | ☐ |
| 8 | **Spatial Join / Intersect** | Overlay/intersect with other layers (e.g., land cover, ecoregions) | ☐ |
| 9 | **Aggregate** | Summarize to analysis unit (e.g., mean elevation by watershed) | ☐ |
| 10 | **Validate** | Check geometries, missing values, outliers, CRS alignment | ☐ |
| 11 | **Export** | Save cleaned files with consistent naming, formats, and CRS | ☐ |
| 12 | **Document** | Record source, projection, processing steps, and variable notes | ☐ |
