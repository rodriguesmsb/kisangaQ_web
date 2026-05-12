# =============================================================================
# mod_dashboard.R — Painel de análises
#
# Estrutura:
#   mod_dashboard_ui()     → GIF de "em construção" + mensagem
#   mod_dashboard_server() → Vazio por enquanto, mas necessário para evitar erros
# Fluxo de dados:
#   (TBD)
# =============================================================================

mod_dashboard_ui <- function(id) {
  ns <- NS(id)  # namespace reservado para quando os outputs forem adicionados
  div(class = "container-xl py-4 text-center",

    # GIF de "em construção" — coloque o arquivo em www/giphy.gif
    # Shiny serve a pasta www/ como raiz — não inclua "www/" no caminho
    tags$img(src = "giphy.gif", height = "450px"),

    h2("Dashboard em construção"),
    p(class = "lead",
      "Estamos trabalhando para trazer análises e visualizações interessantes aqui em breve!")
  )
}

# Servidor vazio — necessário para que server.R possa chamar mod_dashboard_server()
# sem erro. Adicione outputs reativos aqui conforme o painel for desenvolvido.
mod_dashboard_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # futuras análises aqui
  })
}
