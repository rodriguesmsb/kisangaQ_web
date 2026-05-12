mod_home_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # ── Hero ────────────────────────────────────────────────────────────────
    div(class = "hero-banner",
      div(class = "hero-content",
        h1("KisangaQ"),
        p("A platform for curated, deidentified health data")
      )
    ),

    # ── Body ─────────────────────────────────────────────────────────────────
    div(class = "container-xl py-4",

      # About blurb
      div(class = "row mb-5",
        div(class = "col-md-8 offset-md-2 text-center",
          h2("About"),
          p(class = "lead",
            "KisangaQ provides researchers and health managers access to
             harmonised administrative health records for epidemiological
             research and policy analysis."
          )
        )
      ),

      # News cards
      h3("Latest News"),
      hr(),
      uiOutput(ns("news_cards"))
    )
  )
}

mod_home_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    news <- reactive({
      path <- "data/news.csv"
      if (file.exists(path)) {
        read.csv(path, stringsAsFactors = FALSE)
      } else {
        data.frame(
          title = character(0),
          date  = character(0),
          body  = character(0)
        )
      }
    })

    output$news_cards <- renderUI({
      df <- news()
      if (nrow(df) == 0) return(p("No news yet."))

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
