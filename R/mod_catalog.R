# =============================================================================
# mod_catalog.R — Catálogo de dados
#
# Estrutura:
#   mod_catalog_ui()     → Caixas de resumo + filtros + tabela + painel de detalhe
#   mod_catalog_server() → Lê data/datasets.csv, filtra e renderiza tabela e detalhes
#
# Fluxo de dados:
#   datasets.csv → datasets() → filtered() → output$table + output$detail
# =============================================================================

mod_catalog_ui <- function(id) {
  ns <- NS(id)  # namespace do módulo
  div(class = "container-xl py-4",

    # ── Caixas de resumo ────────────────────────────────────────────────────
    # Mostram contagens gerais independentemente dos filtros ativos
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(
        title    = "Conjuntos de dados",
        value    = textOutput(ns("n_datasets")),
        showcase = bsicons::bs_icon("database"),
        theme    = "primary"
      ),
      value_box(
        title    = "Temas cobertos",
        value    = textOutput(ns("n_themes")),
        showcase = bsicons::bs_icon("tags"),
        theme    = "success"
      ),
      value_box(
        title    = "Dados de  acesso aberto",
        value    = textOutput(ns("n_open")),
        showcase = bsicons::bs_icon("unlock"),
        theme    = "info"
      )
    ),

    # ── Cabeçalho ───────────────────────────────────────────────────────────
    h2("Catálogo de Dados"),
    p(class = "lead", "Explore e filtre os conjuntos de dados disponíveis."),
    hr(),

    # ── Filtros ─────────────────────────────────────────────────────────────
    # As opções de "Tema" são populadas dinamicamente pelo servidor
    fluidRow(
      column(4, selectInput(ns("filter_theme"), "Tema",
        choices = c("Todos"), selected = "Todos")),
      column(4, selectInput(ns("filter_access"), "Tipo de acesso",
        choices = c("Todos", "Aberto", "Restrito"), selected = "Todos")),
      column(4, textInput(ns("search"), "Buscar", placeholder = "palavra-chave..."))
    ),

    # ── Tabela ──────────────────────────────────────────────────────────────
    # Clique em uma linha para ver os detalhes completos abaixo
    DTOutput(ns("table")),

    # ── Painel de detalhe ───────────────────────────────────────────────────
    # Exibido apenas quando uma linha estiver selecionada na tabela
    hr(),
    uiOutput(ns("detail"))
  )
}

mod_catalog_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Lê todos os conjuntos de dados do CSV; retorna data frame vazio se ausente
    datasets <- reactive({
      path <- "data/datasets.csv"
      if (file.exists(path)) {
        read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
      } else {
        data.frame(
          name        = character(0),
          theme       = character(0),
          years       = character(0),
          access      = character(0),
          description = character(0),
          link       = character(0)
        )
      }
    })

    # ── Caixas de resumo (totais do catálogo completo, sem filtros) ──────────
    output$n_datasets <- renderText(nrow(datasets()))
    output$n_themes   <- renderText(length(unique(datasets()$theme)))
    output$n_open     <- renderText(sum(datasets()$access == "Aberto", na.rm = TRUE))

    # Popula o selectInput de tema com os valores únicos presentes no CSV
    observe({
      themes <- c("Todos", sort(unique(datasets()$theme)))
      updateSelectInput(session, "filter_theme", choices = themes)
    })

    # Aplica os três filtros (tema, acesso e busca por texto)
    filtered <- reactive({
      df <- datasets()
      if (input$filter_theme  != "Todos") df <- df[df$theme  == input$filter_theme,  ]
      if (input$filter_access != "Todos") df <- df[df$access == input$filter_access, ]
      if (nzchar(input$search)) {
        kw    <- tolower(input$search)
        match <- apply(df, 1, function(r) any(grepl(kw, tolower(r))))
        df    <- df[match, ]
      }
      df
    })

    # Renderiza a tabela interativa (exibe apenas as colunas de resumo)
    output$table <- renderDT({
      df <- filtered()[, c("name", "theme", "years", "access", "link", "fonte")]
      datatable(
        df,
        selection = "single",   # permite selecionar uma linha para ver detalhes
        rownames  = FALSE,
        colnames  = c("Conjunto de dados", "Tema", "Anos", "Acesso", "Links", "Fonte"),
        options   = list(
          pageLength = 10,
          dom        = "tip",
          language   = list(
            paginate   = list(previous = "Anterior", `next` = "Próximo"),
            info       = "Exibindo _START_ a _END_ de _TOTAL_ registros",
            emptyTable = "Nenhum dado disponível"
          )
        )
      )
    })

    # Exibe card com todos os campos do dataset selecionado
    output$detail <- renderUI({
      sel <- input$table_rows_selected
      if (is.null(sel)) return(NULL)

      row <- filtered()[sel, ]

      # Tenta carregar o arquivo de amostra, se existir
      sample_tbl <- NULL
      if (!is.null(row$sample) && nzchar(trimws(row$sample))) {
        sample_path <- file.path("data/samples", trimws(row$sample))
        if (file.exists(sample_path)) {
          sample_tbl <- read.csv(sample_path, stringsAsFactors = FALSE, encoding = "UTF-8")
        }
      }

      tagList(
        card(
          card_header(row$name),
          card_body(
            p(tags$b("Tema: "),      row$theme),
            p(tags$b("Anos: "),      row$years),
            p(tags$b("Acesso: "),    row$access),
            p(tags$b("Descrição: "), row$description)
          )
        ),
        if (!is.null(sample_tbl)) {
          card(
            class = "mt-3",
            card_header("Prévia dos dados"),
            card_body(
              DTOutput(session$ns("sample_table"))
            )
          )
        }
      )
    })

    # Renderiza a tabela de amostra apenas se um arquivo válido for encontrado
    output$sample_table <- renderDT({
      sel <- input$table_rows_selected
      if (is.null(sel)) return(NULL)

      row <- filtered()[sel, ]
      if (is.null(row$sample) || !nzchar(trimws(row$sample))) return(NULL)

      sample_path <- file.path("data/samples", trimws(row$sample))
      if (!file.exists(sample_path)) return(NULL)

      df <- read.csv(sample_path, stringsAsFactors = FALSE, encoding = "UTF-8")
      datatable(
        df,
        selection = "none",
        rownames  = FALSE,
        options   = list(
          pageLength = 10,
          dom        = "t",
          scrollX    = TRUE
        )
      )
    })
  })
}
