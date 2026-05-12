# =============================================================================
# mod_home.R — Página inicial
#
# Estrutura:
#   mod_home_ui()     → Hero banner + seção "Sobre" + cards de notícias
#   mod_home_server() → Lê data/news.csv e renderiza os cards dinamicamente
# =============================================================================

mod_home_ui <- function(id) {
  ns <- NS(id)  # cria namespace para evitar conflito de IDs entre módulos
  tagList(

    # ── Hero banner ──────────────────────────────────────────────────────────
    # Faixa de destaque no topo da página com logo e título
    div(class = "hero-banner",
      div(class = "hero-content",
        # Shiny serve a pasta www/ como raiz — não inclua "www/" no caminho
        tags$img(src = "logo.png", height = "72px", style = "margin-bottom:1rem;"),
        h1("KisangaQ"),
        p("Uma plataforma de análise de dados para comunidades Quilombolas")
      )
    ),

    # ── Corpo principal ──────────────────────────────────────────────────────
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

mod_home_server <- function(id) {
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
