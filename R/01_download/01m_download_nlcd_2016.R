# ==============================================================================
# Script Name:     01m_download_nlcd_2016.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-06-23
# Last Updated:    2025-10-01
# Change Log:
# - 2025-07-23     Update header information;
#                  move notes to `script-notes_and_developer-log`.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}; Updated header metadata.
# - 2025-10-01     Add CRS checks. Add sanity checks
#
# Purpose: Reproject, clip and mask NLCD 2016 Land Cover raster.
#
# Workflow Summary:
# 1.   Manually download zipped archive and move to outdir (see notes)
# 2.   Reproject raster to a common CRS (US Albers Equal Area – EPSG:5070)
#        for spatial analysis -- using appropriate QA checks
# 4.   Export clipped and masked raster to ~data/processed.
#
# Input/Data URLs:
# - Data are downloaded from https://www.mrlc.gov/data.
# Output:
# Clipped and masked raster projected to a common CRS as INT1U
#   - data/processed/nlcd/nlcd_2016_gp_nn.tif
#                  where `gp` stands for Great Plains and 
#                        `nn` stands for nearest neighbor (resampling)
#
# Dependencies:
# - dplyr:         Data manipulation
# - fs             File system operations
# - sf             Support for simple feature access, a standardized way to
#                  encode and analyze spatial vector data. Binds to 'GDAL'
# - terra          Spatial data analysis-- vector and raster data operations
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# --- Load libraries ---
library(fs)
library(here)
library(sf)
library(terra)

# --- Define file paths -------------------------------------------------------
nlcd_file <- file.path(
  here(), "data", "raw", "nlcd", "Annual_NLCD_LndCov_2016_CU_C1V0.tif")
gpkg_file <- file.path(
  here(), "data", "processed", "us_ecoregions", "us_eco_levels.gpkg")

# --- Read raster and vector --------------------------------------------------
r_nlcd <- rast(nlcd_file)

eco_lev1 <- st_read(gpkg_file, layer = "us_eco_l1", quiet = TRUE)
gp_sf <- eco_lev1[eco_lev1$NA_L1NAME == "GREAT PLAINS", ]

# --- Check raster CRS -- should be EPSG 9982 ---
# Raster: use terra::crs(); EPSG may be NA even if it's Conus Albers-equivalent
r_crs_wkt <- terra::crs(r_nlcd)                 # WKT string
message("Raster CRS (WKT starts): ", substr(r_crs_wkt, 1, 80), "...")

# Vector: st_crs shows EPSG if available
message("Vector CRS (eco_lev1): ", sf::st_crs(eco_lev1)$input %||% "NA")

# --- Transform AOI to match raster CRS (do NOT project the raster) ------------
gp_aea <- sf::st_transform(gp_sf, crs = r_crs_wkt)

# --- Quick raster sanity: type, res, nlyr -------------------------------------
message("NLCD dtype: ", terra::datatype(r_nlcd),
        " | nlyr: ", terra::nlyr(r_nlcd),
        " | res: ", paste(terra::res(r_nlcd), collapse = " x "))

# --- Assert categorical + allowed codes on the SOURCE (fail fast) -------------
allowed_codes <- c(11,12,21,22,23,24,31,41,42,43,52,71,81,82,90,95)

# Must be integer on read; if not, the file is wrong (e.g., confidence layer)
stopifnot(grepl("^INT", terra::datatype(r_nlcd)))

freq0 <- terra::freq(r_nlcd) %>%
  tibble::as_tibble() %>%
  dplyr::rename(code = value, n_pixels = count) %>%
  dplyr::arrange(code)

unexpected0 <- setdiff(unique(freq0$code), allowed_codes)
if (length(unexpected0) > 0L) {
  stop("Source NLCD has non-legend codes: ", paste(unexpected0, collapse = ", "),
       ". Did you point to the *confidence* raster? Use the LandCover file.")
}

# --- Crop + mask (nearest-neighbor by default; no resampling) -----------------
r_gp <- r_nlcd %>%
  terra::crop(terra::vect(gp_aea)) %>%
  terra::mask(terra::vect(gp_aea))

# Grid guard: same CRS/res/origin as source
stopifnot(
  identical(as.character(terra::crs(r_gp)), as.character(terra::crs(r_nlcd))),
  isTRUE(all(abs(terra::res(r_gp) - terra::res(r_nlcd)) < 1e-9)),
  isTRUE(all(abs(terra::origin(r_gp) - terra::origin(r_nlcd)) < 1e-9))
)

# --- Values guard: still integer-like after crop/mask -------------------------
vals <- terra::spatSample(r_gp, size = 1e5, method = "random",
                          na.rm = TRUE, as.points = FALSE, values = TRUE)[,1]
stopifnot(all(abs(vals - round(vals)) < 1e-6))

# --- Write processed as INT1U (0..255), tiled+compressed ----------------------
out_tif <- here::here("data", "processed", "nlcd", "nlcd_2016_gp_nn.tif")
fs::dir_create(fs::path_dir(out_tif))

terra::writeRaster(
  terra::as.int(round(r_gp)),
  filename = out_tif,
  datatype = "INT1U",
  overwrite = TRUE,
  gdal = c("COMPRESS=LZW", "TILED=YES")
)

# Re-open and do a tiny QA on uniques (should match allowed)
r_gp <- terra::rast(out_tif)
stopifnot(grepl("^INT", terra::datatype(r_gp)))

freq_gp <- terra::freq(r_gp) %>%
  tibble::as_tibble() %>%
  dplyr::rename(code = value, n_pixels = count) %>%
  dplyr::arrange(code)

unexpected_gp <- setdiff(unique(freq_gp$code), allowed_codes)
stopifnot(length(unexpected_gp) == 0L)

message("OK: wrote ", out_tif,
        " | unique codes: ", paste(unique(freq_gp$code), collapse = ", "))
