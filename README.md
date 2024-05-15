
<!-- README.md is generated from README.Rmd. Please edit that file -->
<!-- 
# Next steps
-- update README
-- add dissertation to OLC Sharepoint
-- Apply a spatial join to select gages 
&#10;# Datasets
-- peak-flow sites in the Northern Great Plains and High Plains level-3 ecoregions with greater than 20-years of record
-- State boundaries
-- plant hardiness map (for temps)
-- level-3 ecoregions
&#10;# Helpful websites:
-- [USEPA level-3 and level-4 ecoregions](https://www.epa.gov/eco-research/level-iii-and-iv-ecoregions-continental-united-states)
&#10;-- metadata available from: http://ecologicalregions.info/htm/level_iii_iv.htm
&#10;## Github issues
[GIT short course]https://carpentries-incubator.github.io/git-Rstudio-course/
[GIT issues](https://dangitgit.com/)
-->

# FFA_regional-skew

<!-- badges: start -->
<!-- badges: end -->

## Overview

Regional skew coefficients are necessary to determine flood frequency
following [Bulletin 17C](https://pubs.usgs.gov/publication/tm4B5)
guidelines. The goal of FFA_regional-skew is to estimate a regional skew
coefficients for stream gages in the Northwestern Great Plains and
northern portion of the High Plains sections of the Great Plains within
southeastern Montana, eastern Wyoming, northeastern Colorado, and the
western portions of Nebraska and the Dakotas.

<!--
&#10;the [level-3 ecoregions](https://www.epa.gov/eco-research/level-iii-and-iv-ecoregions-continental-united-states) for peak flow gages in 
&#10;West-central Prairie ecoregion **add link to level 3 ecoregion maps**. 
&#10;-->

## Study Area

<!--
Bounding box needs to extend further south than the Nebraska border
-->

The study area encompasses the Northwestern Great Plains and the
northern portion of the High Plains ecoregion. Northwestern Great Plains
ecoregion encompasses the Missouri Plateau section of the Great Plains
in southeastern Montana, northeastern Wyoming, and the western portion
of the Dakotas. The northern portion of the High Plains ecoregion
encompasses southeastern Wyoming, western Nebraska, eastern Colorado,
and western Kansas
(<http://www.cec.org/files/documents/publications/10415-north-american-terrestrial-ecoregionslevel-iii-en.pdf>).

The study area is a dry mid-latitude steppe climate marked by hot
summers and cold winters, and a mean annual temperature varying by
latitude.

<!--
The mean annual temperature of the Northwestern Great Plains ranges from of approximately $5C$ in some northern areas to 8.5C in the south. 
The mean annual temperature of the High Plains ranges from approximately 8C in the north to 17C in the far south. 
&#10;Northwestern Great Plains--The frost-free period ranges from 90 days to 155 days. The mean annual precipitation is 393 mm, ranging from 250 to 510 mm."
&#10;High Plains--The frost-free period ranges from 120 to 230 days. The mean annual precipitation is 433 mm, and ranges from 305 to 530 mm.
&#10;NGP Vegetation: Grasslands persist in rangeland areas, especially on broken topography, but have been replaced by cropland on some areas of level ground. Shortgrass and mixedgrass prairies contain blue grama, western wheatgrass, green needlegrass, prairie sandreed, and buffalograss. There are areas of sagebrush steppe with fringed sage, Wyoming big sagebrush, rabbitbrush, and sand sagebrush; some areas have scattered ponderosa pine and Rocky Mountain juniper.
&#10;HP Vegetation: Historically, the region had mostly short and midgrass prairie vegetation; much of it is now greatly altered. Shortgrass prairie featured blue grama, buffalograss, and fringed sage, and mixed grass areas had sideoats grama, western wheatgrass, and little bluestem. Sandsage prairies had sand sagebrush, sand bluestem, prairie sandreed, little bluestem, Indian ricegrass, and sand dropseed. Shinnery sands areas in the south featured Havard shin oak, fourwing saltbush, sand sagebrush, yucca, and mid- and shortgrasses.
&#10;NGP Hydrology: Mostly ephemeral and intermittent streams are found here, with a few larger perennial rivers that cross the region from the western mountains. Many small impoundments occur, and there are some large reservoirs on the Missouri River.
&#10;HP Hydrology: Mostly intermittent and ephemeral streams prevail here. A few larger rivers that originate in the Southern Rockies (6.2.14) cross the region, such as the Platte, Arkansas, and Cimarron. The southern portion has few to no streams. Surface water there occurs in numerous ephemeral pools or playas. These serve as recharge areas for the important Ogallala Aquifer. Water withdrawals from the aquifer usually exceed recharge, however.
&#10;NGP Terrain: The region is an unglaciated, rolling plain of shale and sandstone punctuated by occasional buttes. Some areas are of dissected, badland terrain and river breaks. Entisols, Mollisols, Aridisols, and Inceptisols occur. Frigid and mesic soil temperature regimes and ustic and aridic soil moisture regimes are typical.
&#10;NGP Land Use/Human Activities: The region's grassland and shrubland are used for livestock grazing, mostly of cattle and sheep. Agriculture is restricted by the erratic precipitation and limited opportunities for irrigation. Some areas grow wheat, alfalfa, and barley. A few areas are used for coal mining. Larger settlements include Billings, Lewiston, Livingston, Miles City, Dickinson, Mandan, Belle Fourche, Pierre, Rapid City, Sheridan, Gillette, and Casper.
-->

``` r

# Make a map
# Here is some example code:
# https://www.r4wrds.com/intro/m_intro_mapmaking
```

# Introduction

Ecoregion membership was identified as a key predictor of hydrologic
similarity in south-central South Dakota (Tinant, PhD dissertation).
