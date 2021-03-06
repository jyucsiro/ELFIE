setwd("~/Documents/Projects/ELFIE/ELFIE/data/huc12obs/")
source("../../R/json_ld_functions.R")

catchment_id <- "https://opengeospatial.github.io/ELFIE/usgs/huc/huc12obs/070900020601"

catchment_data <- parse_elfie_json(paste0(catchment_id, ".json"))

realization_ids <- catchment_data$catchmentRealization

get_elfie_docs <- function(x) list(x = parse_elfie_json(paste0(x, ".json")))

realizations <- sapply(realization_ids, get_elfie_docs)
names(realizations) <- realization_ids

for(realization in names(realizations)) {
  rzn <- realizations[realization][[1]]
  if(rzn$`@type` == "http://www.opengeospatial.org/standards/waterml2/hy_features/HY_HydrometricNetwork") {
    print("hydrometric network")
    station_list <- sapply(rzn$networkStation, get_elfie_docs)
    names(station_list) <- rzn$networkStation
    station_geo <- sf::st_sf("geometry" = sf::st_sfc(lapply(station_list, function(x) x$geo)),
                             "name" = sapply(station_list, function(x) x$name),
                             "link" = sapply(station_list, function(x) x$sameAs),
                             "graph" = sapply(station_list, function(x) ifelse(is.null(x$image), "", x$image)),
                             "elfie" = sapply(station_list, function(x) x$`@id`), stringsAsFactors = F)
    rownames(station_geo) <- names(station_list)
    gs <- !station_geo$graph==""
    graph_stations <- station_geo[which(gs),]
    station_geo <- station_geo[which(!gs),]
  } else if(rzn$`@type` == "http://www.opengeospatial.org/standards/waterml2/hy_features/HY_CatchmentDivide") {
    print("divide") 
    divide_geo <- sf::st_sf(name = rzn$name, geometry = sf::st_sfc(rzn$geo), stringsAsFactors = F)
  } else if(rzn$`@type` == "http://www.opengeospatial.org/standards/waterml2/hy_features/HY_HydrographicNetwork") {
    print("hydrographic network")
    network_geo <- sf::st_sf(name = rzn$name, geometry = sf::st_sfc(rzn$geo), stringsAsFactors = F)
  } else {
    stop("got a type that was unexpected. This won't work")
  }
}

station_geo["popup"] <- paste0("<b><a href='", station_geo$link, "' target='_blank'>", station_geo$name, "</a></b><br/>",
                              "<a href='", station_geo$elfie, "' target='_blank'>Source JSON-LD</a>")
                 
graph_stations["popup"] <- paste0("<b><a href='", graph_stations$link, "' target='_blank'>", graph_stations$name, "</a></b><br/>",
                              "<img src='", graph_stations$graph, "alt='hydrograph'><br/>",
                              "<a href='", graph_stations$elfie, "' target='_blank'>Source JSON-LD</a>")


library(magrittr)
m <- leaflet::leaflet() %>%
  leaflet::addTiles() %>%  
  leaflet::addPolygons(data = divide_geo, color = "black", fill = F, opacity = 100) %>%
  leaflet::addPolylines(data = network_geo, opacity = 100) %>%
  leaflet::addMarkers(data = station_geo, popup = station_geo$popup) %>%
  leaflet::addCircleMarkers(data = graph_stations, popup = graph_stations$popup, color = "red", opacity = 75)

htmlwidgets::saveWidget(m, file="../../docs/demo/huc12obs_map.html")
