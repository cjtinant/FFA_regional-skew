==============================================================================
  # Script Name:     02q_download_xml_metadata.R
  # Author: Charles  Jason Tinant — with ChatGPT 4o
  # Date Created:    2025-07-14
  # Last Updated:
  #
  # Purpose:         This script downloads xml metadata
  #
  # Data URLs:
  # -   https://gisarchive.cnra.ca.gov/iso/Elevation/ned/43122/grid/metadata.htm
  #
  # Workflow Summary:
  # 1.
  #
  # Output:
  # - Clean xml metadata
  #
  # Dependencies:
  # Notes:
  # =============================================================================

# load libraries
library(rvest)
library(xml2)

url <- "https://gisarchive.cnra.ca.gov/iso/Elevation/ned/43122/grid/metadata.htm"
html <- read_html(url)

# Try extracting a <script> tag with XML inside
xml_string <- html %>% html_node("script[type='application/xml']") %>% html_text()

# Save to file
writeLines(xml_string, "data/extracted_metadata.xml")


# https://www.epa.gov/waterdata/nhdplusv2-metadata
# Koppen -- https://www.arcgis.com/home/item.html?id=8383418e1f874e5287498e027dea420d

MODIS data includes metadata from two sources: embedded HDF metadata and external ECS (XML) metadata. The HDF metadata, similar to ASTER files, contains global and dataset-specific attributes, including information about the granule. The external ECS metadata, provided as an .met file, is a subset of the HDF metadata in XML format. This external metadata is delivered with the MODIS product and is useful for understanding the data.

