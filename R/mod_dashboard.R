mod_dashboard_ui <- function(id) {
  ns <- NS(id)
  div(class = "container-xl py-4",
    h2("Dashboard"),
    p(class = "lead text-muted", "Analytics and visualisations — coming soon."),
    hr(),

    # Placeholder value boxes
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(
        title    = "Datasets available",
        value    = textOutput(ns("n_datasets")),
        showcase = bsicons::bs_icon("database"),
        theme    = "primary"
      ),
      value_box(
        title    = "Themes covered",
        value    = textOutput(ns("n_themes")),
        showcase = bsicons::bs_icon("tags"),
        theme    = "success"
      ),
      value_box(
        title    = "Open access datasets",
        value    = textOutput(ns("n_open")),
        showcase = bsicons::bs_icon("unlock"),
        theme    = "info"
      )
    ),

    # Chart placeholder
    div(class = "mt-4",
      card(
        card_header("Dataset distribution by theme"),
        card_body(plotOutput(ns("theme_plot"), height = "300px"))
      )
    )
  )
}

mod_dashboard_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    datasets <- reactive({
      path <- "data/datasets.csv"
      if (file.exists(path)) read.csv(path, stringsAsFactors = FALSE)
      else data.frame(name = character(0), theme = character(0), access = character(0))
    })

    output$n_datasets <- renderText(nrow(datasets()))
    output$n_themes   <- renderText(length(unique(datasets()$theme)))
    output$n_open     <- renderText(sum(datasets()$access == "Open", na.rm = TRUE))

    output$theme_plot <- renderPlot({
      df <- datasets()
      if (nrow(df) == 0) {
        plot.new(); text(0.5, 0.5, "No data yet", cex = 1.5, col = "grey60")
        return()
      }
      counts <- sort(table(df$theme))
      par(mar = c(4, 8, 2, 2))
      barplot(counts, horiz = TRUE, las = 1,
              col = "#2C6E49", border = NA,
              xlab = "Number of datasets")
    })
  })
}
