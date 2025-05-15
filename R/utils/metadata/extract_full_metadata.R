# =============================================================================
# Script Name:    extract_full_metadata.R
# Author:         CJ Tinant
# Date Created:   2025-05-12
# Purpose:        Extract and validate metadata from ISO or FGDC-style XML files
#
# Description:
#   - Reads and parses XML metadata files (e.g., EPA shapefiles)
#   - Extracts title, abstract, originator, date, keywords, bounding box, CRS,
#     and constraints
#   - Outputs a tidy summary for documentation or QA
#
# Input: 
#   - XML metadata files (e.g., data/raw/epa_ecoregions/*.xml)
#
# Output: 
#   - A tibble with extracted metadata fields
#
# Dependencies:
#   - xml2
#   - dplyr
#   - tibble
#
# Notes:
#   - Utility function used in milestone 01a and beyond
# =============================================================================

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
#' extract_full_metadata("data/raw/epa_ecoregions/us_eco_l4.xml")
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
