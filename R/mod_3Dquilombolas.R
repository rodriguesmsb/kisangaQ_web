# =============================================================================
# mod_3Dquilombolas.R - Data story panel
#
# Estrutura:
#   mod_3Dquilombolas_ui()     -> panel for data-driven stories
#   mod_3Dquilombolas_server() -> reads GeoJSON and builds story summaries
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
    lat_d = numeric(0),
    long_d = numeric(0),
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

  points <- data.frame(
    nm_aglom = features[["properties.nm_aglom"]],
    nm_uf = features[["properties.nm_uf"]],
    nm_munic = features[["properties.nm_munic"]],
    bioma = features[["properties.bioma"]],
    lat_d = as.numeric(features[["properties.lat_d"]]),
    long_d = as.numeric(features[["properties.long_d"]]),
    status_fundiario = features[["properties.dados_pe14"]],
    stringsAsFactors = FALSE
  )

  points$nm_aglom <- trimws(points$nm_aglom)
  points$nm_aglom[!nzchar(points$nm_aglom)] <- NA_character_
  points <- points[is.finite(points$lat_d) & is.finite(points$long_d), ]
  rownames(points) <- NULL

  points
}

historia_number <- function(value) {
  format(value, big.mark = ".", decimal.mark = ",")
}

historia_count <- function(values, n = NULL) {
  values <- trimws(as.character(values))
  values[!nzchar(values)] <- NA_character_
  values <- stats::na.omit(values)

  if (length(values) == 0) {
    return(data.frame(name = character(0), total = integer(0)))
  }

  counts <- sort(table(values), decreasing = TRUE)
  counts_df <- data.frame(
    name = names(counts),
    total = as.integer(counts),
    stringsAsFactors = FALSE
  )

  if (!is.null(n)) {
    counts_df <- utils::head(counts_df, n)
  }

  rownames(counts_df) <- NULL
  counts_df
}

historia_stat <- function(value, label) {
  div(
    class = "historia-stat",
    span(class = "historia-stat-value", historia_number(value)),
    span(class = "historia-stat-label", label)
  )
}

mod_3Dquilombolas_ui <- function(id) {
  ns <- NS(id)

  div(
    class = "container-fluid py-4 historias-page",
    div(
      class = "historias-heading",
      span(class = "historias-eyebrow", "KISANGA-Q"),
      h2("Historias com dados"),
      p("Narrativas visuais para explorar territorio, biodiversidade, clima e saude a partir da biblioteca KISANGA-Q.")
    ),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        title = "Roteiro",
        width = 320,
        selectInput(
          ns("story"),
          "Historia",
          choices = c("Territorios quilombolas" = "territorios"),
          selected = "territorios"
        ),
        hr(),
        uiOutput(ns("summary")),
        hr(),
        uiOutput(ns("layers"))
      ),
      div(
        class = "historias-workspace",
        tags$section(
          class = "historia-3d-stage",
          div(
            class = "historia-stage-copy",
            span(class = "historias-eyebrow", "Cena 3D"),
            h3("Territorios em perspectiva"),
            p("Comunidades, biomas e situacoes fundiarias organizados para compor historias interativas.")
          ),
          uiOutput(ns("story_scene"))
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          div(
            class = "historia-panel",
            h3("Biomas"),
            uiOutput(ns("biomes"))
          ),
          div(
            class = "historia-panel",
            h3("Status fundiario"),
            uiOutput(ns("land_status"))
          )
        )
      )
    )
  )
}

mod_3Dquilombolas_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    communities <- reactive({
      read_comunidades_points()
    })

    output$summary <- renderUI({
      df <- communities()
      named <- sum(!is.na(df$nm_aglom))
      ufs <- length(unique(stats::na.omit(df$nm_uf)))
      biomes <- length(unique(stats::na.omit(df$bioma)))

      div(
        class = "historias-summary",
        historia_stat(nrow(df), "comunidades"),
        historia_stat(named, "com nome informado"),
        historia_stat(ufs, "UFs"),
        historia_stat(biomes, "biomas")
      )
    })

    output$layers <- renderUI({
      div(
        class = "historia-layers",
        div(icon("database"), span("Base territorial")),
        div(icon("layer-group"), span("Biomas")),
        div(icon("chart-column"), span("Indicadores"))
      )
    })

    output$story_scene <- renderUI({
      top_ufs <- historia_count(communities()$nm_uf, n = 7)

      if (nrow(top_ufs) == 0) {
        return(
          div(
            class = "historia-empty",
            "Dados indisponiveis para esta historia."
          )
        )
      }

      max_total <- max(top_ufs$total)

      div(
        class = "historia-scene",
        lapply(seq_len(nrow(top_ufs)), function(index) {
          item <- top_ufs[index, ]
          width <- max(14, round((item$total / max_total) * 100))

          div(
            class = "historia-bar-row",
            span(class = "historia-bar-label", item$name),
            div(
              class = "historia-bar-track",
              div(
                class = "historia-bar",
                style = sprintf("--bar-width: %s%%;", width),
                span(historia_number(item$total))
              )
            )
          )
        })
      )
    })

    output$biomes <- renderUI({
      counts <- historia_count(communities()$bioma, n = 5)

      if (nrow(counts) == 0) {
        return(div(class = "historia-empty", "Sem biomas informados."))
      }

      div(
        class = "historia-list",
        lapply(seq_len(nrow(counts)), function(index) {
          item <- counts[index, ]
          div(
            class = "historia-list-item",
            span(item$name),
            strong(historia_number(item$total))
          )
        })
      )
    })

    output$land_status <- renderUI({
      counts <- historia_count(communities()$status_fundiario, n = 5)

      if (nrow(counts) == 0) {
        return(div(class = "historia-empty", "Sem status fundiario informado."))
      }

      div(
        class = "historia-list",
        lapply(seq_len(nrow(counts)), function(index) {
          item <- counts[index, ]
          div(
            class = "historia-list-item",
            span(item$name),
            strong(historia_number(item$total))
          )
        })
      )
    })
  })
}
