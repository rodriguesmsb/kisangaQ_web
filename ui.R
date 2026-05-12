
ui <- page_navbar(
  title = tags$span(
    tags$img(src = "logo.png", height = "75px", style = "margin-right:8px; vertical-align:middle;"),
    "KISANGA-Q"
  ),

  # Personalização do tema e inclusão de CSS customizado
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#C8731A",
    success    = "#7A9C38",
    dark       = "#2C1A08",
    base_font  = font_google("Inter"),
    bg         = "#FAF4E8",
    fg         = "#2C1A08"
  ),
  header = tags$head(
    tags$link(rel = "stylesheet", href = "custom.css")
  ),

  # Navegação principal — cada item corresponde a um módulo UI definido em R/mod_*.R
  nav_panel("Início",   mod_home_ui("home")),
  nav_panel("Catálogo", mod_catalog_ui("catalog")),
  nav_panel("Painel",   mod_dashboard_ui("dashboard")),

  # Links externos no canto direito da barra de navegação
  nav_spacer(),
  nav_item(tags$a(
    href   = "https://github.com/rodriguesmsb/KisangaQ_web",  
    target = "_blank",
    icon("github"), "GitHub"
  ))
)
