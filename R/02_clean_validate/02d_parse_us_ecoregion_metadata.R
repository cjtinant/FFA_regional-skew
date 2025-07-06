# ==============================================================================
# Script Name:    02d_parse_us_ecoregion_metadata.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-07-01
#
# Purpose:        Loop through multiple FGDC metadata XML files and extract:
#                   1. Attribute definitions
#                   2. CRS and spatial extent
#
# Output:         data/meta/<name>_attributes.csv
#                 data/meta/<name>_spatial_metadata.csv
# Dependencies:   xml2, dplyr, readr, fs, stringr
# ==============================================================================

library(xml2)
library(dplyr)
library(readr)
library(fs)
library(stringr)
library(purrr)

# Directory with .xml metadata files
xml_dir <- "data/raw"
meta_out_dir <- "data/meta"

# Recursively find all .shp.xml files in nested folders
xml_files <- dir_ls(xml_dir, recurse = TRUE, regexp = "\\.shp\\.xml$")

# Function to parse one file
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
    domain = xml_text(xml_find_first(attrs, "attrdomv/udom | attrdomv/rdom/udom | attrdomv/rdom/rdommin"))
  ) %>%
    mutate(across(everything(), ~ na_if(.x, "")))
  
  # 2. Extract spatial metadata
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
  
  # 3. Write to disk
  attr_file <- path(meta_out_dir, str_glue("{name_root}_attributes.csv"))
  spatial_file <- path(meta_out_dir, str_glue("{name_root}_spatial_metadata.csv"))
  
  write_csv(attr_tbl, attr_file)
  write_csv(crs_info, spatial_file)
  
  message("✅ Written: ", attr_file)
  message("✅ Written: ", spatial_file)
}

# Apply to all xml files
walk(xml_files, parse_fgdc)
