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
    cd_munic = character(0),
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
    "properties.cd_munic",
    "properties.lat_d",
    "properties.long_d"
  )

  if (is.null(features) || !all(required %in% names(features))) {
    return(empty)
  }

  points <- data.frame(
    nm_aglom = features[["properties.nm_aglom"]],
    nm_uf = features[["properties.nm_uf"]],
    cd_munic = features[["properties.cd_munic"]],
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
    "<strong>Codigo municipal:</strong> ",
    htmltools::htmlEscape(df$cd_munic), "<br/>",
    "<strong>Latitude:</strong> ", sprintf("%.5f", df$lat_d), "<br/>",
    "<strong>Longitude:</strong> ", sprintf("%.5f", df$long_d)
  )
}

build_comunidade_submission <- function(nm_aglom, nm_uf, cd_munic, lat_d, long_d) {
  list(
    type = "Feature",
    properties = list(
      lat_d = lat_d,
      long_d = long_d,
      nm_aglom = nm_aglom,
      nm_uf = nm_uf,
      cd_munic = cd_munic
    ),
    geometry = list(
      type = "Point",
      coordinates = list(long_d, lat_d)
    ),
    submitted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    source = "KisangaQ_web"
  )
}

save_comunidade_submission <- function(submission, dir = "data/submissions") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  file_name <- paste0(
    "comunidade_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    sample.int(999999, 1),
    ".json"
  )
  path <- file.path(dir, file_name)

  jsonlite::write_json(
    submission,
    path,
    pretty = TRUE,
    auto_unbox = TRUE
  )

  path
}

comunidade_mailto_uri <- function(submission, json_path) {
  json_text <- jsonlite::toJSON(
    submission,
    pretty = TRUE,
    auto_unbox = TRUE
  )
  subject <- paste("Nova comunidade quilombola:", submission$properties$nm_aglom)
  body <- paste(
    "Segue o JSON de submissao gerado pelo KisangaQ.",
    "",
    as.character(json_text),
    "",
    paste("Arquivo salvo no servidor:", json_path),
    sep = "\n"
  )

  paste0(
    "mailto:rodriguesmsb@gmail.com",
    "?subject=", utils::URLencode(subject, reserved = TRUE),
    "&body=", utils::URLencode(body, reserved = TRUE)
  )
}

mod_comunidades_ui <- function(id) {
  ns <- NS(id)

  div(
    class = "container-fluid py-4 comunidades-page",
    tags$script(HTML("
      Shiny.addCustomMessageHandler('comunidades-mailto', function(message) {
        if (message && message.uri) {
          window.location.href = message.uri;
        }
      });
    ")),
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
        uiOutput(ns("summary")),
        div(
          class = "comunidades-new-community",
          hr(),
          h5("Adicionar comunidade"),
          textInput(
            ns("new_nm_aglom"),
            "Nome da comunidade",
            placeholder = "Nome"
          ),
          selectInput(ns("new_uf"), "UF", choices = NULL),
          textInput(
            ns("new_cd_munic"),
            "Codigo municipal",
            placeholder = "Ex.: 1500800"
          ),
          numericInput(
            ns("new_lat"),
            "Latitude",
            value = NA,
            min = -90,
            max = 90,
            step = 0.000001
          ),
          numericInput(
            ns("new_long"),
            "Longitude",
            value = NA,
            min = -180,
            max = 180,
            step = 0.000001
          ),
          actionButton(
            ns("send_new"),
            "Enviar",
            icon = icon("paper-plane"),
            class = "btn-primary w-100"
          ),
          uiOutput(ns("submit_status"))
        )
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

      ufs <- sort(unique(stats::na.omit(communities()$nm_uf)))
      updateSelectInput(
        session,
        "new_uf",
        choices = c("Selecione" = "", stats::setNames(ufs, ufs)),
        selected = ""
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
          span(class = "comunidades-stat-label", "pontos no mapa")
        ),
        div(
          class = "comunidades-stat",
          span(class = "comunidades-stat-value", format(named, big.mark = ".")),
          span(class = "comunidades-stat-label", "com nm_aglom")
        ),
        div(
          class = "comunidades-stat",
          span(class = "comunidades-stat-value", format(ufs, big.mark = ".")),
          span(class = "comunidades-stat-label", "UFs no filtro")
        )
      )
    })

    submission_status <- reactiveVal(NULL)

    output$submit_status <- renderUI({
      status <- submission_status()
      if (is.null(status)) {
        return(NULL)
      }

      div(
        class = paste("alert mt-3 mb-0", status$class),
        status$message,
        if (!is.null(status$file)) {
          tags$small(class = "d-block mt-1", status$file)
        }
      )
    })

    observeEvent(input$send_new, {
      clean_text <- function(value) {
        if (is.null(value) || length(value) == 0 || is.na(value)) {
          return("")
        }
        trimws(as.character(value[[1]]))
      }
      clean_number <- function(value) {
        if (is.null(value) || length(value) == 0 || is.na(value)) {
          return(NA_real_)
        }
        suppressWarnings(as.numeric(value[[1]]))
      }

      nm_aglom <- clean_text(input$new_nm_aglom)
      nm_uf <- clean_text(input$new_uf)
      cd_munic <- clean_text(input$new_cd_munic)
      lat_d <- clean_number(input$new_lat)
      long_d <- clean_number(input$new_long)

      errors <- character(0)
      if (!nzchar(nm_aglom)) errors <- c(errors, "nome da comunidade")
      if (!nzchar(nm_uf)) errors <- c(errors, "UF")
      if (!nzchar(cd_munic)) errors <- c(errors, "codigo municipal")
      if (!is.finite(lat_d) || lat_d < -90 || lat_d > 90) {
        errors <- c(errors, "latitude valida")
      }
      if (!is.finite(long_d) || long_d < -180 || long_d > 180) {
        errors <- c(errors, "longitude valida")
      }

      if (length(errors) > 0) {
        submission_status(list(
          class = "alert-danger",
          message = paste("Preencha:", paste(errors, collapse = ", "), ".")
        ))
        return()
      }

      submission <- build_comunidade_submission(
        nm_aglom = nm_aglom,
        nm_uf = nm_uf,
        cd_munic = cd_munic,
        lat_d = lat_d,
        long_d = long_d
      )
      json_path <- save_comunidade_submission(submission)
      mailto_uri <- comunidade_mailto_uri(submission, json_path)

      submission_status(list(
        class = "alert-success",
        message = "JSON salvo e email aberto.",
        file = json_path
      ))
      session$sendCustomMessage("comunidades-mailto", list(uri = mailto_uri))

      updateTextInput(session, "new_nm_aglom", value = "")
      updateSelectInput(session, "new_uf", selected = "")
      updateTextInput(session, "new_cd_munic", value = "")
      updateNumericInput(session, "new_lat", value = NA)
      updateNumericInput(session, "new_long", value = NA)
    })

    output$map <- leaflet::renderLeaflet({
      df <- filtered()
      selected <- input$nm_aglom
      selected_one <- !is.null(selected) && nzchar(selected) && selected != all_value
      marker_color <- if (selected_one) "#7A9C38" else "#C8731A"

      map <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
        leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron)

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
