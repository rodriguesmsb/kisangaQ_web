server <- function(input, output, session) {
  mod_home_server("home")
  mod_catalog_server("catalog")
  mod_3dquilombolas_server("comunidades")
  mod_suggestions_server("suggestions")
}
