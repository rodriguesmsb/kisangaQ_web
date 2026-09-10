# =============================================================================
# mod_equipe.R — Equipe do projeto
# =============================================================================

mod_equipe_ui <- function(id) {
  ns <- NS(id)

  div(id = ns("equipe"), class = "container-xl py-4 text-center",
    tags$img(
      src = "giphy.gif",
      alt = "Animação da página Equipe",
      class = "img-fluid"
    )
  )
}

mod_equipe_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Espaço reservado para futuras funcionalidades da equipe.
  })
}
