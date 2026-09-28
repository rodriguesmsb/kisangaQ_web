# =============================================================================
# mod_equipe.R — Equipe do projeto
# =============================================================================

mod_equipe_ui <- function(id) {
  ns <- NS(id)

  div(id = ns("equipe"), class = "container-xl py-4 equipe-page",
    h2("Equipe"),
    p(class = "text-muted mb-4", "Conheça a equipe do projeto KISANGA-Q."),
    uiOutput(ns("team_grid"))
  )
}

mod_equipe_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$team_grid <- renderUI({
      path <- "data/kisanga_team.json"
      if (!file.exists(path)) return(p("Equipe indisponível no momento."))

      team <- jsonlite::fromJSON(path)
      if (length(team) == 0L || nrow(team) == 0L) {
        return(p("Nenhum integrante cadastrado."))
      }

      # Os nomes dos arquivos identificam os integrantes com ordem de destaque.
      member_ids <- tools::file_path_sans_ext(basename(team$path_to_photo))
      featured <- c(
        "james_junior", "gabriela_arrifano", "fernando_carvalho",
        "amanda_sacramento", "moreno_rodrigues"
      )
      priority <- match(member_ids, featured)
      priority[is.na(priority)] <- length(featured) + 1L
      alphabetical <- tolower(iconv(team$name, from = "UTF-8", to = "ASCII//TRANSLIT"))
      member_order <- order(priority, alphabetical)

      cards <- lapply(member_order, function(i) {
        member <- team[i, ]
        # Shiny publica o conteúdo de www diretamente na raiz da aplicação.
        photo_url <- sub("^/?www/", "", member$path_to_photo)
        photo <- if (file.exists(file.path("www", photo_url))) {
          tags$img(
            src = photo_url,
            alt = paste("Foto de", member$name),
            class = "equipe-photo",
            loading = "lazy",
            width = "320", height = "320"
          )
        } else {
          div(class = "equipe-photo equipe-photo-placeholder",
            role = "img", `aria-label` = paste("Foto indisponível de", member$name),
            tags$span("Foto em breve")
          )
        }

        tags$article(class = "card equipe-card",
          photo,
          div(class = "card-body",
            h3(class = "equipe-name", member$name),
            if (member_ids[i] == "james_junior") {
              tags$span(class = "equipe-coordinator", "Coordenador")
            },
            if (!is.na(member$institution) && nzchar(trimws(member$institution))) {
              p(class = "equipe-institution", member$institution)
            }
          )
        )
      })

      div(class = "equipe-grid", tagList(cards))
    })
  })
}
