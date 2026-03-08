#' Run the Halkhata Accounting App
#' @param db_path Path to the SQLite database
#' @param attachments_dir Directory to store file attachments
#' @export
run_accounting_app <- function(db_path = "accounting.db", attachments_dir = "attachments") {
  # Create attachments directory if it doesn't exist
  if (!dir.exists(attachments_dir)) {
    dir.create(attachments_dir, recursive = TRUE)
  }
  
  # Ensure database is set up
  setup_database(db_path)
  
  # Set environment variables for the app to pick up
  Sys.setenv(HALKHATA_DB_PATH = normalizePath(db_path))
  Sys.setenv(HALKHATA_ATTACHMENTS_DIR = normalizePath(attachments_dir))
  
  # Run the app
  shiny::runApp(system.file("shiny-app", package = "halkhata"))
}

#' Run Accounting App
#'
#' Launch the accounting Shiny application.
#'
#' @param db_path Path to SQLite database (default: "accounting.db")
#' @param attachments_dir Directory for file attachments (default: "attachments")
#' @export
run_accounting_app <- function(db_path = "accounting.db",
                               attachments_dir = "attachments") {
    # Initialize database
    init_database(db_path)

    # Create attachments directory
    if (!dir.exists(attachments_dir)) {
        dir.create(attachments_dir, recursive = TRUE)
    }

    # Get app directory
    app_dir <- system.file("shiny-app", package = "halkhata")

    if (app_dir == "") {
        stop("Could not find Shiny app directory. Make sure the package is properly installed.")
    }

    # Set options for the app
    options(
        halkhata.db_path = db_path,
        halkhata.attachments_dir = attachments_dir
    )

    # Run the app
    shiny::runApp(app_dir, display.mode = "normal")
}
