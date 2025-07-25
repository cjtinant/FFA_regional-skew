# ==============================================================================
# Script Name:     02a_merge_nhdplus_hr_flowlines.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-06-07
# Last Updated:    2025-07-25
# Change Log:
# - 2025-07-13     Update name and folder path to fit with naming conventions.
#                  Update metadata in script header
# - 2025-07-25     Update header information;
#                  move notes to `script-notes_and_developer-log`
#
# Purpose: Merge NHDPlus HR flowlines into a single GeoPackage.
#
# Workflow Summary:
# 1. List files in /data/raw/nhdphr_flowlines/
# 2. QA check on potential type conflicts prior to merge.
# 3. QA check on potential coercions.
# 4. Read and combine flowlines from all .gpkg files with type coercion.
# 5. Perform QA on result and export result.
# 6. Make and export a data dictionary to
#    `data/meta/flowlines_combined_data_dict.csv``

# Input/Data URLs
# - data/raw/nhdphr_flowlines/*.gpkg — one per Level IV ecoregion (N =171) .
# - https://www.usgs.gov/ngp-standards-and-specifications/ Data Dictionary items.
# Outputs:
# - nhdphr_flowlines_combined.gpkg (~3,405,000 obs x 178 vars) saved to:
#   data/processed/nhdphr/
# - data/log/nhdphr_conflicts.csv -- type conflicts log
#
# Dependencies:
# - tidyverse      General data wrangling
# - fs             File interface system
# - glue           String interpolation
# - here           Consistent relative paths
# - sf             Handling spatial data
# - units          Unit conversion
#
# Helper Functions:
#
# Related Milestone Reports:
#
# ==============================================================================
# --- Load libraries ---
library(tidyverse)
library(fs)
library(glue)
library(here)
library(sf)
library(units)

# ------------------------------------------------------------------------------
# 1. Read in downloaded nhdphr flowline files
# ------------------------------------------------------------------------------
# --- Get list of file names ---
file_path  <- "data/raw"      # top-level folder for intermediate data
dir_name   <- "nhdphr_flowlines/"   # subfolder for NHDPlus HR flowlines

gpkg_files <- dir_ls(glue("{here()}/{file_path}/{dir_name}/", glob = "*.gpkg"))

# --- Get list of column types ---
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
# 2. QA check on potential type conflicts prior to merge
# ------------------------------------------------------------------------------
# --- Check regions for type conflicts -- column types differ across files ---
type_summary_table <- type_summary %>%
  group_by(column) %>%
  summarise(n_types = n_distinct(class), .groups = "drop") %>%
  filter(n_types > 1)

# --- Join results with original ---
type_summary_table_regions <- type_summary %>%
  semi_join(type_summary_table, by = "column") %>%
  arrange(column, region)

# --- make a table of results ---
conflicts <- type_summary_table_regions %>%
  group_by(column) %>%
  summarise(
    types = paste(unique(class), collapse = ", "),
    regions = paste(unique(region), collapse = "; "),
    .groups = "drop"
  ) %>%
  arrange(types)

# --- log the conflicts ---
write_csv(conflicts,
          here("data/log/nhdphr_conflicts.csv"
          ))

# ------------------------------------------------------------------------------
# 3. QA check on potential coercions
# ------------------------------------------------------------------------------
# --- Parse the types into list columns ---
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

# --- Show proposed coercions ---
coercion_table <- conflicts_expanded %>%
  select(column, types, suggested_type, regions)

# --- Generate coercion function ---
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
# 4. Read and combine flowlines from all .gpkg files with type coercion
# ------------------------------------------------------------------------------
# --- Coerce known problematic columns to common types ---
safe_as_integer <- function(x) {
  if (!is.numeric(x)) {
    warning("⚠️ Not numeric — skipping integer coercion")
    return(x)
  }
  if (all(is.na(x))) return(as.integer(x))
  if (all(x == floor(x), na.rm = TRUE)) return(as.integer(x))
  warning("⚠️ Not integer-safe — coercing to numeric instead")
  #  return(as.numeric(x))
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

  #  return(sf_obj)
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
# 5. Checks results of merge and save results
# -----------------------------------------------------------------------------
# --- Check results ---
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

# --- Drop shape_length prior to writing ---
flowlines_all <- flowlines_all %>%
  select(-matches("^shape_length$", ignore.case = TRUE))

# --- Drop qa/qc prior to writing ---
flowlines_vars <- tibble(var_names = names(flowlines_all))

flowlines_vars_sub <- flowlines_vars %>%
  filter(!str_detect(var_names, "^qa_|^va_|^qc_|^vc_|^qe_|^ve_"))

# --- Write merged results ---
# close any open processes prior to writing
unlink(here("data/processed/nhdphr_flowlines/nhdhr_flowlines_combined.gpkg"))

# write merged results
sf::write_sf(flowlines_all[, flowlines_vars_sub$var_names],
             here("data/processed/nhdphr_flowlines/nhdhr_flowlines_combined.gpkg"))

# -----------------------------------------------------------------------------
# 5. Make data dictionary
# -----------------------------------------------------------------------------
flowlines_vars <- tibble(var_names = names(flowlines_all))

fld <- c("Enabled", "FCode", "FDate", "FlowDir", "FType", "GNIS_ID",
  "GNIS_Name", "InNetwork", "LengthKM", "MainPath", "NHDPlusID",
  "Permanent_Identifier", "ReachCode", "VisibilityFilter", "VPUID",
  "WBArea_Permanent_Identifier", "resolution", "streamleve",
  "streamorde", "streamcalc", "fromnode", "tonode", "hydroseq",
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
  "gageqma", "geom", "ecoregion", "gridcode", "featureid", "sourcefc",
  "shape_area", "comid", "wbareacomi", "tidal", "totma", "wbareatype",
  "pathtimema", "lakefract", "surfarea", "rareahload", "rpuid"
)

data_dict <- tibble(field = fld,
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

write_csv(data_dict, here("data/meta/flowlines_combined_data_dict.csv"))
