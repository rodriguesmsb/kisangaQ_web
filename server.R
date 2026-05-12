server <- function(input, output, session) {
  mod_home_server("home")
  mod_catalog_server("catalog")
  mod_dashboard_server("dashboard")
}

