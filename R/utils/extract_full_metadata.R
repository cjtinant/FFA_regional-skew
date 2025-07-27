# =============================================================================
# Script Name:     extract_full_metadata.R
# Author:          CJ Tinant - with ChatGPT 4o
# Date Created:    2025-05-12
# Last Updated:    2025-07-25
# Change Log:
# - 2025-07-25     Update header information;
#                  move notes to `script-notes_and_developer-log`
#
# Purpose:        Extract and validate metadata from ISO or FGDC-style XML files.

# Workflow Summary
# 1. Read and parses XML metadata files
# 2. Extract title, abstract, originator, date, keywords, bounding box, CRS,
#    and constraints
# 3. Output a tidy summary for documentation or QA
#
# Input/Data URLs:
#   - XML metadata files (e.g., data/metadata/us_ecoregions/*.xml)
# Outputs:
#   - A tibble with extracted metadata fields
#
# Dependencies:
# - dplyr          General data wrangling, import and export.
# - fs             File interface system.
# - here           Consistent relative paths.
# - xml2           Parse XML data.
#
# Helper Functions:
#
# Related Milestone Reports:
# =============================================================================
# --- load libraries ---
library(dplyr)
library(fs)
library(here)
library(xml2)

#' Extract metadata from ISO/FGDC XML file
#'
#' Parses an XML metadata file and returns a tidy tibble with core metadata fields
#' such as title, abstract, originator, keywords, bounding box, and constraints.
#'
#' @param xml_path A character string giving the file path to a metadata `.xml` file.
#'
#' @return A tibble with standardized metadata fields (title, abstract, originator, date, etc.)
#'
#' @examples
#' extract_full_metadata("data/metadata/us_ecoregions/us_eco_l4.xml")
#'
#' @export
extract_full_metadata <- function(xml_path) {
  # ... function code ...
}

extract_full_metadata <- function(xml_path) {
  xml <- xml2::read_xml(xml_path)

  # Helper for optional text extraction
  get_text <- function(xpath) {
    result <- xml2::xml_find_first(xml, xpath)
    if (length(result) > 0) xml2::xml_text(result) else NA_character_
  }

  # Keywords (possibly multiple)
  keywords <- xml2::xml_find_all(xml, ".//keyword")
  keyword_list <- xml2::xml_text(keywords)
  keyword_str <- if (length(keyword_list)) paste(keyword_list, collapse = "; ") else NA_character_

  # Bounding Box
  xmin <- get_text(".//westbc | .//westBoundLongitude")
  xmax <- get_text(".//eastbc | .//eastBoundLongitude")
  ymin <- get_text(".//southbc | .//southBoundLatitude")
  ymax <- get_text(".//northbc | .//northBoundLatitude")

  # Spatial reference (e.g., NAD83, Albers Equal Area)
  spatial_ref <- get_text(".//horizdn | .//geodeticDatum | .//referenceSystemIdentifier//code")

  # Access/use constraints
  access_constraint <- get_text(".//accconst | .//resourceConstraints//useLimitation")
  use_constraint <- get_text(".//useconst | .//resourceConstraints//otherConstraints")

  tibble::tibble(
    title = get_text(".//title"),
    abstract = get_text(".//abstract | .//idAbs"),
    originator = get_text(".//origin | .//CI_ResponsibleParty//individualName"),
    pub_date = get_text(".//pubdate | .//date"),
    keywords = keyword_str,
    bbox_xmin = xmin,
    bbox_xmax = xmax,
    bbox_ymin = ymin,
    bbox_ymax = ymax,
    spatial_ref = spatial_ref,
    access_constraint = access_constraint,
    use_constraint = use_constraint
  )
}
