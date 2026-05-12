# =============================================================================
# mod_home.R — Página inicial
#
# Estrutura:
#   mod_home_ui()     → Hero banner + seção "Sobre" + cards de notícias
#   mod_home_server() → Lê data/news.csv e renderiza os cards dinamicamente
# =============================================================================

mod_home_ui <- function(id) {
  #cria namespace para evitar conflito de IDs entre módulos
  ns <- NS(id) 

  # A função tagList() é usada para retornar múltiplos elementos UI como um único objeto
  tagList(

    # Faixa de destaque no topo da página com logo e título
    div(class = "hero-banner",
      div(class = "hero-content",
        tags$img(src = "logo.png", height = "200px", style = "margin-bottom:1rem;"),
        h1("KisangaQ"),
        p("Uma plataforma de análise de dados para comunidades Quilombolas")
      )
    ),

    # Corpo da página com seção "Sobre" e notícias recentes
    div(class = "container-xl py-4",

      # Bloco "Sobre" — substitua o texto pelo conteúdo real do projeto
      div(class = "row mb-5",
        div(class = "col-md-8 offset-md-2 text-center",
          h2("Sobre"),
          p(class = "lead",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor
            incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud
            exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
          )
        )
      ),

      # Notícias — geradas dinamicamente a partir de data/news.csv
      h3("Últimas Notícias"),
      hr(),
      uiOutput(ns("news_cards"))  # preenchido pelo servidor
    )
  )
}

# O servidor lê o arquivo CSV de notícias e renderiza um card para cada linha
mod_home_server <- function(id) {

  # A função moduleServer() é usada para criar um servidor modularizado
  moduleServer(id, function(input, output, session) {

    # Lê o arquivo de notícias; retorna data frame vazio se não existir
    news <- reactive({
      path <- "data/news.csv"
      if (file.exists(path)) {
        read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
      } else {
        data.frame(title = character(0), date = character(0), body = character(0))
      }
    })

    # Renderiza um card Bootstrap para cada linha do CSV
    output$news_cards <- renderUI({
      df <- news()
      if (nrow(df) == 0) return(p("Nenhuma notícia disponível."))

      # Cria uma lista de divs, cada uma contendo um card para uma notícia
      cards <- lapply(seq_len(nrow(df)), function(i) {
        div(class = "col-md-4 mb-4",
          card(
            card_header(df$title[i]),
            card_body(
              p(class = "text-muted small", df$date[i]),
              p(df$body[i])
            )
          )
        )
      })

      div(class = "row", tagList(cards))
    })
  })
}
