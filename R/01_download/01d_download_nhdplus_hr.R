# ==============================================================================
# Script Name:    01d_download_nhdplus_HR.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-05-19
# Last Updated:   2025-06-04
#
# Purpose:         Download NHDPlus HR (1:24k) tiles by HUC4, clipped to 
#                  Great Plains
# Data URLs:
# -   
# 
# Workflow Summary:
# 1.   Load Great Plains Level IV Ecoregions and keep only external boundary
# 2.   Move datum from WGS84 to NAD83 and buffer.
# 3.   Download 1:100,000 scale V2 data 
# 2.   Reproject shapefiles to a common CRS (US Albers Equal Area – EPSG:5070) 
# 3.   Clip Levels I–III to the spatial extent of Level IV (CONUS boundary) 
# 4.   Validate and repair geometries and coerce to consistent geometry type.
# 5.   Recalculate area in sq-km using a common CRS
# 6.   Export reprojected, clipped, cleaned data as a gpkg for downstream use.
#
# Output:
# -    NHDplus v2.1 flowlines and catchment boundaries for the Great Plains
#      Ecoregion
#
# Dependencies:
# -    dplyr
# -    fs
# -    ggplot2
# -    here:                 # consistent relative path
# -    nhdplusTools          # Tools for working with National Hydrography 
#                                 Dataset Plus (NHDPlus) data.
# -    sf:                   # handling spatial data
# -    units                 # unit conversion
#
# Notes:
# -
# ============================================================================== 

# Load libraries
library(dplyr)
library(ggplot2)
library(here)
library(nhdplusTools)
library(sf)
library(units)

# ------------------------------------------------------------------------------
# Purpose: Download NHDPlus HR (1:24k) tiles by HUC4, clipped to Great Plains
# ------------------------------------------------------------------------------

#START HERE -- USE A MUCH SMALLER AREA -- MAYBE LEVEL 2
# 1. Reuse the same AOI from V2 script
eco_lev4 <- st_read("data/raw/vector_raw/ecoregions_unprojected/us_eco_lev4_greatplains_geographic.gpkg") #%>%

names <- eco_lev4 %>%
  select(na_l2code) %>%
  distinct()
# Filter by level 2 data

    filter(na_l1name == "GREAT PLAINS") 


#%>%
  st_union() %>%
  st_sf(geometry = .) %>%
  st_cast("POLYGON") %>%
  st_sf() %>%
  mutate(area = st_area(.)) %>%
  arrange(desc(area)) %>%
  slice(1) %>%
  st_buffer(1) %>%
  st_transform(4269)

# Check EPSG (should be NAD83 / EPSG:4269)
epsg_ck2 <- st_crs(eco_lev4_gp_main_buf) %>%
  unlist()

# Quick reality check (visually)
ggplot() +
  geom_sf(data = eco_lev4_gp_main_buf,
          fill = "gray80",
          color = "white") +
  geom_sf(data = eco_lev4_gp_main,
          fill = "gray60",
          color = "white")



nhdphr_gp_flowline <- get_nhdphr(
  AOI = eco_lev4_gp_main_buf,
  type = "networknhdflowline",
  t_srs = 5070           # Reproject output to CONUS Albers (EPSG:5070)
)


#url <- "https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/HU4/Shape/WBDHU4_National_Shape.zip"
#dest <- "data/raw/nhdplus/WBD_National_GDB.zip"
# 
# if (!fs::file_exists(dest)) {
#   download.file(url, destfile = dest, mode = "wb")
#   unzip(dest, exdir = "data/raw/nhdplus/WBDHU4_National")
# }

# # 2. Get intersecting HUC4 codes
# huc4_all <- get_huc(id = "all", type = "huc04") %>%
#   st_transform(st_crs(eco_lev4))



# ------------------------------------------------------------------------------
#  Download NHDPlus HR by HUC4 (with throttling & etiquette)
# ------------------------------------------------------------------------------



huc4_proj <- st_transform(huc4, st_crs(eco_lev4_gp_main_buf))

huc4_gp <- huc4_proj %>%
  filter(st_intersects(geometry, eco_lev4_gp_main_buf, sparse = FALSE))

target_huc_codes <- huc4_gp$huc4



# Get all HUC4s (Watershed Boundary Dataset - WBD) for CONUS
huc4 <- get_huc(id = "all", type = "huc04")  # returns sf object


# Reproject to match buffer
huc4_proj <- st_transform(huc4, st_crs(eco_lev4_gp_main_buf))


# Example: Replace this with your actual HUC4 list derived from intersection
huc4_list <- c("1018", "1025", "1106")  # Replace with intersecting HUC4s

# Optional: create a log file of downloads
log_path <- "data/log/nhdplus_hr_download_log.csv"
download_log <- tibble()

# Loop over HUC4s with throttling
for (huc in huc4_list) {
  url <- glue("https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/NHDPlusHR/Beta/GDB/NHDPLUS_H_{huc}_HU4_GDB.zip")
  dest <- glue("data/raw/nhdplus_hr/NHDPLUS_H_{huc}.zip")
  
  if (!file_exists(dest)) {
    message(glue("📥 Downloading HUC {huc}..."))
    tryCatch({
      res <- GET(url, write_disk(dest, overwrite = TRUE), timeout(120))
      if (res$status_code == 200) {
        message(glue("✅ Successfully downloaded: {dest}"))
        download_log <- bind_rows(download_log, tibble(HUC4 = huc, Status = "Downloaded", Timestamp = Sys.time()))
      } else {
        warning(glue("⚠️ Failed to download HUC {huc}: Status {res$status_code}"))
        download_log <- bind_rows(download_log, tibble(HUC4 = huc, Status = "Failed", Timestamp = Sys.time()))
      }
    }, error = function(e) {
      warning(glue("❌ Error downloading HUC {huc}: {e$message}"))
      download_log <- bind_rows(download_log, tibble(HUC4 = huc, Status = "Error", Timestamp = Sys.time()))
    })
    
    Sys.sleep(10)  # 💤 Pause between requests to be polite to the server
  } else {
    message(glue("⏭️ Already downloaded: {dest}"))
    download_log <- bind_rows(download_log, tibble(HUC4 = huc, Status = "Exists", Timestamp = Sys.time()))
  }
}

# Save log
write.csv(download_log, log_path, row.names = FALSE)
message("📄 Download log written to: ", log_path)


