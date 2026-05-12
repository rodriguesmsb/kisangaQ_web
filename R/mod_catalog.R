mod_catalog_ui <- function(id) {
  ns <- NS(id)
  div(class = "container-xl py-4",
    h2("Data Catalog"),
    p(class = "lead", "Browse and filter available datasets."),
    hr(),

    # Filters row
    fluidRow(
      column(4, selectInput(ns("filter_theme"), "Theme",
        choices = c("All"), selected = "All")),
      column(4, selectInput(ns("filter_access"), "Access type",
        choices = c("All", "Open", "Restricted"), selected = "All")),
      column(4, textInput(ns("search"), "Search", placeholder = "keyword..."))
    ),

    # Table
    DTOutput(ns("table")),

    # Detail panel — shown when a row is selected
    hr(),
    uiOutput(ns("detail"))
  )
}

mod_catalog_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    datasets <- reactive({
      path <- "data/datasets.csv"
      if (file.exists(path)) {
        read.csv(path, stringsAsFactors = FALSE)
      } else {
        data.frame(
          name        = character(0),
          theme       = character(0),
          years       = character(0),
          access      = character(0),
          description = character(0)
        )
      }
    })

    # Populate theme filter dynamically
    observe({
      themes <- c("All", sort(unique(datasets()$theme)))
      updateSelectInput(session, "filter_theme", choices = themes)
    })

    filtered <- reactive({
      df <- datasets()
      if (input$filter_theme  != "All") df <- df[df$theme  == input$filter_theme,  ]
      if (input$filter_access != "All") df <- df[df$access == input$filter_access, ]
      if (nzchar(input$search)) {
        kw <- tolower(input$search)
        match <- apply(df, 1, function(r) any(grepl(kw, tolower(r))))
        df <- df[match, ]
      }
      df
    })

    output$table <- renderDT({
      df <- filtered()[, c("name", "theme", "years", "access")]
      datatable(
        df,
        selection  = "single",
        rownames   = FALSE,
        colnames   = c("Dataset", "Theme", "Years", "Access"),
        options    = list(pageLength = 10, dom = "tip")
      )
    })

    output$detail <- renderUI({
      sel <- input$table_rows_selected
      if (is.null(sel)) return(NULL)

      row <- filtered()[sel, ]
      card(
        card_header(row$name),
        card_body(
          p(tags$b("Theme: "),   row$theme),
          p(tags$b("Years: "),   row$years),
          p(tags$b("Access: "),  row$access),
          p(tags$b("Description: "), row$description)
        )
      )
    })
  })
}
