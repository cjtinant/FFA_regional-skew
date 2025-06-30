# ==============================================================================
# Script Name:    01d_download_nhdplus_HR.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-05-19
# Last Updated:   2025-06-06
#
# Purpose:         Download NHDPlus HR (1:24k) flowlines and catchment
                   boundaries clipped to Great Plains
#
# Data URLs: https://www.usgs.gov/national-hydrography/nhdplus-high-resolution
#
# Workflow Summary:
# 1.   Load Great Plains Level IV Ecoregions.
# 2.   Get AOI for each
# 3.   Individually download as a batch
# 4.   Use an iteratively created function to handle edge cases
#
# Output:
# -    NHDplus flowlines and *****catchment boundaries**** for the Great Plains
#      Ecoregion for each Level IV Ecoregion.
#
# Dependencies:
# -   dplyr        -   Data manipulation
# -   fs           -   File system operations
# -   ggplot2      -   Data visualization
# -   glue         -   Formats strings
# -   here         -   Locates files relative to a project root
# -   nhdplusTools -   Tools for traversing and working with National
#                      Hydrography Dataset Plus (NHDPlus) data.
# -   purrr        -   Functional programming toolkit
# -   readr        -   Reads rectangular data
# -   sf           -   Support for simple feature access, a standardized way to
#                      encode and analyze spatial vector data. Binds to 'GDAL'
# -   stringr      -   Wrappers for string operations

# Notes: See the bottom of the script for a test-run that explains some of the
# functions used.
# =============================================================================

# Load libraries
suppressPackageStartupMessages(c(
  library(dplyr),
  library(fs),
  library(glue),  
  library(ggplot2),
  library(here),
  library(nhdplusTools),
  library(purrr),
  library(readr),
  library(sf),
  library(stringr),
  library(units)
  ))

# ------------------------------------------------------------------------------
# 1.Download NHDPlus HR data by L4 Ecoregion.
# ------------------------------------------------------------------------------

# --- Make a function to retry ecoregions that don't batch download -----------

# 🔍 Likely Reasons the Main Loop (below) Might Not Work (works mostly)
# 1. ❌ Missing or Improper CRS
#     get_nhdphr() expects input in EPSG:4326 (WGS 84).
#     If your AOI was still in EPSG:5070 or unprojected, the request silently
#       failed or produced invalid tiles.
# ✔️ Fix that worked: manually reprojected to 4326 before calling get_nhdphr().
#
# 2. ❌ Geometry too complex or fragmented
#       Some AOIs have lots of tiny polygons or complex slivers (e.g.,
#         river corridors).
#       This can overwhelm NHDPlus web service or cause excessive tile requests.
# ✔️ Fix that worked: You simplified by using st_union() and buffering the
#        result to create a clean boundary.
# 3. ❌ Too many tiles requested
#     get_nhdphr() queries by tile chunks. Some ecoregions with narrow but
#       long shapes (e.g. "Platte River Valley and Terraces") span a huge
#       number of tiles even if their area is small.
# ✔️ Fix that worked: You buffered only slightly and isolated a single AOI,
#       dramatically reducing the request size.
# 4. ❌ Retry not properly handled
#     In batch mode, retries on NULL or 504 (timeout) responses may not be
#        triggered or logged.
#     And, if the error is "no applicable method for st_write on class 'NULL',"
#        it’s because you skipped checking if the download succeeded.
# ✔️ Fix that worked: You explicitly guarded the st_write() with a !is.null()
#        check.
# 5. ❌ Missing geometry column renaming
#     Your early versions sometimes had geom, not geometry, which meant
#       st_area() and get_nhdphr() could fail silently or give malformed inputs.
# ✔️ Fix that worked: You explicitly renamed and reassigned the geometry column.
#
# ✅ Why Your New Version Works
#     🔁 AOI cleaned with st_union()
#     🌐 Correct CRS (EPSG:4326)
#     📏 Optional buffering to ensure area isn’t clipped
#     🧼 Only 1 region at a time
#     🛡 is.null() check prevents writing garbage

retry_failed_aoi <- function(region_name, ecoregion_sf, buffer_dist = 1000) {
  message(glue::glue("🔄 Retrying download: {region_name}"))
  
  # Extract and simplify AOI geometry
  region_data <- ecoregion_sf %>%
    filter(us_l4name == region_name)
  
  region_union <- st_union(st_geometry(region_data)) %>%
    st_sf(us_l4name = region_name, geometry = .) %>%
    st_transform(5070) %>%
    st_buffer(buffer_dist)
  
  message(glue::glue("⏳ Trying buffer_dist = {buffer_dist} meters..."))
  
  try_result <- tryCatch({
    nhdV2_gp <- get_nhdplus(
      AOI = region_union,
      realization = "all",
      streamorder = 3,
      t_srs = 5070
    )
    
    # Determine what we got back
    msg_class <- paste(class(nhdV2_gp), collapse = ", ")
    message(glue::glue("📦 Download result class: {msg_class}"))
    
    # If it's a list, try extracting an sf component
    if (is.list(nhdV2_gp) && any(sapply(nhdV2_gp, inherits, "sf"))) {
      # Pick the first valid sf object
      nhd_sf <- nhdV2_gp[sapply(nhdV2_gp, inherits, "sf")][[1]]
    } else if (inherits(nhdV2_gp, "sf")) {
      nhd_sf <- nhdV2_gp
    } else {
      nhd_sf <- NULL
    }
    
    # Handle result
    if (is.null(nhd_sf) || nrow(nhd_sf) == 0) {
      tibble(
        region = region_name,
        status = "error",
        message = "Download returned NULL or no valid features"
      )
    } else {
      nhd_sf <- st_make_valid(nhd_sf)
      
 #     gpkg_path <- glue::glue(
 "data/intermediate/nhdphr_by_ecoregion/{str_replace_all(region_name, ' ', '_')}.gpkg")

      safe_name <- region_name %>%
        stringr::str_replace_all("[ /]", "_")  # replace both space and slash
      
      gpkg_path <- glue::glue(
        "data/intermediate/nhdphr_by_ecoregion/{safe_name}.gpkg")
      
      
            if (file.exists(gpkg_path)) file.remove(gpkg_path)
      
      st_write(nhd_sf, gpkg_path, delete_dsn = TRUE, quiet = TRUE)
      message(glue::glue("✅ Saved: {region_name}"))
      
      tibble(
        region = region_name,
        status = "success",
        message = glue::glue("Downloaded with buffer = {buffer_dist}")
      )
    }
    
  }, error = function(e) {
    tibble(
      region = region_name,
      status = "error",
      message = conditionMessage(e)
    )
  })
  
  return(try_result)
}


# --- this is a manual approach to the function ---
# aoi_broken_red <- eco_lev4 %>%
#   filter(us_l4name == "Broken Red Plains") %>%
#   st_union() %>%
#   st_sf() %>%
#   st_transform(4326)  # required CRS for get_nhdphr()
#
# aoi_broken_red_buf <- st_buffer(
#   aoi_broken_red, dist = 1)  # buffer by 1 degree (~100 km)
#
# nhd_broken_red <- get_nhdphr(
#   AOI = aoi_broken_red_buf,
#   type = "networknhdflowline",   # or "catchmentsp", etc.
#   t_srs = 5070                   # project to CONUS Albers
# )
#
# out_path <- "data/intermediate/nhdphr_by_ecoregion/Broken_Red_Plains.gpkg"
# if (!is.null(nhd_broken_red)) {
#   st_write(nhd_broken_red, out_path, delete_dsn = TRUE)
# } else {
#   message("Download returned NULL for Broken Red Plains.")
# }

# --- Setup -------------------------------------------------------------------

# Load EPA Level IV ecoregions (should be already subset to Great Plains)
eco_lev4 <- st_read(
  "data/raw/vector_raw/ecoregions_unprojected/us_eco_lev4_GreatPlains_geographic.gpkg")

# Ensure folders exist
dir_create("data/intermediate/nhdphr_by_ecoregion")
dir_create("data/log")

log_file <- "data/log/nhdphr_download_log.csv"

# Initialize log file if needed
if (!file_exists(log_file)) {
  write_csv(
    tibble(
      us_l4name = character(),
      status = character(),
      message = character(),
      timestamp = character()
    ),
    log_file
  )
}

# Read existing log
log_tbl <- read_csv(log_file, show_col_types = FALSE)

# Get all distinct L4 names
eco_list <- eco_lev4 %>%
  st_drop_geometry() %>%
  distinct(us_l4name) %>%
  pull(us_l4name)

# --- Main Loop --------------------------------------------------------------

walk(eco_list, function(l4name) {
  message("Processing: ", l4name)
  
  # Sanitize filename
  safe_name <- str_replace_all(l4name, "[^A-Za-z0-9]+", "_")
  out_path <- glue("data/intermediate/nhdphr_by_ecoregion/{safe_name}.gpkg")
  
  # Skip if already marked as successful
  if (l4name %in% log_tbl$us_l4name && any(log_tbl$status[log_tbl$us_l4name == l4name] == "success")) {
    message("Already downloaded: ", l4name)
    return(NULL)
  }
  
  tryCatch({
    
    # Build buffered AOI in EPSG:5070
    eco_aoi <- eco_lev4 %>%
      filter(us_l4name == l4name) %>%
      st_union() %>%
      st_sf(geometry = .) %>%
      st_cast("POLYGON") %>%
      mutate(area = st_area(.)) %>%
      arrange(desc(area)) %>%
      slice(1) %>%
      st_buffer(1) %>%
      st_transform(5070)
    
    # Download NHDPlusHR flowlines
    nhd <- get_nhdphr(
      AOI = eco_aoi,
      type = "networknhdflowline",
      t_srs = 5070
    )
    
    # Ensure old file doesn't block write
    if (file_exists(out_path)) file_delete(out_path)
    
    # Write to disk
    st_write(nhd, out_path, quiet = TRUE)
    
    # Log success
    write_csv(
      tibble(
        us_l4name = l4name,
        status = "success",
        message = NA_character_,
        timestamp = as.character(Sys.time())
      ),
      log_file,
      append = TRUE
    )
    
    Sys.sleep(5)  # Respect server load
    
  }, error = function(e) {
    message("Error for: ", l4name, " — ", e$message)
    
    # Log error
    write_csv(
      tibble(
        us_l4name = l4name,
        status = "error",
        message = as.character(e$message),
        timestamp = as.character(Sys.time())
      ),
      log_file,
      append = TRUE
    )
  })
})

# --- Retry files that did not successfully download --------------------------

log_tbl <- read_csv("data/log/nhdphr_download_log.csv", show_col_types = FALSE)

failed_regions <- log_tbl %>%
  filter(status == "error") %>%
  distinct(us_l4name) %>%
  pull(us_l4name)

# Retry download for failed regions
walk(failed_regions, function(l4name) {
  message("Retrying: ", l4name)
  
  safe_name <- str_replace_all(l4name, "[^A-Za-z0-9]+", "_")
  out_path <- glue("data/intermediate/nhdphr_by_ecoregion/{safe_name}.gpkg")
  
  tryCatch({
    
    if (file_exists(out_path)) file_delete(out_path)
    
    eco_aoi <- eco_lev4 %>%
      filter(us_l4name == l4name) %>%
      st_union() %>%
      st_sf(geometry = .) %>%
      st_cast("POLYGON") %>%
      mutate(area = st_area(.)) %>%
      arrange(desc(area)) %>%
      slice(1) %>%
      st_buffer(1) %>%
      st_transform(5070)
    
    nhd <- get_nhdphr(
      AOI = eco_aoi,
      type = "networknhdflowline",
      t_srs = 5070
    )
    
    if (is.null(nhd)) {
      stop("Download returned NULL — possibly no features found.")
    }
    
    st_write(nhd, out_path, quiet = TRUE)
    
    write_csv(
      tibble(
        us_l4name = l4name,
        status = "success",
        message = NA_character_,
        timestamp = as.character(Sys.time())
      ),
      "data/log/nhdphr_download_log.csv",
      append = TRUE
    )
    
    Sys.sleep(5)
    
  }, error = function(e) {
    message("Retry failed: ", l4name, " — ", e$message)
    
    write_csv(
      tibble(
        us_l4name = l4name,
        status = "error",
        message = as.character(e$message),
        timestamp = as.character(Sys.time())
      ),
      "data/log/nhdphr_download_log.csv",
      append = TRUE
    )
  })
})

# --- Investigate NULL errors -------------------------------------------------
# Load EPA Level IV ecoregions (should be already subset to Great Plains)
eco_lev4 <- st_read(
  "data/raw/vector_raw/ecoregions_unprojected/us_eco_lev4_GreatPlains_geographic.gpkg")

#Load the log
log_tbl <- read_csv("data/log/nhdphr_download_log.csv", 
                    show_col_types = FALSE) %>%
  janitor::clean_names() %>%
  select(-starts_with("x"))

# Identify regions where the most recent status was an error due to NULL
null_regions <- log_tbl %>%
  filter(status == "error" & str_detect
         (message, "no applicable method for 'st_write' applied to an object of class \"NULL\"")) %>%
  distinct(us_l4name) %>%
  pull(us_l4name)

# check AOIs of NULL returns
null_aois <- eco_lev4 %>%
  filter(us_l4name %in% null_regions) %>%
  group_by(us_l4name) %>%
  summarise(do_union = TRUE, .groups = "drop")  # dissolve to one per region

# --- fix possible issues with name and CRS ---
null_aois <- st_transform(null_aois, crs = 5070)

# Grab current geometry column name
geom_col <- attr(null_aois, "sf_column")

# Rename it to 'geometry'
names(null_aois)[names(null_aois) == geom_col] <- "geometry"
st_geometry(null_aois) <- "geometry"

# make spatial statistics
null_aois <- null_aois %>%
  mutate(
    area_km2 = as.numeric(st_area(geometry)) / 1e6,
    bbox_obj = map(geometry, st_bbox),
    bbox_aspect = map_dbl(bbox_obj, ~ (.x["xmax"] - .x["xmin"]) / (.x["ymax"] - .x["ymin"])),
    bbox_geom = map(bbox_obj, ~ st_as_sfc(.x, crs = st_crs(null_aois))),
    bbox_wkt = map_chr(bbox_geom, st_as_text)
  ) #%>%
#  select(-bbox_obj, -bbox_geom)

# flag slivers
null_aois <- null_aois %>%
  mutate(sliver_flag = bbox_aspect < 0.35 | bbox_aspect > 2.5)

# log summary results
write_csv(st_drop_geometry(null_aois), "data/log/null_aoi_summary.csv")


# Step 1: Create sf object of bounding boxes from bbox_geom
bbox_sf <- null_aois %>%
  mutate(bbox_id = us_l4name) %>%
  pull(bbox_geom) %>%
  map(~ .[[1]]) %>%                      # unwrap sfc to sfg
  st_sfc(crs = st_crs(null_aois)) %>%
  st_sf() %>%
  mutate(us_l4name = null_aois$us_l4name)

# Step 2: QA Plot
ggplot() +
  geom_sf(data = null_aois, aes(fill = sliver_flag), color = "black") +
  geom_sf(data = bbox_sf, fill = NA, color = "red", linetype = "dashed") +
    coord_sf(crs = st_crs(null_aois)) +
  scale_fill_manual(values = c("FALSE" = "gray90", "TRUE" = "tomato"),
                    name = "Sliver?") +
  facet_wrap(~ us_l4name
             #, scales = "free"
             ) +
  theme_minimal(base_size = 10) +
  theme(
    strip.text = element_text(face = "bold", size = 8),
    legend.position = "bottom"
  )

# save results
ggsave("data/log/null_aois_diagnostics_facet_map.png",
       width = 10,
       height = 8,
       dpi = 300
       )

# --- retry NULL returns individually ---
retry_failed_aoi("Broken Red Plains", eco_lev4, buffer_dist = 1)

retry_failed_aoi("Des Moines Lobe", eco_lev4, buffer_dist = 1) # this fails --
# the request found features that were outside of the buffer
retry_failed_aoi("Des Moines Lobe", eco_lev4, buffer_dist = 2)# this fails --
# the request found features that were outside of the buffer
retry_failed_aoi("Des Moines Lobe", eco_lev4, buffer_dist = 3) # works --
# updated function based on results.

retry_failed_aoi("Flint Hills", eco_lev4) # worked at 1000 m
retry_failed_aoi("Loess Flats and Till Plains", eco_lev4) # worked at 1000 m
retry_failed_aoi("Missouri Alluvial Plain", eco_lev4) # worked at 1000 m
retry_failed_aoi("Northern Blackland Prairie", eco_lev4) # worked at 1000 m
retry_failed_aoi("Osage Cuestas", eco_lev4) # worked at 1000 m
retry_failed_aoi("Smoky Hills", eco_lev4) # worked at 1000 m

# updated to handle multipolygons here
retry_failed_aoi("Platte River Valley and Terraces", eco_lev4)

retry_failed_aoi("Sand Hills", eco_lev4)

# ------------------------------------------------------------------------------
# 2.Validate results
# ------------------------------------------------------------------------------

# --- Check for missing regions -----------------------------------------------
expected_names <- sort(unique(eco_lev4$us_l4name))
downloaded_files <- fs::dir_ls("data/intermediate/nhdphr_by_ecoregion/",
                               glob = "*.gpkg")
downloaded_names <- downloaded_files %>%
  fs::path_file() %>%
  str_remove("\\.gpkg") %>%
  str_replace_all("_", " ")

ck_results <- setdiff(expected_names, downloaded_names)
missing_in_data <- setdiff(ck_results, eco_lev4$us_l4name)

# Retry each missing region
retry_results <- purrr::map_dfr(
  ck_results,
  ~ retry_failed_aoi(.x, eco_lev4, buffer_dist = 1000)
)


failed_names <- c(
  "Canadian/Cimarron Breaks",
  "Canadian/Cimarron High Plains",
  "Conchas/Pecos Plains",
  "Mesa de Maya/Black Mesa",
  "Nebraska/Kansas Loess Hills",
  "Southern Blackland/Fayette Prairie",
  "Tewaukon/Big Stone Stagnation Moraine"
)

retry_final <- purrr::map_dfr(failed_names, ~ retry_failed_aoi(.x, eco_lev4))

# Save the results for audit trail
readr::write_csv(retry_results, "data/log/nhdphr_missing_download_attempts.csv")


# ============================================================================== 
# -- Test run to scale and generalize to batch download --
# # 1.1 Read ecoregions
# eco_lev4 <- st_read(
#   "data/raw/vector_raw/ecoregions_unprojected/us_eco_lev4_greatplains_geographic.gpkg"
#   )
#
# # 1.2 Pick first distinct L4 name
# eco_aoi_name <- eco_lev4 %>%
#   st_drop_geometry() %>%
#   select(us_l4name) %>%
#   distinct() %>%
#   slice(1) %>%
#   pull(us_l4name)       # pull() is similar to $. It's mostly useful because
#                         #    it looks a little nicer in pipes.
#
# # Notes on `st_union()` below:
# #    Unioning a set of overlapping polygons has the effect of merging the areas
# #    i.e. the same effect as iteratively unioning all individual polygons
# #    together. Unioning a set of LineStrings has the effect of fully noding and
# #    dissolving the input linework. In this context "fully noded" means that
# #    there will be a node or endpoint in the output for every endpoint or line
# #    segment crossing in the input. "Dissolved" means that any duplicate
# #    (e.g. coincident) line segments or portions of line segments will be reduced
# #    to a single line segment in the output. Unioning a set of Points has the
# #    effect of merging all identical points (producing a set with no duplicates).
# #   -- In this case, it creates a of nodes in lat long to feed to `st_sf()`
# #
# # Notes on `st_sf()` below:
# #    Create sf, which extends data.frame-like objects with a simple feature list 
# #    column.
#
#
# # 1.3 filter ecoregions by that name
# eco_aoi <- eco_lev4 %>%
#   filter(us_l4name == eco_aoi_name) %>%
#   st_union() %>%
#   st_sf(geometry = .) %>%         # Creates an sf, in other words extend
#                                   # data.frame-like objects with a simple
#                                   # feature list column (make geospatial)
#   st_cast("POLYGON") %>%          # explicitly cast geometry of sf object
#   mutate(area = st_area(.)) %>%   # compute area to extract largest object
#       arrange(desc(area)) %>%     # necessary when combining objects to the
#   slice(1)                        # scale of the Great Plains
#
# # 1.4 Check EPSG (should be WGS84 GCS -- EPSG:4326) then buffer and transform
# epsg_ck <- st_crs(eco_aoi) %>%
#   unlist()
#
# eco_aoi_buff <- eco_aoi %>%
# st_buffer(1) %>%                  # buffers out 1 degree ~= 100 km
#   st_transform(4269)
#
# # 1.5 Check EPSG (should be NAD83 GCS -- EPSG:4269)
# epsg_buff_ck <- st_crs(eco_aoi_buff) %>%
#   unlist()
#
# # Quick reality check (visually)
# ggplot() +
#   geom_sf(data = eco_aoi_buff,
#           fill = "gray60",
#           color = "white") +
#   geom_sf(data = eco_aoi,
#           fill = "gray20",
#           color = "white")
#
# nhdphr_gp_flowline <- get_nhdphr(
#   AOI = eco_aoi_buff,
#   type = "networknhdflowline",
#   t_srs = 5070           # Reproject output to CONUS Albers (EPSG:5070)
# )
