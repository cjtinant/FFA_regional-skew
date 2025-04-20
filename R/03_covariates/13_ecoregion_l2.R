# ==============================================================================
# Script: 13_ecoregion_l2a.R    -- Exploratory--
# Purpose: Explore potential vars related to L1 for predicting station skew.
#
# Author: Charles Jason Tinant 
# Date Created: April 2025
#
# Workflow:
# 1. Load Ecoregion level 2 db
# 2. Check ecoregion description in bplant.org (volunteer effort)
#
# Thoughts -- 
# Topography -- use terrain roughness index?

# ==============================================================================

# Load Libraries ---------------------------------------------------------------
library(sf)
library(tidyverse)
library(here)



# Load Data --------------------------------------------------------------------
# Set the path to shapefile
shapefile_path <- "data/us_eco_l2/us_eco_l2.shp"

# Read the shapefile
eco_l2_df <- st_read(shapefile_path) %>%
  janitor::clean_names() %>%
  st_drop_geometry

# pull l1 names --
l1_names <- eco_l2_df %>%
  select(na_l1name) %>%
  distinct()

# filter l2 key based on l1 name == "GREAT PLAINS"
gp_l2_names <- eco_l2_df %>%
  filter(na_l1name == "GREAT PLAINS") %>%
  select(na_l1code, na_l1name,
         na_l2code, na_l2name
         ) %>%
  distinct()

gp_l2_names


# na_l2key
# 1              9.2  TEMPERATE PRAIRIES
# 2  9.3  WEST-CENTRAL SEMIARID PRAIRIES
# 3 9.4  SOUTH CENTRAL SEMIARID PRAIRIES
# 4   9.5  TEXAS-LOUISIANA COASTAL PLAIN
# 5 9.6  TAMAULIPAS-TEXAS SEMIARID PLAIN
# manually develop logic model
logic_model <- tribble(
  ~na_l2name, ~topography, ~climate, ~cover,
  "TEMPERATE PRAIRIES",
  "flat, with gently-rolling hills",          # topo
  "semiarid, subhumid, humid continental",    # climate
  "grasslands with scattered trees",          # cover type
  "WEST-CENTRAL SEMIARID PRAIRIES",
  "flat to tablelands and badlands, with some sand dunes", 
  "semi-arid continental", 
  "short- and mixed-grass prairie",
  "SOUTH CENTRAL SEMIARID PRAIRIES", 
  NA,
  "semi-arid continental to humid subtropical",
  NA
  )


#,
  "TEXAS-LOUISIANA COASTAL PLAIN")
  #,
  NA, # topo
 NA,  # climate
  NA,# cover type
  "TAMAULIPAS-TEXAS SEMIARID PLAIN",
 NA, # topo
 NA,  # climate
 NA # cover type
)

