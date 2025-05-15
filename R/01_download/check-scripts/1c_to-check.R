

# ------------------------------------------------------------------------------
# Utility: Build SpatRaster from prism_archive_ls() results

build_prism_rasters <- function(prism_dirs) {
  bil_paths <- file.path(
    prism_get_dl_dir(),
    prism_dirs,
    paste0(basename(prism_dirs), ".bil")
  )
  terra::rast(bil_paths)
}

# ------------------------------------------------------------------------------
# Load & Extract PRISM Rasters to Site Locations

prism_files <- prism_archive_ls()

ppt_dirs   <- prism_files[str_detect(prism_files, "ppt_30yr_normal_4kmM")]
tmean_dirs <- prism_files[str_detect(prism_files, "tmean_30yr_normal_4kmM")]

ppt_rast   <- build_prism_rasters(ppt_dirs)
tmean_rast <- build_prism_rasters(tmean_dirs)

ppt_cov   <- terra::extract(ppt_rast, vect(sites_sf))
tmean_cov <- terra::extract(tmean_rast, vect(sites_sf))

# ------------------------------------------------------------------------------
# Clean & Rename Covariate Data for Modeling

ppt_cov_clean <- ppt_cov %>%
  rename_with(
    ~ str_replace_all(., c(
      "PRISM_ppt_30yr_normal_4kmM4_0" = "ppt_M0",
      "PRISM_ppt_30yr_normal_4kmM4_"  = "ppt_M",
      "_bil" = "_mm"
    )),
    .cols = starts_with("PRISM_ppt")
  ) %>%
  clean_names() %>%
  rename(ppt_ann_mm = ppt_mannual_mm)

tmean_cov_clean <- tmean_cov %>%
  rename_with(
    ~ str_replace_all(., c(
      "PRISM_tmean_30yr_normal_4kmM5_0" = "tmean_M0",
      "PRISM_tmean_30yr_normal_4kmM5_"  = "tmean_M",
      "_bil" = "_C"
    )),
    .cols = starts_with("PRISM_tmean")
  ) %>%
  clean_names() %>%
  rename(tmean_ann_C = tmean_mannual_c)

# ------------------------------------------------------------------------------
# Join Climate Covariates + Site Info

covariates_climate <- sites %>%
  bind_cols(
    ppt_cov_clean %>% select(-id),
    tmean_cov_clean %>% select(-id)
  ) %>%
  relocate(site_no, dec_lat_va, dec_long_va, .before = everything())

# ------------------------------------------------------------------------------
# Export Final Climate Covariates

write_csv(covariates_climate, here("data/clean/data_covariates_climate.csv"))

write_csv(prism_metadata, here("data/meta/data_covariates_climate_metadata.csv"))
write_csv(prism_metadata_spatial, here("data/meta/data_covariates_climate_spatial.csv"))

message("Finished downloading, extracting, and cleaning PRISM climate covariates.")
