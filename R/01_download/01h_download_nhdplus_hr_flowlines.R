# ==============================================================================
# Script Name:    01h_download_nhdplus_hr_flowlines.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-05-19
# Last Updated:   2025-07-13
#
# Purpose:
# Download and validate NHDPlus HR (1:24k) flowlines clipped to Level IV
# Ecoregions of the Great Plains. Includes retry logic and diagnostics for
# problematic AOIs.
#
# Change Log:
# 2025-07-13 - Recreated script that had potentially been deleted. Updated file
#              paths to avoid data/intermediate. Updated file names to follow
#              a consistent naming pattern. Added reusable naming function,
#              enhanced retry filtering, and CLI feedback.
#
# Workflow Summary:
# 1. Load Great Plains Level IV ecoregions shapefile
# 2. Loop through ecoregions and request NHDPlus HR flowlines (WFS)
# 3. Write each region's result to disk as GeoPackage
# 4. Log success/failure; retry failed regions with `retry_failed_aoi()`
# 5. Diagnose geometry issues (e.g., slivers, complex AOIs)
#
# Output:
# - GeoPackage flowline files: data/raw/nhdphr_flowlines/
# - Log of downloads:          data/log/nhdphr_download_log.csv
# - Diagnostics PNG:           data/log/null_aois_diagnostics_facet_map.png
#
# Data Source:
# https://www.usgs.gov/national-hydrography/nhdplus-high-resolution
#
# Dependencies:
# dplyr, fs, ggplot2, glue, here, nhdplusTools, purrr, readr, sf, stringr,
# units, janitor, cli
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(ggplot2)
  library(glue)
  library(here)
  library(nhdplusTools)
  library(purrr)
  library(readr)
  library(sf)
  library(stringr)
  library(units)
  library(janitor)
  library(cli)
})

# --- Constants ----------------------------------------------------------------
output_dir <- "data/raw/nhdphr_flowlines/"
log_file <- "data/log/nhdphr_download_log.csv"
retry_log_file <- "data/log/nhdphr_retry_log.csv"
null_summary_csv <- "data/log/null_aoi_summary.csv"
null_diag_png <- "data/log/null_aois_diagnostics_facet_map.png"
default_crs <- 5070
default_buffer <- 1000

# --- Ensure output folders exist ----------------------------------------------
dir_create(output_dir)
dir_create("data/log")

# --- Initialize log file if needed --------------------------------------------
if (!file_exists(log_file)) {
  write_csv(tibble(us_l4name = character(),
                   status = character(),
                   message = character(),
                   timestamp = character()), log_file)
}

# --- Region name to filename-safe string --------------------------------------
region_name_to_filename <- function(name) {
  str_replace_all(name, "[^A-Za-z0-9]+", "_")
}

# --- Load ecoregion boundaries ------------------------------------------------
eco_lev4 <- st_read("data/processed/us_ecoregions/us-eco-levels.gpkg",
                    layer = "us_eco_l4", quiet = TRUE)

log_tbl <- read_csv(log_file, show_col_types = FALSE)

# --- Retry logic for failed AOIs ---------------------------------------------
retry_failed_aoi <- function(region_name, ecoregion_sf, buffer_dist = default_buffer) {
  cli::cli_alert_info("🔄 Retrying {.strong {region_name}} with buffer = {buffer_dist} meters")

  region_union <- ecoregion_sf %>%
    filter(us_l4name == region_name) %>%
    st_union() %>%
    st_sf(us_l4name = region_name, geometry = .) %>%
    st_transform(default_crs) %>%
    st_buffer(buffer_dist)

  try_result <- tryCatch({
    nhd <- get_nhdphr(
      AOI = region_union,
      type = "networknhdflowline",
      t_srs = default_crs
    )

    if (is.null(nhd) || nrow(nhd) == 0) {
      cli_alert_danger("❌ Retry failed for {.strong {region_name}} — NULL or no features returned")
      return(tibble(us_l4name = region_name,
                    status = "error",
                    message = "NULL or no features",
                    timestamp = Sys.time()))
    }

    nhd <- st_make_valid(nhd)
    safe_name <- region_name_to_filename(region_name)
    out_path <- glue("{output_dir}{safe_name}.gpkg")

    if (file_exists(out_path)) file_delete(out_path)
    st_write(nhd, out_path, quiet = TRUE)

    cli::cli_alert_success("✅ Retry succeeded for {.strong {region_name}}")

    tibble(us_l4name = region_name,
           status = "retry_success",
           message = glue("Downloaded with buffer = {buffer_dist}"),
           timestamp = Sys.time())

  }, error = function(e) {
    cli::cli_alert_danger("❌ Retry error for {.strong {region_name}} — {e$message}")
    tibble(us_l4name = region_name,
           status = "error",
           message = conditionMessage(e),
           timestamp = Sys.time())
  })

  write_csv(try_result, log_file, append = TRUE)
  return(try_result)
}

# --- Main loop over L4 ecoregions ---------------------------------------------
eco_list <- eco_lev4 %>%
  st_drop_geometry() %>%
  distinct(us_l4name) %>%
  pull()

walk(eco_list, function(l4name) {
  if (l4name %in% log_tbl$us_l4name &&
        any(log_tbl$status[log_tbl$us_l4name == l4name] == "success")) {
    cli::cli_alert_info("⏭️ Skipping already downloaded: {.strong {l4name}}")
    return(NULL)
  }

  cli::cli_alert("⬇️  Downloading {.strong {l4name}}")

  tryCatch({
    eco_aoi <- eco_lev4 %>%
      filter(us_l4name == l4name) %>%
      st_union() %>%
      st_sf(geometry = .) %>%
      st_cast("POLYGON") %>%
      mutate(area = st_area(.)) %>%
      arrange(desc(area)) %>%
      slice(1) %>%
      st_buffer(1) %>%
      st_transform(default_crs)

    nhd <- get_nhdphr(AOI = eco_aoi, type = "networknhdflowline", t_srs = default_crs)

    safe_name <- region_name_to_filename(l4name)
    out_path <- glue("{output_dir}{safe_name}.gpkg")
    if (file_exists(out_path)) file_delete(out_path)
    st_write(nhd, out_path, quiet = TRUE)

    cli::cli_alert_success("✅ Saved flowlines for {.strong {l4name}}")

    write_csv(tibble(us_l4name = l4name,
                     status = "success",
                     message = NA_character_,
                     timestamp = Sys.time()), log_file, append = TRUE)

    Sys.sleep(5)

  }, error = function(e) {
    cli::cli_alert_danger("⚠️  Error for {.strong {l4name}} — {e$message}")
    write_csv(tibble(us_l4name = l4name,
                     status = "error",
                     message = e$message,
                     timestamp = Sys.time()), log_file, append = TRUE)
  })
})

# --- Retry failed downloads ---------------------------------------------------
log_tbl <- read_csv(log_file, show_col_types = FALSE)
failed <- log_tbl %>%
  filter(status == "error") %>%
  distinct(us_l4name) %>%
  pull()

retry_results <- map_dfr(failed, ~ retry_failed_aoi(.x, eco_lev4))
write_csv(retry_results, retry_log_file)

# --- Diagnose NULL results ----------------------------------------------------
null_regions <- retry_results %>%
  filter(status == "error",
         str_detect(message,
                    regex("null|empty|no features",
                          ignore_case = TRUE))) %>%
  pull(us_l4name)

null_aois <- eco_lev4 %>%
  filter(us_l4name %in% null_regions) %>%
  group_by(us_l4name) %>%
  summarise(do_union = TRUE, .groups = "drop") %>%
  st_transform(default_crs)

# Standardize geometry name
geom_col <- attr(null_aois, "sf_column")
names(null_aois)[names(null_aois) == geom_col] <- "geometry"
st_geometry(null_aois) <- "geometry"

# Calculate QA metrics
null_aois <- null_aois %>%
  mutate(
    area_km2 = as.numeric(st_area(geometry)) / 1e6,
    bbox_obj = map(geometry, st_bbox),
    bbox_aspect = map_dbl(bbox_obj, ~ (.x["xmax"] - .x["xmin"]) / (.x["ymax"] - .x["ymin"])),
    bbox_geom = map(bbox_obj, ~ st_as_sfc(.x, crs = st_crs(null_aois))),
    bbox_wkt = map_chr(bbox_geom, st_as_text),
    sliver_flag = bbox_aspect < 0.35 | bbox_aspect > 2.5
  )

write_csv(st_drop_geometry(null_aois), null_summary_csv)

# Create bbox geometry for diagnostics
bbox_sf <- null_aois %>%
  mutate(bbox_id = us_l4name) %>%
  pull(bbox_geom) %>%
  map(~ .[[1]]) %>%
  st_sfc(crs = st_crs(null_aois)) %>%
  st_sf() %>%
  mutate(us_l4name = null_aois$us_l4name)

ggplot() +
  geom_sf(data = null_aois, aes(fill = sliver_flag), color = "black") +
  geom_sf(data = bbox_sf, fill = NA, color = "red", linetype = "dashed") +
  coord_sf(crs = st_crs(null_aois)) +
  scale_fill_manual(values = c("FALSE" = "gray90", "TRUE" = "tomato")) +
  facet_wrap(~ us_l4name) +
  theme_minimal(base_size = 10) +
  theme(strip.text = element_text(face = "bold", size = 8),
        legend.position = "bottom")

ggsave(null_diag_png, width = 10, height = 8, dpi = 300)
