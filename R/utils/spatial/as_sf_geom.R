# ==============================================================================
# Script Name:     as_sf_geom.R
# Purpose:         Assert CRS and 'geom' name for geometry
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-04
# Last Updated:    2025-10-04
# Change Log:
# - 2025-10-04     Initial commit
#
# Example:
# # gp_union_5070_sf <- as_sf_geom(gp_union_5070_sfc, geom_name = "geom")

# User Inputs:
# - Target CRS from another spatial object
# - Name for geometry column (always use "geom")

# ==============================================================================

as_sf_geom <- function(x, crs = NULL, geom_name = "geom") {
  if (!inherits(x, "sf")) x <- sf::st_sf(geom = x)
  if (!is.null(crs)) x <- sf::st_transform(x, crs)
  sf::st_geometry(x) <- geom_name
  x
}
