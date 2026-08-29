# =============================================================================
# mod_3dquilombolas.R - Story index for data-driven narratives
# =============================================================================

stories_dir <- "data/stories"

register_stories_resource_path <- function() {
  if (dir.exists(stories_dir) && !"stories" %in% names(shiny::resourcePaths())) {
    shiny::addResourcePath("stories", normalizePath(stories_dir, winslash = "/"))
  }
}

read_story_name <- function(index_html) {
  html <- paste(readLines(index_html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  h1 <- regmatches(html, regexpr("(?is)<h1[^>]*>.*?</h1>", html, perl = TRUE))
  name <- gsub("<[^>]+>", "", h1, perl = TRUE)
  trimws(name)
}

list_data_stories <- function() {
  if (!dir.exists(stories_dir)) {
    return(data.frame(name = character(0), href = character(0)))
  }

  folders <- sort(list.dirs(stories_dir, full.names = FALSE, recursive = FALSE))
  index_files <- file.path(stories_dir, folders, "index.html")
  keep <- file.exists(index_files)

  data.frame(
    name = unname(vapply(index_files[keep], read_story_name, character(1))),
    href = paste0("stories/", folders[keep], "/index.html"),
    stringsAsFactors = FALSE
  )
}

story_link <- function(name, href) {
  tags$a(
    class = "historia-link",
    href = href,
    target = "_blank",
    rel = "noopener noreferrer",
    name
  )
}

mod_3dquilombolas_ui <- function(id) {
  ns <- NS(id)
  register_stories_resource_path()

  div(
    class = "container-fluid py-4 historias-page",
    div(
      class = "historias-heading",
      span(class = "historias-eyebrow", "KISANGA-Q"),
      h2("Historias com dados"),
      p("Narrativas visuais em 3D e historias interativas construidas a partir da biblioteca KISANGA-Q.")
    ),
    uiOutput(ns("stories"))
  )
}

mod_3dquilombolas_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$stories <- renderUI({
      register_stories_resource_path()
      stories <- list_data_stories()

      if (nrow(stories) == 0) {
        return(
          div(
            class = "historias-empty-state",
            icon("book-open"),
            h3("Nenhuma historia disponivel"),
            p("Novas narrativas aparecerao nesta lista.")
          )
        )
      }

      div(
        class = "historias-list",
        lapply(seq_len(nrow(stories)), function(index) {
          story_link(stories$name[[index]], stories$href[[index]])
        })
      )
    })
  })
}
