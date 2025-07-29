# ==============================================================================
# Script Name:     parse_metadata.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-07-01
# Last Update:     2025-07-28
# Change Log:
# - 2025-07-28     Update header information;
#                  move notes to `script-notes_and_developer-log`
#
# Purpose:         Loop through multiple FGDC metadata XML files and extract
#                  attribute definitions, CRS, and spatial extent
#
# Workflow Summary:
# 1. Check `raw/data` or a user-defined folder for XML files.
# 2. Extract spatial metadata, including: datum, ellipsoid, semi_major_axis,
#    inverse_flattening, planar_units, abs_res, ord_res, bounding box coords.
#
# Input/Data URLs:
# - xml data in a user-defined folder.
# Outputs:
# - data/meta/<name>_attributes.csv
# - data/meta/<name>_spatial_metadata.csv
#
# Dependencies:
# - dplyr, readr   General data wrangling, import and export.
# - fs             File interface system.
# - here           Consistent relative paths.
# - xml2           Parse XML data.
#
# Helper Functions:
#
# Related Milestone Reports:
#
# ==============================================================================
# --- Load libraries ---
library(xml2)
library(dplyr)
library(readr)
library(fs)
library(stringr)
library(purrr)

# ------------------------------------------------------------------------------
# 1. Check Raw Data
# ------------------------------------------------------------------------------
# --- Directory with .xml metadata files ---
xml_dir <- "data/meta"
meta_out_dir <- "data/meta/raw_xml"

stopifnot(dir_exists(xml_dir))
if (!dir_exists(meta_out_dir)) dir_create(meta_out_dir, recurse = TRUE)

# --- Recursively find all .shp.xml files in nested folders ---
xml_files <- dir_ls(xml_dir, recurse = TRUE, regexp = "\\.shp\\.xml$")

# ------------------------------------------------------------------------------
# --- Function to parse one file ---
parse_fgdc <- function(file_path) {
  message("📄 Parsing: ", basename(file_path))
  doc <- read_xml(file_path)
  name_root <- str_remove(basename(file_path), "\\.shp\\.xml$")

  # 1. Extract attributes
  attrs <- xml_find_all(doc, ".//eainfo//detailed//attr")
  attr_tbl <- tibble(
    attr_name = xml_text(xml_find_first(attrs, "attrlabl")),
    description = xml_text(xml_find_first(attrs, "attrdef")),
    source = xml_text(xml_find_first(attrs, "attrdefs")),
    domain = xml_text(xml_find_first(
      attrs,
      "attrdomv/udom |
                                   attrdomv/rdom/udom |
                                   attrdomv/rdom/rdommin"
    ))
  ) %>%
    mutate(across(everything(), ~ na_if(.x, "")))

  # ------------------------------------------------------------------------------
  # 2. Extract spatial metadata
  # ------------------------------------------------------------------------------
  crs_info <- tibble(
    file = name_root,
    datum = xml_text(xml_find_first(doc, ".//spref//geodetic//horizdn")),
    ellipsoid = xml_text(xml_find_first(doc, ".//spref//geodetic//ellips")),
    semi_major_axis = xml_text(xml_find_first(doc, ".//spref//geodetic//semiaxis")),
    inverse_flattening = xml_text(xml_find_first(doc, ".//spref//geodetic//denflat")),
    planar_units = xml_text(xml_find_first(doc, ".//spref//planar//planci//plandu")),
    abs_res = xml_text(xml_find_first(doc, ".//spref//planar//planci//coordrep//absres")),
    ord_res = xml_text(xml_find_first(doc, ".//spref//planar//planci//coordrep//ordres")),
    west = xml_text(xml_find_first(doc, ".//spdom//bounding//westbc")),
    east = xml_text(xml_find_first(doc, ".//spdom//bounding//eastbc")),
    north = xml_text(xml_find_first(doc, ".//spdom//bounding//northbc")),
    south = xml_text(xml_find_first(doc, ".//spdom//bounding//southbc"))
  ) %>%
    mutate(across(everything(), ~ na_if(.x, "")))

  # ------------------------------------------------------------------------------
  # 3. Export results
  # ------------------------------------------------------------------------------

  attr_file <- path(meta_out_dir, str_glue("{name_root}_attributes.csv"))
  spatial_file <- path(meta_out_dir, str_glue("{name_root}_spatial_metadata.csv"))

  write_csv(attr_tbl, attr_file)
  write_csv(crs_info, spatial_file)

  message("✅ Written: ", attr_file)
  message("✅ Written: ", spatial_file)
}

# --- Apply to all xml files in folder ---
walk(xml_files, parse_fgdc)
