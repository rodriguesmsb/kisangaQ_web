# =============================================================================
# helpers_comunidades.R - Shared readers for quilombola community data
# =============================================================================

resolve_comunidades_points_path <- function(path) {
  candidates <- unique(c(
    path,
    "data/stories/story_001_quilombola_comunities/comunidades_quilombola.json"
  ))
  existing <- candidates[file.exists(candidates)]

  if (length(existing) == 0) {
    return(NA_character_)
  }

  existing[[1]]
}

read_comunidades_points <- function(path = "data/comunidades_quilombola.json") {
  empty <- data.frame(
    nm_aglom = character(0),
    nm_uf = character(0),
    nm_munic = character(0),
    bioma = character(0),
    lat_d = numeric(0),
    long_d = numeric(0),
    status_fundiario = character(0),
    stringsAsFactors = FALSE
  )

  path <- resolve_comunidades_points_path(path)

  if (is.na(path)) {
    return(empty)
  }

  geojson <- jsonlite::fromJSON(path, flatten = TRUE)
  features <- geojson[["features"]]
  required <- c(
    "properties.nm_aglom",
    "properties.nm_uf",
    "properties.nm_munic",
    "properties.bioma",
    "properties.lat_d",
    "properties.long_d"
  )

  if (is.null(features) || !all(required %in% names(features))) {
    return(empty)
  }

  if ("properties.dados_pe14" %in% names(features)) {
    status_fundiario <- features[["properties.dados_pe14"]]
  } else {
    status_fundiario <- rep(NA_character_, nrow(features))
  }

  points <- data.frame(
    nm_aglom = features[["properties.nm_aglom"]],
    nm_uf = features[["properties.nm_uf"]],
    nm_munic = features[["properties.nm_munic"]],
    bioma = features[["properties.bioma"]],
    lat_d = as.numeric(features[["properties.lat_d"]]),
    long_d = as.numeric(features[["properties.long_d"]]),
    status_fundiario = status_fundiario,
    stringsAsFactors = FALSE
  )

  points$nm_aglom <- trimws(points$nm_aglom)
  points$nm_aglom[!nzchar(points$nm_aglom)] <- NA_character_
  points <- points[is.finite(points$lat_d) & is.finite(points$long_d), ]
  rownames(points) <- NULL

  points
}
