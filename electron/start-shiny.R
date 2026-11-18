args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 5L) {
  stop("Expected app directory, package library, database path, attachments directory, and port.")
}

app_dir <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
r_library <- args[[2]]
database_path <- normalizePath(args[[3]], winslash = "/", mustWork = FALSE)
attachments_dir <- normalizePath(args[[4]], winslash = "/", mustWork = FALSE)
port <- suppressWarnings(as.integer(args[[5]]))

if (is.na(port) || port < 1L || port > 65535L) {
  stop("The Shiny server port must be between 1 and 65535.")
}
if (nzchar(r_library)) {
  r_library <- normalizePath(r_library, winslash = "/", mustWork = TRUE)
  .libPaths(c(r_library, .Library))
}

if (!requireNamespace("halkhata", quietly = TRUE)) {
  stop("The halkhata R package is not installed in the selected R library.")
}

dir.create(dirname(database_path), recursive = TRUE, showWarnings = FALSE)
dir.create(attachments_dir, recursive = TRUE, showWarnings = FALSE)
options(
  halkhata.db_path = database_path,
  halkhata.attachments_dir = attachments_dir
)

shiny::runApp(
  app_dir,
  host = "127.0.0.1",
  port = port,
  launch.browser = FALSE,
  display.mode = "normal"
)
