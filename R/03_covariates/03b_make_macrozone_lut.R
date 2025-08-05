# ==============================================================================
# Script Name:     03b_make_macrozone_metadata.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-08-01
# Last Updated:    2025-08-05
# Changelog:
# - 2025-08-01     Create initial script
# - 2025-08-04     Split initial script
# - 2025-08-05     Finalize initial script
#
# Purpose:         This script creates the metadata to delineate Ecoregions into
#                  Tallgrass, Mixed-Grass, and Shortgrass Prairie macrozones.
#                  When possible macrozones are delineated at the Level III (L3)
#                  Ecoregion scale. The L3 designations follow North American
#                  Ecoregion nomenclature (NA_L3CODE), e.g. 9.4.1 refers to:
#                  9 GREAT PLAINS dot 4 SOUTH CENTRAL SEMI-ARID PRAIRIES dot
#                  1 HIGH PLAINS. The 9 dot 4 dot 1 HIGH PLAINS NA_L3CODE also
#                  corresponds with United States Level III Ecoregion nomenclature
#                  (US_L3CODE) , e.g. 25 High Plains. Macrozones in the central
#                  and southern Great Plains states, i.e. Colorado, Kansas,
#                  Oklahoma, New Mexico, and Texas, exhibit a one to many
#                  cardinality at the L3 scale, and therefore are delineated
#                  at the Level IV (L4) Ecoregion scale. The L4 designations follow
#                  the United States Level III Ecoregion nomenclature (US_L4CODE),
#                  e.g. 25b the Rolling Sand Plains L4 Ecoregion of the High Plains.
#
# Workflow Summary:
# 1. Load L4 Ecoregions for reference.
# 2. Make a look-up table for L3 Ecoregions with a one-to-one cardinality with
#    macrozones at the L3 Ecoregion scale.
# 3. Make a look-up table for L4 Ecoregions with a one-to-many cardinality with
#    macrozones at the L3 Ecoregion scale.
# 4. Join L4 Ecoregions.
# 5. Write results to file.

# Dependencies:
# - tidyverse, here
#
# Related Milestone Reports, Data Dictionaries, and Notes:
# - milestone_03_prepare_covariates.pdf
# - data_dictionary_covariates.pdf
# - script-notes_and_developer-log.pdf
#
# Next Steps:
# ==============================================================================
# --- load libraries ---
library(tidyverse)
library(here)

# ------------------------------------------------------------------------------
# 1. Load L4 Ecoregions for Reference
# ------------------------------------------------------------------------------
# --- make path ---
input_file_name <- "us_eco_levels.gpkg"
input_folder <- here("data", "processed", "us_ecoregions")
input_path <- here(input_folder, input_file_name)

# --- check layers
st_layers(input_path)
layer_name <- "us_eco_l4"

# --- load Level IV ecoregions ---
eco_l4_gp <- st_read(input_path, layer = layer_name) %>%
  filter(NA_L1NAME == "GREAT PLAINS") %>%
  st_drop_geometry() %>%
  select(-area_km2) %>%
  distinct()

# ------------------------------------------------------------------------------
# 2. Make L3 Ecoregion Descriptions
# ------------------------------------------------------------------------------
# --- make look-up table of L3 metadata ---
lut_l3_meta <- tribble(
  ~NA_L3CODE, ~macrozone, ~estimated_koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  "9.2.1", "tallgrass", "Dfb, Dwb", "mostly farmland",
  "low-density streams, wetlands",
  "flat to gently rolling plains composed of glacial moraine",
  "9.2.2", "tallgrass", "Dfb, Dwb",
  "cropland, cottonwood, willow, bur oak, green ash, and elm riparian areas",
  "low density, low-gradient streams; late winter flooding is common",
  "flat to low rolling plains of moraine and lacustrine deposits",
  "9.2.3", "tallgrass", "Dfa, Dwa", "mostly farmland",
  "intermittent and perennial streams, many of which have been channelized",
  "nearly level to gently rolling glaciated till plains and hilly loess plains",
  "9.2.4", "tallgrass", "Dfa, Dwa, Cfa", "mostly farmland, grassland/forest mosiac",
  "perennial streams; in some areas many are channelized",
  "Rolling and irregular plains with loess overlying glacial till in the north",
  "9.4.4", "tallgrass", "Dfa, Dwa", "intact tallgrass prairie",
  "intermittent and perennial streams; low to moderate gradient",
  "Steep terrain with shallow limestone soils; fire-maintained tallgrass remnant",
  "9.5.1", "tallgrass", "Cfb", "cropland",
  "low gradient intermittent and perennial streams; some channelized",
  "Nearly flat coastal plain",
  "9.3.1", "mixed", "BS", "Speargrass, blue grama, and wheatgrass, shrubs, sagebrush",
  "mostly intermittent, some perennial streams; Prairie Potholes",
  "transitional region between 9.2.1 and 9.3.3; terminal glaciation extent",
  "9.3.3", "mixed", "BS", "shortgrass and mixed grass species; sagebrush steppe; scattered ponderosa pine and Rocky Mountain juniper",
  "mostly ephemeral and intermittent streams",
  "Rolling shale-sandstone plain with occasional buttes; Badlands and river breaks",
  "9.3.4", "mixed", "BS", "grass-stabilized sand dunes; mid and tallgrass prairie",
  "lakes and wetlands common; a lack of streams",
  "rolling to steep, irregular sand dunes"
)  %>%
  mutate(eco_level = "L4")

# ------------------------------------------------------------------------------
# 3. Make L4 Ecoregion Descriptions
# ------------------------------------------------------------------------------
# --- High Plains Level III Ecoregion ---
l4_us25_high_plains_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # 25a Pine Ridge Escarpment
  "25a", "shortgrass", "BSk", "buffalo grass, blue gramma, galleta; mostly rangeland",
  "intermittent streams; perennial rivers",
  "diverse from gently sloping to very steep",
  # 25b Rolling Sand Plains
  "25b", "mixed", "Cfa",
  "rangeland; sandsage association: Havard shin oak, big sandreed, little bluestem, sand dropseed",
  "low drainage density; occasional intermittent or spring fed streams",
  "sandy undulating plains with small scattered areas of active sand dunes",
  # 25c Moderate Relief Rangeland
  "25c", "shortgrass", "Cfa", "mixed-grass in north; shortgrass in south",
  "mostly intermittent streams",
  "moderate slope irregular loess and colluvial plains",
  # 25d Flat to Rolling Cropland
  "25d", "mixed", "Cfa", "mixed-grass in north; shortgrass in south",
  "mostly intermittent streams",
  "flat to rolling loess plains",
  # 25e Canadian-Cimarron High Plains
  "25e", "shortgrass", "Cfa",
  "Short and sandsage prairie: blue, black, and hairy grama, buffalograss, silver bluestem",
  "intermittent or spring fed streams",
  "nearly level to rolling plains dissected by stream channels; some aeolean deposits",
  # Scotts Bluff and Wildcat Hills
  "25f", "shortgrass", "BSk", "ponderosa and lumber pine",
  "likely intermittent to ephemeral",
  "Steep slopes, escarpments, river breaks, slump areas; calcareous soils",
  # 25g Sandy and Silty Tablelands
  "25g", "shortgrass", "BSk", "gramma and buffalo grass; mesquite-buffalo grass",
  "likely ephemeral due to deep permeable soils",
  "tablelands; fine to loamy sands interspersed with lamellae",
  # 25h North and South Platte Valley and Terraces
  "25h", "shortgrass", "BSk", "mostly croplands;grasslands, wet meadows",
  "shallow streams; braided channels",
  "wide alluvial valleys",
  # 25i Llano Estacado
  "25i", "shortgrass", "BSk",
  "blue, black, and hairy grama, buffalograss, silver bluestem, sideoats grama, western wheatgrass",
  "few permanant streams; surface water in numerous ephemeral pools or playas",
  "flat expansive plateau; mesas, tablelands",
  # 25j Shinnery Sands
  "25j", "shortgrass", "BSk or BSh",
  "sand shinnery oak shrubs",
  "low drainage density; occasional intermittent or spring fed streams",
  "sand hills and dunes as well as flat sandy recharge areas",
  # 25k Arid Llano Estacado
  "25k", "shortgrass", "BSk; transitional to Chihauhuan desert",
  "rangeland ;gramma and buffalo grass, silver bluestem, sand dropseed, threeawn",
  "few to no streams, surface water in numerous ephemeral pools",
  "level, elevated plain, decreasing in elevation from west to east",
  # 25l Front Range Fans
  "25l", "shortgrass", "BSk", "gramma and buffalograss",
  "cooler streams, perhaps intermittent to perannial",
  "higher elevation; aluvial fans, terraces, and benches; outwash gravels")

# --- Southwestern Tablelands Level III Ecoregion ---
l4_us26_sw_tablelands_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # 26a Canadian/Cimarron Breaks
  "26a", "mixed", "BSk",
  "gramma buffalo grass, little and big bluestem",
  "streams intermittent or spring fed, salty and sometimes turbid",
  "Tablelands, terraces, and broken topography",
  # 26b Flat Tablelands and Valleys
  "26b", "mixed", "BSk; transition from subhumid (C) to semiarid (BS) climate",
  "cultivated agriculture; rangelands",
  "Intermittent streams and meandering rivers w broad sandy channels, high sediment load",
  "Flat to gently rolling valleys and plains; islands of level land between 26c ecoregions",
  # 26c Caprock Canyons, Badlands, and Breaks
  "26c", "shortgrass", "BSk", "Blue grama, buffalo grass",
  "Intermittent or springfed streams",
  "Steep canyons, escarpments, rounded badlands, and dissected river breaks",
  # 26d Semiarid Canadian Breaks
  "26d", "mixed", "BSk", "Sideoats, black, and blue grama, sand dropseed,
buffalograss, western wheatgrass, galleta, alkali sacaton, and fringed sagewort",
  "streams intermittent or spring fed, salty, and sometimes turbid",
  "Tablelands, terraces, and broken topography bordering Canadian River and
tributary canyons",
  # 26e Piedmont Plains and Tablelands
  "26e", "shortgrass", "BSk",
  "blue grama, green needlegrass, buffalograss, needle-and-thread, red threeawn",
  "intermittent with a few perennial streams",
  "Irregular and dissected plains",
  # 26f Mesa de Maya/Black Mesa
  "26f", "shortgrass", "BSk",
  "Shortgrass prairie intergrades with Rocky Mnt foothills Pinyon-juniper woodland",
  "spring-fed perennial streams often disappearing into alluvium",
  "broad basaltic mesa, knobs, dissected plains with deep canyons; steep slopes common",
  # 26g Purgatoire Hills and Canyons
  "26g", "shortgrass", "BSk",
  "Pinyon-juniper woodland and shortgrass prairie",
  "perhaps intermittent",
  "dissected plains and tablelands with some hills, steep canyons, and rock outcrops",
  # 26h Pinyon-Juniper Woodlands and Savannas ecoregion
  "26h", "shortgrass", "BSk",
  "Pinyon-juniper woodlands; some montaine coniferous forest",
  "perhaps intermittent",
  "dissected plains and tablelands with some scattered ridges and hills",
  # 26i Pine-Oak Woodlands
  "26i", "mixed", "BSk",
  "pine-oak woodlands; big and little bluestem, Montana and western wheatgrass, sideoats grama",
  "perhaps intermittent",
  "dissected plains and hills",
  # 26j Foothill Grasslands
  "26j", "mixed", "BSk",
  "indiangrass, big and little bluestem, switchgrass, fescues, ponderosa pine, Gambel oak",
  "perhaps intermittent",
  "dissected and irregular plains",
  # 26k Sand Sheets
  "26k", "shortgrass", "BSk",
  "sandsage prairie: sand sagebrush, sand bluestem, prairie sandreed, blowout grass, little bluestem",
  "perhaps ephemeral",
  "rolling plains with stabilized sand sheets and areas of low sand dunes",
  # 26l Upper Canadian Plateau
  "26l", "shortgrass", "BSk",
  "shortgrass prairie, some midgrass prairie, scattered juniper savanna and woodland",
  "perhaps intermittent to ephemeral",
  "heterogeneous; influenced by proximity to mountainous regions",
  # 26m Canadian Canyons
  "26m", "shortgrass", "BSk",
  "pinyon pine, one-seed juniper, and some ponderosa pine at higher elevations",
  "perhaps intermittent to ephemeral",
  "canyon lands",
  # 26n Conchas/Pecos Plains
  "26n", "shortgrass", "BSk",
  "rangelands; blue grama, galleta, sand dropseed, threeawns, ring muhly",
  "perhaps intermittent to ephemeral",
  "broad, rolling plains, tablelands, and piedmonts",
  # 26o Central New Mexico Plains
  "26o", "shortgrass", "BSk", "rangelands; shortgrass steppe, some mixed-grass prairie",
  "perhaps intermittent to ephemeral",
  "perhaps broad, rolling plains",
  # 26p Pluvial Lake Basins
  "26p", "shortgrass", "BSk", "fourwing saltbush and alkali sacaton",
  "lake basins annual evaporation greater than annual precipitation",
  "large closed lake basins",
  # 26q Southern New Mexico Dissected Plains
  "26q", "shortgrass", "BSk; transitional with Chihuahuan Desert grasslands",
  "blue grama, black grama, hairy grama, sideoats grama, triden, threeawn",
  "perhaps intermittent to ephemeral",
  "well-dissected topography with numerous draws and shallow canyons")

# --- Central Great Plains Level III Ecoregon ---
l4_us27_central_plains_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # 27a Smoky Hills
  "27a", "mixed", "Cfa", "cropland; winter wheat",
  "perhaps intermittent to perennial",
  "undulating to hilly dissected plain",
  # 27b Rolling Plains and Breaks
  "27b", "mixed", "Cfa",
  "big and little bluestem, blue and side-oats grama, needle-and-thread, western wheatgrass",
  "perhaps intermittent to perennial",
  "dissected plains with broad undulating ridge tops and hilly to steep valley sides",
  # Great Bend Sand Prairie
  "27c", "mixed", "Cfa",
  "cropland; winter wheat, sorghum, alfalfa; sand prairie-bunch grasses",
  "perhaps intermittent",
  "undulating to rolling sandy plains, dune areas",
  # 27d Prairie Tableland
  "27d", "mixed-grass", "Cfa",
  "cropland; winter wheat; big and little bluestem, indiangrass, switchgrass",
  "perennial streams and numerous springs ,intermittent (type-F) low-gradient streams",
  "flat alluvial lowlands",
  # 27e Central Nebraska Loess Plains
  "27e", "mixed", "Cfa",
  "rangeland, some cropland; big and little bluestem, sideoats and blue grama, western wheatgrass",
  "perennial and intermittent streams",
  "rolling dissected plains with deep loess layer",
  # 27f Rainwater Basin Plains
  "27f", "tallgrass", "Cfa",
  "transitional: tallgrass prairie to the east and mixedgrass prairie in the west",
  "historically, extensive rainwater basins, and wetlands",
  "flat to gently rolling loess-covered plains",
  # 27g Platte River Valley
  "27g", "tallgrass", "Cfa",
  "lowland tallgrass prairie with areas of wet meadow and marsh",
  "shallow, interlacing streams on a sandy bed",
  "flat, wide alluvial valley",
  # 27h Red Prairie
  "27h", "mixed", "Cfa",
  "cropland, rangeland; wheat, sorghum, alfalfa; mesquite–buffalograss, shinnery",
  "Streams largely intermittent. Larger braided rivers with high sediment load",
  "level to rolling plain",
  # 27i Broken Red Plains
  "27i", "shortgrass", "Cfa or BSk",
  "rangeland, cropland; mesquite–buffalograss; mesquite shrublands",
  "streams largely intermittent; larger rivers meandering, turbid",
  "dissected plain, cuesta topography",
  # 27j Limestone Plains
  "27j", "shortgrass", "BSk",
  "shortgrass to mixed-grass: buffalograss, little and silver bluestem, sideoats grama",
  "most streams intermittent",
  "rolling plains with some low hills or ridges",
  # 27k Wichita Mountains
  "27k", "shortgrass", "Cfa or BSk",
  "post and blackjack oak woodlands; short grasses and scattered prickly pear",
  "gravel and cobble substrates; distinct stream assemblages and water quality",
  "high relief granite-gabbro mountainous region with rocky outcrops",
  # 27l Pleistocene Sand Dunes
  "27l", "shortgrass", "Cka or BSk",
  "sand sagebrush–bluestem prairie; oak savanna",
  "lack well-developed drainage networks; high water tables, abundant springs",
  "active, barren, or stabilized Pleistocene Sand Dunes found along major rivers",
  # 27m Red River Tablelands
  "27m", "shortgrass", "Cka or BSk",
  "irrigated cropland; mesquite–buffalograss; some mixed-grass prairie; lotebush, ephedra",
  "irrigation water largely derived from solution cavities in underlying gypsum beds",
  "nearly level",
  # 27n Gypsum Hills
  "27n", "mixed", "Cka or BSk",
  "mixed grass prairie and scattered trees",
  "karst; many spring-fed tributaries",
  "karst terraine; breaks, escarpments, gorges, ledges, caves, canyons",
  # 27o Cross Timbers Transition
  "27o", "mixed", "Cka or BSk",
  "rangeland and cropland; transitional prairie-savanna; prairie grasses, eastern redcedar, oak, elm",
  "channelized streams; rocky substrates",
  "rough rugged plains",
  # 27p Salt Plains
  "27p", "shortgrass", "Cka or BSk",
  "barren areas, halophytic vegetation, seapurslane, western seepweed, little bluestem",
  "lakes; may not support good drainage networks",
  "salt flats",
  # 27q Rolling Red Hills
  "27q", "mixed", "Cka or BSk",
  "rangeland, some cropland; mostly mixed-grass, shinnery, shortgrass higher elevation",
  "extensive flood control projects modify regional hydrology; entrenched streams",
  "gently to steeply sloping hills, breaks, gypsum karst",
  # 27r Limestone Hills
  "27r", "shortgrass",  "Cka or BSk",
  "rangeland",
  "many springs, but no perennial streams, occur",
  "steep, stony, carbonate rocks")

# --- Cross Timbers Level III Ecoregon ---
l4_us29_cross_timbers_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # Northern Cross Timbers
  "29a","tallgrass", "Cka or Cfa",
  "pastureland, cropland; post and blackjack oak, tall grass prairie understory",
  "typically shallow, sandy streams",
  "hills, cuestas, and ridges",
  # 29b Eastern Cross Timbers
  "29b", "tallgrass", "Cka or Cfa",
  "pastureland, cropland; oak savanna, oak forest, eastern redcedar,tallgrass prairie",
  "NA_character_",
  "rolling hills, cuestas, and ridges ",
  # 29c Western Cross Timbers
  "29c", "tallgrass", "Cka or Cfa",
  "pastureland, cropland; oak savanna, scrubby oak forest, and prairie",
  "NA_character_",
  "rolling hills, cuestas, and ridges",
  # 29d Grand Prairie
  "29d", "tallgrass", "Cka or Cfa",
  "cropland, pastureland American elm, hackberry, pecan, tall grass prairie uplands",
  "incised, meandering streams",
  "nearly level to rolling",
  # 29e Limestone Cut Plain
  "29e", "mixed", "BSk",
  "shrubland, grassland, and woodland; Mid-tall grassland: big and little bluestem, indiangrass, tall dropseed, sideoats grama",
  "headwater streams in narrow canyons, lower reaches in broader valleys, springs common",
  "benched or stairstep topography, capped mesas, eroded sideslopes, broad flat valleys",
  # 29f Carbonate Cross Timbers
  "29f", "mixed", "BSk",
  "Oak forest upland; sideoats grama, big and little bluestem, silver bluestem, switchgrass",
  "low to moderate gradient, turbid streams and rivers",
  "rounded low hills and mountains",
  # 29g Arbuckle Uplift
  "29g", "tallgrass", "Cka or Cfa",
  "cropland, grazing land; tall grass prairie, oak savanna",
  "perannial gravel, cobble, bedrock, coarse sand streams",
  "rolling hills and plains",
  # 29h Northwestern Cross Timbers
  "29h", "tallgrass", "Cka or Cfa",
  "blackjack oak–post oak savanna; tallgrass prairie; sugar maple forest",
  "perannial, spring-fed streams; modified by upstream flood control, channelization",
  "rolling hills",
  # 29i Arbuckle Mountains
  "29i","tallgrass", "Cka or Cfa",
  "post oak–blackjack oak–winged elm woodland",
  "steep, cool, clear, fast-flowing, spring-fed streams, bedrock or gravel substrates",
  "mesic ravines, ledges, caves, sinkholes, springs")

# --- Edwards Plateau Level III Ecoregon ---
l4_us30_edwards_plateau_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # Edwards Plateau Woodland
  "30a", "mixed", "BSk",
  "oak savanna; grassland: little bluestem, indiangrass, sideoats grama",
  "low to moderate gradient streams; bedrock, cobble, gravel, and sandy substrates",
  "elevated plateau; rolling to rounded hills, broad valleys",
  # Llano Uplift
  "30b", "shortgrass", "BSk",
  "oak savanna mixed with mesquite grassland: little bluestem, sideoats grama, Texas wintergrass",
  "low to moderate gradient streams with cobble, boulder, and sandy substrates",
  "flat to rolling terrain punctuated by ridges and bare rock outcrops",
  # Balcones Canyonlands
  "30c", "mixed", "BSk",
  "oak savanna; grasslands: little bluestem, indiangrass, sideoats grama, Texas wintergrass",
  "moderate to high gradient streams with bedrock, cobble, and gravel substrates",
  "dissected plateau and escarpment with stair step topography",
  # Semiarid Edwards Plateau
  "30d","shortgrass", "BSk",
  "little bluestem, buffalograss, forbs, Texas wintergrass, green sprangletop, threeawns",
  "streams mostly ephemeral or intermittent",
  "flat to gently rolling plateau dissected by canyons"
)

# --- Southern Texas Plains Level III Ecoregon ---
l4_us31_southern_texas_plains_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # Northern Nueces Alluvial Plains
  "31a", "mixed", "BSk",
  "cropland, rangeland; Mesquite-acacia savanna, little bluestem, sideoats grama, plains bristlegrass",
  "NA_character_",
  "lighty to moderately dissected irregular plains, broad, gently sloping alluvial fans",
  # Semiarid Edwards Bajada
  "31b", "mixed", "BSk",
  "rangeland; mesquite-acacia-savanna, slim tridens, red grama, purple threeawn, plains bristlegrass",
  "springs and some perennial streams",
  "lightly to moderately dissected irregular plains, with alluvial fans",
  # Texas-Tamaulipan Thornscrub
  "31c", "mixed", "BSk",
  "mesquite-acacia-savanna, some mesquite-live oak savanna, scattered mid and short grasses",
  "NA_character_",
  "lightly to moderately dissected irregular plains",
  # Rio Grande Floodplain and Terraces
  "31d", "mixed", "BSk",
  "woody riparian: hackberry, Mexican ash, cedar, elm, multiflowered false rhodesgrass, sacaton, cottontop, plains bristlegrass",
  "NA_character_",
  "floodplain and narrow terraces"
)

# --- Northern Blackland Prairie Level III Ecoregon ---
l4_us32_northern_blackland_prairie_meta <- tribble(
  ~US_L4CODE, ~macrozone, ~koppen, ~vege_lnd_use, ~hydrology, ~terrain,
  # 32a Northern Blackland Prairie
  "32a", "tallgrass",  "Cka or Cfa",
  "croplands; historically, tallgrass prairie: big and little bluestem, indiangrass",
  "low to moderate gradient streams with silty, clayey, and sandy substrates",
  "irregular plains, lightly to moderately dissected",
  # 32b Southern Blackland Prairie
  "32b", "tallgrass",  "Cka or Cfa",
  "croplands; historically, tallgrass prairie: big and little bluestem, brownseed paspalum",
  "low to moderate gradient streams with silty, clayey, and sandy substrates",
  "irregular plains, lightly to moderately dissected",
  # 32c Floodplains and Low Terraces
  "32c", "tallgrass",  "Cka or Cfa",
  "Bottomland hardwood forest: bur, Shumard, post oak, green ash, pecan, cedar elm",
  "low gradient streams with sand, silt, clay, and gravel substrates",
  "flat floodplains with sloughs, natural levees, and associated alluvial low terraces"
)


# ------------------------------------------------------------------------------
# 4. Join L4 metadata
# ------------------------------------------------------------------------------

lut_l4_composite_meta <- bind_rows(
  l4_us25_high_plains_meta,
  l4_us26_sw_tablelands_meta,
  l4_us27_central_plains_meta,
  l4_us29_cross_timbers_meta,
  l4_us30_edwards_plateau_meta,
  l4_us32_northern_blackland_prairie_meta
  ) %>%
  rename(estimated_koppen = koppen) %>%
  mutate(eco_level = "L4")

# ------------------------------------------------------------------------------
# 5. Write results to file
# ------------------------------------------------------------------------------
# --- make path ---
output_folder <- here("docs", "metadata", "look_up_tables")

output_lev03_file_name <- "ecoregion_l3_metadata_lut.csv"
output_lev04_file_name <- "ecoregion_l4_metadata_lut.csv"

output_lev03_path <- here(output_folder, output_lev03_file_name)
output_lev04_path <- here(output_folder, output_lev04_file_name)

write_csv(lut_l3_meta, output_lev03_path)
write_csv(lut_l4_composite_meta, output_lev04_path)

