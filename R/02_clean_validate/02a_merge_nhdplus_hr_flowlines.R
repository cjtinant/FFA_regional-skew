# ==============================================================================
# Script Name:    02a_merge_nhdplus_hr_flowlines.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-06-07
# Last Updated:   
#
# Purpose: Merge NHDPlus HR flowlines into a single GeoPackage
#
# Data URLs: https://www.usgs.gov/national-hydrography/nhdplus-high-resolution
# Data Dictionary: https://www.usgs.gov/ngp-standards-and-specifications/national-hydrography-dataset-nhd-data-dictionary-feature-classes
#
# Workflow Summary:
# 1. List files in /data/intermediate/
# 2. QA check on 
# 2. Read each file
# 3. Combine all into one sf object
#
# Output: flowlines 
#
# Dependencies:
# -    tidyverse: general data wrangling
# -    fs:        file interface system
# -    glue:      string interpolation
# -    here:      consistent relative paths
# -    sf:        handling spatial data
# -    units      unit conversion
#
# Notes: inputs flowlines from 171 L4 Ecoregions and merges to ~3,405,000 obs
# of 178 variables
#
# ============================================================================== 

# Load libraries
library(tidyverse)
library(fs)
library(glue)
library(here)
library(sf)
library(units)

# ------------------------------------------------------------------------------
# 1. List All Downloaded Files
# ------------------------------------------------------------------------------

# --- 1a. get list of file names ----------------------------------------------
file_path  <- "data/intermediate"      # top-level folder for intermediate data
dir_name   <- "nhdphr_by_ecoregion/"   # subfolder for NHDPlus HR flowlines

gpkg_files <- dir_ls(glue("{here()}/{file_path}/{dir_name}/", glob = "*.gpkg"))

# --- 1b. get list of column types --------------------------------------------
column_types <- map(gpkg_files, function(file) {
  region <- file %>%
    path_file() %>%
    str_remove("\\.gpkg$") %>%
    str_replace_all("_", " ")
  
  sf_obj <- read_sf(file)
  
  tibble(
    region = region,
    column = names(sf_obj),
    class = map_chr(sf_obj, ~ class(.x)[1])
  )
})

type_summary <- bind_rows(column_types)

# ------------------------------------------------------------------------------
# 2. QA Check on potential type conflicts prior to merge
# ------------------------------------------------------------------------------

# --- 2a. Find which regions had type conflicts -------------------------------
# View where column types differ across files 
type_summary_table <- type_summary %>%
  group_by(column) %>%
  summarise(n_types = n_distinct(class), .groups = "drop") %>%
  filter(n_types > 1)

# Join back to original 
type_summary_table_regions <- type_summary %>%
  semi_join(type_summary_table, by = "column") %>%
  arrange(column, region)

# make a table of results
conflicts <- type_summary_table_regions %>%
  group_by(column) %>%
  summarise(
    types = paste(unique(class), collapse = ", "),
    regions = paste(unique(region), collapse = "; "),
    .groups = "drop"
  ) %>%
  arrange(types)

# log the conflicts
write_csv(conflicts, 
          here("data/log/nhdphr_conflicts.csv"
               ))

# --- 2b. Identify potential coercions -----------------------------------------
# Parse the types into list columns
conflicts_expanded <- conflicts %>%
  mutate(type_list = str_split(types, ",\\s*")) %>%
  rowwise() %>%
  mutate(
    n_total = length(type_list),
    suggested_type = case_when(
      "flowdir" %in% column ~ "integer",          # from data dictionary
      "ftype" %in% column ~ "integer",            # from data dictionary
      "hwtype"  %in% column ~ "integer",          # guess based on 'type'
      "resolution" %in% column ~ "integer",       # from data dictionary
      "thinner" %in% column ~ "integer",          # wild guess
      "POSIXct" %in% type_list ~ "POSIXct",
      "numeric" %in% type_list ~ "numeric",
      "integer" %in% type_list ~ "integer",
      TRUE ~ type_list[[1]]
    )
  ) %>%
  ungroup()

# Show proposed coercions
coercion_table <- conflicts_expanded %>%
  select(column, types, suggested_type, regions)

# --- 2c. Generate coercion function _-----------------------------------------
generate_coercion_function <- function(coercion_df) {
  lines <- coercion_df %>%
    mutate(code = glue::glue(
      'if ("{column}" %in% names(sf_obj)) sf_obj${column} <- as.{suggested_type}(sf_obj${column})'
    )) %>%
    pull(code)
  
  fn_code <- c(
    "coerce_column_types <- function(sf_obj) {",
    paste0("  ", lines),
    "  return(sf_obj)",
    "}"
  )
  
  cat(paste(fn_code, collapse = "\n"))
}

# ------------------------------------------------------------------------------
# 3. Read and combine flowlines from all .gpkg files with type coercion
# ------------------------------------------------------------------------------

# --- 3a. Coerce known problematic columns to common types --------------------
# Uses a file-reading loop with type coercion and error logging
# Fixes issues: 
# -   Only coerce if possible, using a safe test like is.integerish().
# -   Fallback to numeric when needed.
# 
# -   Applies coercion one column at a time
# -   Skips columns that cause errors (and logs them)
# -   Prevents across() from failing all at once
# -   Wrap the across() call in logic that filters to only existing columns. 
#
# -   Fine-grained control: logs problems per column, per file
# -   Non-blocking: does not interrupt the whole region's read if a single 
#       column fails
# -   Quiet warnings: keeps logs readable but still lets you know what happened
#
# -   coerce fdate to character safely in all files. Character is the most 
#        flexible, readable, and safest for uncertain timestamp formats.

safe_as_integer <- function(x) {
  if (!is.numeric(x)) {
    warning("⚠️ Not numeric — skipping integer coercion")
    return(x)
  }
  if (all(is.na(x))) return(as.integer(x))
  if (all(x == floor(x), na.rm = TRUE)) return(as.integer(x))
  warning("⚠️ Not integer-safe — coercing to numeric instead")
  return(as.numeric(x))
}

coerce_column_types <- function(sf_obj) {
  # Handle fdate separately
  if ("fdate" %in% names(sf_obj)) {
    tryCatch({
      sf_obj$fdate <- as.character(sf_obj$fdate)
    }, error = function(e) {
      message(glue::glue("⚠️ Could not coerce `fdate` — {e$message}"))
    })
  }
  
  # Columns that can safely be numeric (if integer-like)
  intish_cols <- c("avgqadjma", "gageqma", "qgadjma", "qgnavma", "hwnodesqkm")
  
  for (col in intersect(intish_cols, names(sf_obj))) {
    tryCatch({
      sf_obj[[col]] <- suppressWarnings(safe_as_integer(sf_obj[[col]]))
    }, error = function(e) {
      message(glue("⚠️ Skipped numeric coercion for `{col}` — {e$message}"))
    })
  }
  
  # Columns with mixed character/numeric → standardize as character
  char_cols <- c("flowdir", "ftype", "resolution", "thinner", "hwtype")
  
  for (col in intersect(char_cols, names(sf_obj))) {
    tryCatch({
      sf_obj[[col]] <- as.character(sf_obj[[col]])
    }, error = function(e) {
      message(glue("⚠️ Skipped character coercion for `{col}` — {e$message}"))
    })
  }
  
  return(sf_obj)
}

flowlines_all <- map_dfr(gpkg_files, function(file) {
  region_name <- file %>%
    fs::path_file() %>%
    str_remove("\\.gpkg$") %>%
    str_replace_all("_", " ")
  
  tryCatch({
    sf_obj <- read_sf(file)
    sf_obj <- coerce_column_types(sf_obj)
    sf_obj %>% mutate(ecoregion = region_name)
  }, error = function(e) {
    message(glue("⚠️ Failed to read or coerce: {region_name} — {e$message}"))
    NULL
  })
})

# -----------------------------------------------------------------------------
# 4. Check and save results
# -----------------------------------------------------------------------------

# --- 4a. check results -------------------------------------------------------
# Check for empty geometries -- should be zero 
n_empty <- sum(sf::st_is_empty(flowlines_all))
message(glue("Found {n_empty} empty geometries"))

# Check for duplicate column names
dup_names <- names(flowlines_all)[duplicated(names(flowlines_all))]

dups_case <- flowlines_all %>%
  names() %>%
  tolower() %>%
  duplicated()

names(flowlines_all)[dups_case]

# drop shape_length prior to writing
flowlines_all <- flowlines_all %>%
  select(-matches("^shape_length$", ignore.case = TRUE))

# --- 4b. drop qa/qc prior to writing -----------------------------------------
# drop qa/qc vars prior to witing
flowlines_vars <- tibble(var_names = names(flowlines_all))

flowlines_vars_sub <- flowlines_vars %>%
  filter(!str_detect(var_names, "^qa_|^va_|^qc_|^vc_|^qe_|^ve_"))

# --- 4c. write merged results ------------------------------------------------
# close any open processes prior to writing
unlink(here("data/processed/flowlines_combined_clean.gpkg"))

# --- 4b. write merged results ------------------------------------------------
sf::write_sf(flowlines_all[, flowlines_vars_sub$var_names], 
             here("data/processed/flowlines_combined_clean.gpkg"))

# -----------------------------------------------------------------------------
# 5. Make data dictionary
# -----------------------------------------------------------------------------
flowlines_vars <- tibble(var_names = names(flowlines_all))

fld <- c("Enabled", "FCode", "FDate", "FlowDir", "FType", "GNIS_ID",
         "GNIS_Name", "InNetwork", "LengthKM", "MainPath", "NHDPlusID",
         "Permanent_Identifier", "ReachCode", "VisibilityFilter", "VPUID",
         "WBArea_Permanent_Identifier", "resolution", "streamleve", 
         "streamorde", "streamcalc", "fromnode", "tonode","hydroseq", 
         "levelpathi", "pathlength", "terminalpa", "arbolatesu", "divergence", 
         "startflag", "terminalfl", "uplevelpat", "uphydroseq", "dnlevel", 
         "dnlevelpat", "dnhydroseq", "dnminorhyd", "dndraincou", "frommeas", 
         "tomeas", "rtndiv", "thinner", "vpuin", "vpuout", "areasqkm", 
         "totdasqkm", "divdasqkm", "maxelevraw", "minelevraw", "maxelevsmo", 
         "minelevsmo", "slope", "slopelenkm", "elevfixed", "hwtype", 
         "hwnodesqkm", "statusflag", "qama", "vama", "qincrama", "qbma", "vbma",
         "qincrbma", "qcma", "vcma", "qincrcma", "qdma", "vdma", "qincrdma", 
         "qema", "vema", "qincrema", "qfma", "qincrfma", "arqnavma", "petma", 
         "qlossma", "qgadjma", "qgnavma", "gageadjma", "avgqadjma", "gageidma", 
         "gageqma", "geom", "ecoregion", "gridcode","featureid", "sourcefc", 
         "shape_area", "comid", "wbareacomi", "tidal", "totma", "wbareatype", 
         "pathtimema", "lakefract", "surfarea", "rareahload", "rpuid"
         )

data_dict <- tibble(
  field = fld,
  description = c(
    "Participates in geometric network",
    "Five-digit feature code (type + subtype)",
    "Date of last modification",
    "Flow direction relative to geometry order",
    "Three-digit feature type code",
    "GNIS ID for named feature",
    "GNIS name of feature",
    "Included in NHDPlus navigable network",
    "Length in kilometers",
    "Identifier for main stem",
    "NHDPlus feature ID",
    "GUID from The National Map",
    "Reach code (HUC8 + 6)",
    "Scale display filter",
    "Vector Processing Unit ID",
    "GUID for associated waterbody",
    "Data resolution: 1 = Local, 2 = High",
    "Stream segment level in dendritic tree",
    "Stream order (Strahler)",
    "Stream order (alternative calculation)",
    "Start node ID",
    "End node ID",
    "Hydrologic sequence number",
    "Levelpath ID",
    "Distance to outlet (km)",
    "Hydroseq of terminal outlet",
    "Total upstream length (km)",
    "Divergence from main path",
    "Flag: headwater start",
    "Flag: terminal outlet",
    "Upstream levelpath ID",
    "Upstream hydroseq",
    "Downstream level",
    "Downstream levelpath ID",
    "Downstream hydroseq",
    "Downstream minor hydroseq",
    "Downstream connections count",
    "Start position (0–100)",
    "End position (0–100)",
    "Return divergence flag (0 = no, 1 = yes)",
    "Thinner stream flag (1 = true)",
    "Vector Processing Unit (VPU) input ID",
    "Vector Processing Unit (VPU) output ID",
    "Catchment area (sq km)",
    "Total upstream drainage area (sq km)",
    "Divergence-adjusted drainage area (sq km)",
    "Maximum elevation from raw DEM (cm)",
    "Minimum elevation from raw DEM (cm)",
    "Maximum elevation from smoothed DEM (cm)",
    "Minimum elevation from smoothed DEM (cm)",
    "Mean slope (m/m)",
    "Slope length (km)",
    "Fixed elevation adjustment flag",
    "Headwater type code",
    "Headwater node density (nodes/sq km)",
    "Status flag for flowline (e.g., active, historic)",
    "Mean annual flow (cms)",
    "Mean annual velocity (m/s)",
    "Incremental annual flow (cms)",
    "Mean flow for scenario B (cms)",
    "Mean velocity for scenario B (m/s)",
    "Incremental flow for scenario B (cms)",
    "Mean flow for scenario C (cms)",
    "Mean velocity for scenario C (m/s)",
    "Incremental flow for scenario C (cms)",
    "Mean flow for scenario D (cms)",
    "Mean velocity for scenario D (m/s)",
    "Incremental flow for scenario D (cms)",
    "Mean flow for scenario E (cms)",
    "Mean velocity for scenario E (m/s)",
    "Incremental flow for scenario E (cms)",
    "Mean flow for scenario F (cms)",
    "Incremental flow for scenario F (cms)",
    "Area-weighted routed flow value (cms)",
    "Potential evapotranspiration (mm/year)",
    "Loss in flow (cms) due to human alterations",
    "Gage-adjusted flow (cms)",
    "Gage-adjusted flow, navigable network only (cms)",
    "Flag: gage-adjusted model used",
    "Average gage-adjusted model output (cms)",
    "USGS gage ID for the flowline",
    "Annual mean flow at gage (cms)",
    "Geometry column (LINESTRING)",
    "Ecoregion name (added during processing)",
    "Grid code (often from rasterized source)",
    "Feature ID in source data",
    "Source feature class",
    "Polygon area (square meters or km²)",
    "NHD COMID (Catchment Object ID)",
    "Associated COMID for waterbody",
    "Flag indicating tidal influence",
    "Total modeled area (km²)",
    "Waterbody area type classification",
    "Estimated time to reach outlet (hr)",
    "Fraction of area covered by lakes in catchment",
    "Catchment surface area (sq km)",
    "Rare species habitat load score (if available)",
    "Reach Processing Unit ID"
    )
  ) %>% mutate(var_names = tolower(field))

data_dict <- left_join(flowlines_vars, data_dict,
                       by = join_by(var_names)) %>%
  arrange(field) %>%
  select(-var_names) %>%
  filter(!is.na(field))

write_csv(data_dict, here("data/meta/flowlines_combined_data_dict"))