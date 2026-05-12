ui <- page_navbar(
  title = "KisangaQ",
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#2C6E49",
    base_font  = font_google("Inter")
  ),
  header = tags$head(
    tags$link(rel = "stylesheet", href = "custom.css")
  ),

  # ── Pages ──────────────────────────────────────────────────────────────────
  nav_panel("Home",      mod_home_ui("home")),
  nav_panel("Catalog",   mod_catalog_ui("catalog")),
  nav_panel("Dashboard", mod_dashboard_ui("dashboard")),

  nav_spacer(),
  nav_item(tags$a(
    href   = "https://github.com/",   # replace with your repo
    target = "_blank",
    icon("github"), "GitHub"
  ))
)
