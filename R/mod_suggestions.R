# =============================================================================
# mod_suggestions.R - Contact form for missing communities
#
# Estrutura:
#   mod_suggestions_ui()     -> form for a suggested community
#   mod_suggestions_server() -> validates, saves JSON, opens email draft
# =============================================================================

suggestion_clean_text <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value)) {
    return("")
  }
  trimws(as.character(value[[1]]))
}

suggestion_clean_number <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value)) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(value[[1]]))
}

suggestion_uf_choices <- function() {
  if (!exists("read_comunidades_points", mode = "function")) {
    return(character(0))
  }

  df <- read_comunidades_points()
  sort(unique(stats::na.omit(df$nm_uf)))
}

build_suggestion_submission <- function(nm_aglom, nm_uf, cd_munic, lat_d, long_d) {
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

save_suggestion_submission <- function(submission, dir = "data/submissions") {
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

suggestion_mailto_uri <- function(submission, json_path) {
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

mod_suggestions_ui <- function(id) {
  ns <- NS(id)

  div(
    class = "container-xl py-4 suggestions-page",
    tags$script(HTML("
      Shiny.addCustomMessageHandler('suggestions-mailto', function(message) {
        if (message && message.uri) {
          window.location.href = message.uri;
        }
      });
    ")),
    h2("Nao achou sua comunidade aqui? Envie-nos as informacoes e ela sera adicionada."),
    div(
      class = "suggestions-form",
      bslib::layout_columns(
        col_widths = c(12, 6, 6, 6, 6),
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
        )
      ),
      actionButton(
        ns("send_new"),
        "Enviar",
        icon = icon("paper-plane"),
        class = "btn-primary"
      ),
      uiOutput(ns("submit_status"))
    )
  )
}

mod_suggestions_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    observe({
      ufs <- suggestion_uf_choices()
      updateSelectInput(
        session,
        "new_uf",
        choices = c("Selecione" = "", stats::setNames(ufs, ufs)),
        selected = ""
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
      nm_aglom <- suggestion_clean_text(input$new_nm_aglom)
      nm_uf <- suggestion_clean_text(input$new_uf)
      cd_munic <- suggestion_clean_text(input$new_cd_munic)
      lat_d <- suggestion_clean_number(input$new_lat)
      long_d <- suggestion_clean_number(input$new_long)

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

      submission <- build_suggestion_submission(
        nm_aglom = nm_aglom,
        nm_uf = nm_uf,
        cd_munic = cd_munic,
        lat_d = lat_d,
        long_d = long_d
      )
      json_path <- save_suggestion_submission(submission)
      mailto_uri <- suggestion_mailto_uri(submission, json_path)

      submission_status(list(
        class = "alert-success",
        message = "JSON salvo e email aberto.",
        file = json_path
      ))
      session$sendCustomMessage("suggestions-mailto", list(uri = mailto_uri))

      updateTextInput(session, "new_nm_aglom", value = "")
      updateSelectInput(session, "new_uf", selected = "")
      updateTextInput(session, "new_cd_munic", value = "")
      updateNumericInput(session, "new_lat", value = NA)
      updateNumericInput(session, "new_long", value = NA)
    })
  })
}
