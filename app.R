library(shiny)

# Serve the pre-rendered self-contained presentation.
# index.html lives in www/ so Shiny serves it as a static file.
# The redirect sends the browser straight there.

ui <- tags$html(
  tags$head(
    tags$script(HTML('window.location.replace("index.html");'))
  ),
  tags$body()
)

server <- function(input, output, session) {}

shinyApp(ui, server)
