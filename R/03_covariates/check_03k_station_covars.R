# ==============================================================================
# Script Name:     03b_station_covars.R
# Author:          Charles Jason Tinant — with GPT-5 Thinking
# Date Created:    2025-08-13
# Last Updated:    2025-08-13
#
# Changelog:
# - 2025-08-13     Initial script from GPT-5 output
# - 2025-08-13     Update script using 03d_make_macrozone_layer as a template.
#
# Purpose:         Create a geospatial layer of station-level (Level 0)
#                  covariates and station skew coefficients in CSV format.
#
# Workflow:
# 0. Define paths & project CRS.
# 1. Read and clean sites: read in raw data, coalesce drainage area values keeping
#    contributing drainage area if available, drop gages missing altitude or
#    drainage area values. Perform a sanity check using skimr and count the
#    number of gages with incomplete and complete metadata.
# 2. Convert watershed area in square miles to square kilometers and altitude
#    from feet to meters.
# 3. Encode as spatial points by datum, transform to EPSG:5070, write outputs.
# 4. Use stylr and lintr for standard code.
#
# Inputs:
# - data/processed/gage_summary_skew
# Outputs:
# - data/processed/stations/stations_covars.gpkg  (layer="stations_covars"; CRS=EPSG:5070)
# - data/processed/stations/stations_covars.csv   (tabular, no geometry)
#
# Dependencies: tidyverse, sf, here, readr, janitor, skimr
#
# Related Files:
# - docs/metadata/data-dictionaries/peakflow-gage_data-dictionary_v01.csv
#
# Conventions:
# - Work in NAD83 geographic (EPSG:4269) for input coordinates
# - Persist spatial outputs in EPSG:5070 (CONUS Albers)
# - Keep lat_dd/long_dd columns in decimal degrees
# - Join key: site_no
#
# ==============================================================================
# --- load libraries ---
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(sf)
  library(janitor)
  library(units)
  library(skimr)
})
# ------------------------------------------------------------------------------
# 0. Define paths and project CRS.
# ------------------------------------------------------------------------------
in_gage_gpkg <- here(
  "data", "processed", "peakflow_gages", "gage_covars.gpkg"
)

out_dir <- here("data", "processed", "peakflow_gages")
out_csv <- file.path(out_dir, "stations_covars.csv")
out_gpkg <- file.path(out_dir, "stations_covars.gpkg")
out_layer <- "stations_covars"

crs_nad83 <- 4269 # NAD83 geographic (decimal degrees)
crs_wgs84 <- 4326 # WGS84 geographic (decimal degrees)
crs_nad27 <- 4267 # NAD27 geographic (Clarke 1866)
crs_out   <- 5070 # CONUS Albers Equal Area (repo standard)

# ------------------------------------------------------------------------------
# 1. Read and clean sites
# ------------------------------------------------------------------------------
stopifnot(file.exists(in_gage_gpkg))

gage_raw <- read_sf(in_gage_gpkg) %>%
  st_drop_geometry()

gage_raw <- read_csv(
  in_gage_csv,
  col_types = cols(
    site_no               = col_character(),
    station_nm            = col_character(),
    dec_lat_va            = col_double(),
    dec_long_va           = col_double(),
    alt_va                = col_double(),
    huc_cd                = col_character(), # keep leading zeros
    basin_cd              = col_character(),
    drain_area_va         = col_double(),
    contrib_drain_area_va = col_double(),
    coord_datum_cd        = col_character(),
    tier                  = col_character(),
    skew_lp3              = col_double()
  ),
  show_col_types = FALSE
) %>%
  clean_names() %>%
  select(-any_of(c("n_years", "basin_cd", "topo_cd"))) %>%
  relocate(skew_lp3, .after = alt_va) %>%
  relocate(coord_datum_cd, tier, .after = last_col())

# coalesce drainage area (prefer contributing if present)
gage_area_sqmi <- gage_raw %>%
  mutate(
    wtsd_area_sqmi = coalesce(contrib_drain_area_va, drain_area_va)
  ) %>%
  select(-c(drain_area_va, contrib_drain_area_va))

# drop gages missing altitude or drainage area
gage_filt <- gage_area_sqmi %>%
  filter(!is.na(alt_va), !is.na(wtsd_area_sqmi))

# sanity summary
skim(gage_filt)
cnt_gage_raw <- nrow(gage_raw)
cnt_gage_filt <- nrow(gage_filt)
cnt_gage_dropped <- cnt_gage_raw - cnt_gage_filt
message(
  "Kept ", cnt_gage_filt, " of ", cnt_gage_raw, " (dropped ", cnt_gage_dropped, ").")

# ------------------------------------------------------------------------------
# 2. Convert to SI Units and standardize names
# ------------------------------------------------------------------------------
sqmi_to_sqkm <- 2.58999
ft_to_m <- 0.3047992424196

gage_clean <- gage_filt %>%
  mutate(
    wtsd_area_sqkm = round(wtsd_area_sqmi * sqmi_to_sqkm, 2),
    alt_m          = round(alt_va * ft_to_m, 2)
  ) %>%
  select(-c(wtsd_area_sqmi, alt_va)) %>%
  rename(
    lat_dd  = dec_lat_va,
    long_dd = dec_long_va
  )

# ------------------------------------------------------------------------------
# 3. Encode as spatial points by datum, transform to EPSG:5070, write outputs
# ------------------------------------------------------------------------------
# normalize datum codes and map to EPSG
gage_tagged <- gage_clean %>%
  mutate(coord_datum_cd = toupper(trimws(coord_datum_cd))) %>%
  mutate(crs_in = case_when(
    coord_datum_cd %in% c("NAD83", "NAD83(1986)", "NAD83(2011)") ~ crs_nad83,
    coord_datum_cd == "WGS84" ~ crs_wgs84,
    coord_datum_cd == "NAD27" ~ crs_nad27,
    TRUE ~ NA_real_
  ))

unknown <- gage_tagged %>% filter(is.na(crs_in))
if (nrow(unknown) > 0) {
  warning(
    "Unknown coord_datum_cd for ", nrow(unknown), " rows: ",
    paste(sort(unique(unknown$coord_datum_cd)), collapse = ", "),
    ". They will be retained in CSV, omitted from spatial output."
  )
}

# helper: only build sf when there are rows; otherwise return NULL
make_sf <- function(df, epsg) {
  df_epsg <- df %>% dplyr::filter(crs_in == epsg)
  if (nrow(df_epsg) == 0) {
    return(NULL)
  }
  df_epsg %>%
    sf::st_as_sf(
      coords = c("long_dd", "lat_dd"),
      crs = epsg, remove = FALSE
    )
}

# build per-datum sfs, drop NULLs, transform each to 5070, then bind
sf_list <- list(
  make_sf(gage_tagged, crs_nad83),
  make_sf(gage_tagged, crs_wgs84),
  make_sf(gage_tagged, crs_nad27)
) %>%
  purrr::compact() %>%
  purrr::map(~ sf::st_transform(.x, crs_out))

if (length(sf_list) == 0L) {
  stop("No rows with recognized coord_datum_cd; nothing to write.")
}

stations_sf <- sf_list %>%
  purrr::reduce(dplyr::bind_rows) %>%
  {
    if (!all(sf::st_is_valid(.))) sf::st_make_valid(.) else .
  }

stations_sf <- sf_list %>%
  purrr::reduce(bind_rows) %>%
  {
    if (!all(st_is_valid(.))) st_make_valid(.) else .
  } %>%
  st_transform(crs_out)

# write GPKG (points in EPSG:5070)
st_write(
  stations_sf,
  dsn = out_gpkg, layer = out_layer, delete_layer = TRUE, quiet = TRUE
)

# write CSV (tabular only; includes unknown-datum rows)
bind_rows(
  stations_sf %>% st_drop_geometry(),
  unknown %>% select(-crs_in)
) %>%
  write_csv(out_csv)

message("Wrote: ", out_gpkg, " [layer='", out_layer, "'] (EPSG:", crs_out, ")")
message("Wrote: ", out_csv)
