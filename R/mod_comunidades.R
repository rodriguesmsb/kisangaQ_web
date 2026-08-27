# =============================================================================
# mod_comunidades.R - Leaflet map of quilombola communities
#
# Estrutura:
#   mod_comunidades_ui()     -> sidebar filter + Leaflet map
#   mod_comunidades_server() -> reads GeoJSON, filters by nm_aglom, updates map
# =============================================================================

read_comunidades_points <- function(path = "data/comunidades_quilombola.json") {
  empty <- data.frame(
    nm_aglom = character(0),
    nm_uf = character(0),
    nm_munic = character(0),
    lat_d = numeric(0),
    long_d = numeric(0),
    stringsAsFactors = FALSE
  )

  if (!file.exists(path)) {
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

  points <- data.frame(
    nm_aglom = features[["properties.nm_aglom"]],
    nm_uf = features[["properties.nm_uf"]],
    nm_munic = features[["properties.nm_munic"]],
    bioma = features[["properties.bioma"]],
    lat_d = as.numeric(features[["properties.lat_d"]]),
    long_d = as.numeric(features[["properties.long_d"]]),
    stringsAsFactors = FALSE
  )

  points$nm_aglom <- trimws(points$nm_aglom)
  points$nm_aglom[!nzchar(points$nm_aglom)] <- NA_character_
  points <- points[is.finite(points$lat_d) & is.finite(points$long_d), ]
  rownames(points) <- NULL

  points
}

comunidade_popup <- function(df) {
  name <- ifelse(
    is.na(df$nm_aglom),
    "Comunidade sem nome informado",
    df$nm_aglom
  )

  paste0(
    "<strong>", htmltools::htmlEscape(name), "</strong><br/>",
    "<strong>UF:</strong> ", htmltools::htmlEscape(df$nm_uf), "<br/>",
    "<strong>Codigo municipal:</strong> ", htmltools::htmlEscape(df$nm_munic), "<br/>",
    "<strong>Bioma:</strong> ", htmltools::htmlEscape(df$bioma), "<br/>",
    "<strong>Latitude:</strong> ", sprintf("%.5f", df$lat_d), "<br/>",
    "<strong>Longitude:</strong> ", sprintf("%.5f", df$long_d)
  )
}

mod_comunidades_ui <- function(id) {
  ns <- NS(id)

  div(
    class = "container-fluid py-4 comunidades-page",
    h2("Comunidades Quilombolas"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        title = "Filtro",
        width = 320,
        selectizeInput(
          ns("nm_aglom"),
          "Comunidade",
          choices = NULL,
          options = list(
            placeholder = "Buscar por nm_aglom",
            maxOptions = 100
          )
        ),
        actionButton(
          ns("clear_filter"),
          "Limpar",
          icon = icon("xmark"),
          class = "btn-outline-secondary w-100"
        ),
        hr(),
        uiOutput(ns("summary"))
      ),
      div(
        class = "comunidades-map-panel",
        leaflet::leafletOutput(ns("map"), height = "72vh")
      )
    )
  )
}

mod_comunidades_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    all_value <- "__all__"

    communities <- reactive({
      read_comunidades_points()
    })

    observe({
      names_with_values <- stats::na.omit(communities()$nm_aglom)
      names_with_values <- sort(unique(names_with_values))
      choices <- c("Todas as comunidades" = all_value, stats::setNames(
        names_with_values,
        names_with_values
      ))

      updateSelectizeInput(
        session,
        "nm_aglom",
        choices = choices,
        selected = all_value,
        server = TRUE
      )
    })

    observeEvent(input$clear_filter, {
      updateSelectizeInput(session, "nm_aglom", selected = all_value)
    })

    filtered <- reactive({
      df <- communities()
      selected <- input$nm_aglom

      if (!is.null(selected) && nzchar(selected) && selected != all_value) {
        df <- df[!is.na(df$nm_aglom) & df$nm_aglom == selected, , drop = FALSE]
      }

      df <- df[is.finite(df$lat_d) & is.finite(df$long_d), , drop = FALSE]
      rownames(df) <- NULL
      df
    })

    output$summary <- renderUI({
      df <- filtered()
      named <- sum(!is.na(df$nm_aglom))
      ufs <- length(unique(stats::na.omit(df$nm_uf)))

      div(
        class = "comunidades-summary",
        div(
          class = "comunidades-stat",
          span(class = "comunidades-stat-value", format(nrow(df), big.mark = ".")),
          span(class = "comunidades-stat-label", "número de comunidades")
        ),
        div(
          class = "comunidades-stat",
          span(class = "comunidades-stat-value", format(named, big.mark = ".")),
          span(class = "comunidades-stat-label", "com nome informado")
        ),
        div(
          class = "comunidades-stat",
          span(class = "comunidades-stat-value", format(ufs, big.mark = ".")),
          span(class = "comunidades-stat-label", "UFs no filtro")
        )
      )
    })

    output$map <- leaflet::renderLeaflet({
      df <- filtered()
      selected <- input$nm_aglom
      selected_one <- !is.null(selected) && nzchar(selected) && selected != all_value
      marker_color <- if (selected_one) "#7A9C38" else "#C8731A"

      map <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
        leaflet::addTiles()

      if (nrow(df) == 0) {
        return(
          map |>
          leaflet::setView(lng = -53.2, lat = -14.2, zoom = 4)
        )
      }

      map <- map |>
        leaflet::addCircleMarkers(
          data = df,
          lng = ~long_d,
          lat = ~lat_d,
          radius = if (selected_one) 7 else 4,
          stroke = TRUE,
          color = "#2C1A08",
          weight = 1,
          opacity = 0.8,
          fill = TRUE,
          fillColor = marker_color,
          fillOpacity = 0.75,
          popup = comunidade_popup(df),
          label = ifelse(
            is.na(df$nm_aglom),
            "Sem nome informado",
            df$nm_aglom
          ),
          clusterOptions = leaflet::markerClusterOptions()
        )

      lng_range <- range(df$long_d, na.rm = TRUE)
      lat_range <- range(df$lat_d, na.rm = TRUE)

      if (nrow(df) == 1 || (diff(lng_range) == 0 && diff(lat_range) == 0)) {
        map |>
          leaflet::setView(lng = df$long_d[1], lat = df$lat_d[1], zoom = 12)
      } else {
        map |>
          leaflet::fitBounds(
            lng1 = lng_range[1],
            lat1 = lat_range[1],
            lng2 = lng_range[2],
            lat2 = lat_range[2]
          )
      }
    })
  })
}
