# =============================================================================
# mod_home.R — Página inicial
#
# Estrutura:
#   mod_home_ui()     → Hero banner + seção "Sobre" + carrossel de notícias
#   mod_home_server() → Lê data/news.csv e monta o carrossel Bootstrap 5
#
# Lógica do carrossel:
#   - As notícias são agrupadas em slides de 3 cards por vez
#   - O carrossel usa o componente nativo do Bootstrap 5 (já incluído pelo bslib)
#   - Botões anterior/próximo navegam entre os grupos
# =============================================================================

mod_home_ui <- function(id) {
  # Cria namespace para evitar conflito de IDs entre módulos
  ns <- NS(id)

  # A função tagList() retorna múltiplos elementos UI como um único objeto
  tagList(

    # ── Hero banner ──────────────────────────────────────────────────────────
    # Faixa de destaque no topo da página com logo e título
    div(class = "hero-banner",
      div(class = "hero-content",
        tags$img(src = "logo.png", height = "200px", style = "margin-bottom:1rem;"),
        h1("KisangaQ"),
        p("Uma plataforma de análise de dados para comunidades Quilombolas")
      )
    ),

    # Corpo da página — container centralizado com conteúdo sobre o projeto e o carrossel de notícias
    div(class = "container-xl py-4",

      # Bloco "Sobre" — substitua o Lorem ipsum pelo texto real do projeto
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

      # Carrossel de notícias — o conteúdo é gerado dinamicamente pelo servidor a partir do CSV
      # O uiOutput é preenchido pelo servidor com o HTML do carrossel Bootstrap 5
      h3("Últimas Notícias"),
      hr(),
      uiOutput(ns("news_carousel"))
    )
  )
}

# O servidor lê o CSV e constrói o carrossel Bootstrap 5 com grupos de 3 cards
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

    output$news_carousel <- renderUI({
      
      df <- news()
      if (nrow(df) == 0) return(p("Nenhuma notícia disponível."))

 
      # Cada "slide" do carrossel contém uma linha com até 2 cards
      n_per_slide <- 2
      indices     <- seq_len(nrow(df))
      # split() divide o vetor de índices em grupos de tamanho n_per_slide
      groups      <- split(indices, ceiling(indices / n_per_slide))

      # Constrói cada slide como um div.carousel-item com uma row de cards
      slides <- lapply(seq_along(groups), function(g) {
        group_idx <- groups[[g]]

        # Cria um card para cada notícia do grupo
        cards_in_slide <- lapply(group_idx, function(i) {
          div(class = "col-md-5",
            div(class = "card h-100 news-card",
              div(class = "card-header", df$title[i]),
              div(class = "card-body",
                tags$p(class = "text-muted small", df$date[i]),
                # Exibe "(sem conteúdo)" se o campo body estiver vazio
                tags$p(if (nzchar(trimws(df$body[i]))) df$body[i] else tags$em("(sem conteúdo)"))
              )
            )
          )
        })

        # O primeiro slide recebe a classe "active" — obrigatório para o Bootstrap
        slide_class <- if (g == 1) "carousel-item active" else "carousel-item"
        div(class = slide_class,
          div(class = "row g-3", tagList(cards_in_slide))
        )
      })

  
      # Um botão por slide; o primeiro começa ativo
      indicators <- lapply(seq_along(groups), function(g) {
        btn_class <- if (g == 1) "active" else ""
        tags$button(
          type             = "button",
          `data-bs-target` = "#newsCarousel",
          `data-bs-slide-to` = as.character(g - 1),
          class            = btn_class,
          `aria-label`     = paste("Slide", g)
        )
      })

      # ── Monta o carrossel Bootstrap 5 completo ────────────────────────────
      tagList(
        div(class = "carousel slide", id = "newsCarousel",


          # Slides — padding-bottom deixa espaço para as bolinhas não sobreporem os cards
          div(class = "carousel-inner", tagList(slides)),

            # Bolinhas de navegação
          div(class = "carousel-indicators", tagList(indicators)),

          # Botão "Anterior"
          tags$button(
            class            = "carousel-control-prev",
            type             = "button",
            `data-bs-target` = "#newsCarousel",
            `data-bs-slide`  = "prev",
            tags$span(class = "carousel-control-prev-icon news-carousel-ctrl"),
            tags$span(class = "visually-hidden", "Anterior")
          ),

          # Botão "Próximo"
          tags$button(
            class            = "carousel-control-next",
            type             = "button",
            `data-bs-target` = "#newsCarousel",
            `data-bs-slide`  = "next",
            tags$span(class = "carousel-control-next-icon news-carousel-ctrl"),
            tags$span(class = "visually-hidden", "Próximo")
          )
        ),

        # Bootstrap 5 só inicializa carrosséis presentes no carregamento da página.
        # Como este é injetado pelo renderUI, precisamos inicializá-lo manualmente via JS.
        # O setTimeout garante que o DOM já foi atualizado antes da inicialização.
        tags$script(HTML("
          setTimeout(function() {
            var el = document.getElementById('newsCarousel');
            if (el) {
              new bootstrap.Carousel(el, { interval: 4000, ride: 'carousel' });
            }
          }, 100);
        "))
      )
    })
  })
}
