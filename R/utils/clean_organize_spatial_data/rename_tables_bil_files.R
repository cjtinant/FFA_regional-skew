# =============================================================================
# Script Name:    rename_tables_bil_files.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-05
# Last Updated:   [yyyy-mm-dd]
# Purpose:        Helper function to rename PRISM tables
#
# Description:
#   - [Step 1: what the function does...]
#   - [Step 2: any side effects, file outputs, or key decisions]
#
# Input: 
#   - [e.g., File paths, data frames, raw XML, etc.]
#
# Output: 
#   - [e.g., A tibble, a CSV, a shapefile, etc.]
#
# Dependencies:
#   - [e.g., xml2, dplyr, terra, fs]
#
# Notes:
#   - Moved function from 01c_download_climate -- do not remembe if this is
#     an active part of the workflow right
# =============================================================================

# Create rename table from bil_files
rename_tbl <- tibble(
  path_raw = bil_files,
  fname_raw = path_file(bil_files)
) %>%
  mutate(
    theme = case_when(
      str_detect(fname_raw, "ppt")   ~ "ppt",
      str_detect(fname_raw, "tmean") ~ "tmean",
      str_detect(fname_raw, "tmax")  ~ "tmax",
      str_detect(fname_raw, "tmin")  ~ "tmin",
      TRUE ~ NA_character_
    ),
    # period = case_when(
    #   str_detect(fname_raw, "annual") ~ "ann",
    #   str_detect(fname_raw, "0[1-9]_bil|10_bil|11_bil|12_bil") ~ str_extract(fname_raw, "(?<=_)[0-9]{2}(?=_bil)"),
    #   str_detect(fname_raw, "_[0-9]{4}_bil") ~ str_extract(fname_raw, "[0-9]{4}"),
    #   TRUE ~ NA_character_
    # ),
    period = case_when(
      str_detect(fname_raw, "annual") ~ "ann",
      
      # Daily: 4-digit DOY-like codes (e.g., _0101_)
      str_detect(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") ~ str_extract(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") %>%
        str_remove_all("_bil") %>%
        str_remove("^_"),
      
      # Monthly: _01_ to _12_, prefix with 'm' for clarity
      str_detect(fname_raw, "_(0[1-9]|1[0-2])_bil") ~ paste0("m", str_extract(fname_raw, "(0[1-9]|1[0-2])"))
    ),
    # period = case_when(
    #   str_detect(fname_raw, "annual") ~ "ann",
    #   str_detect(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") ~ str_extract(fname_raw, "_[0-1][0-9][0-3][0-9]_bil") %>%
    #     str_remove_all("_bil") %>%
    #     str_remove("^_"),
    #   str_detect(fname_raw, "_(0[1-9]|1[0-2])_bil") ~ str_extract(fname_raw, "_(0[1-9]|1[0-2])_bil") %>%
    #     str_remove_all("_bil") %>%
    #     str_remove("^_"),
    #   TRUE ~ NA_character_
    # ),
    unit = case_when(
      theme == "ppt" ~ "mm",
      theme %in% c("tmean", "tmax", "tmin") ~ "C",
      TRUE ~ "unk"
    ),
    fname_clean = paste0(theme, "_", period, "_", unit, ".tif")
  )

# add the `from` and `to` paths
rename_tbl <- rename_tbl %>%
  mutate(
    path_proj = path("data/intermediate/prism_epsg5070", 
                     path_ext_set(fname_raw, "tif")),
    path_renamed = path("data/intermediate/prism_epsg5070", fname_clean)
  )

# rename the files
walk2(rename_tbl$path_proj, rename_tbl$path_renamed, file_move)

# summarise results
rename_summary <- rename_tbl %>%
  mutate(
    # Parse temporal scale
    temporal_scale = case_when(
      str_detect(fname_clean, "_ann_") ~ "annual",
      str_detect(fname_clean, "_m[0-9]{2}_") ~ "monthly",
      str_detect(fname_clean, "_[0-9]{4}_") ~ "daily",
      TRUE ~ "unknown"
    )
  ) %>%
  count(theme, temporal_scale, name = "n_files") %>%
  arrange(theme, temporal_scale)
print(rename_summary)
