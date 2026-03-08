#' Add Transaction
#'
#' Insert a new transaction into the database.
#'
#' @param con Database connection
#' @param date Transaction date (Date or character)
#' @param type Transaction type ("inflow" or "outflow")
#' @param amount Transaction amount (numeric)
#' @param category Transaction category
#' @param description Transaction description (optional)
#' @param attachment_path Path to attachment file (optional)
#' @param hostname Hostname or username of the machine running the app (optional)
#' @param event Event associated with transaction (optional)
#' @return Transaction ID
#' @export
add_transaction <- function(con, date, type, amount, category,
                            description = "", attachment_path = NULL,
                            hostname = NULL, event = NULL) {
    # Validate inputs
    if (!type %in% c("Inflow", "Outflow")) {
        stop("Type must be 'Inflow' or 'Outflow'")
    }
    if (amount <= 0) {
        stop("Amount must be positive")
    }

    # Convert date to character if needed
    date_str <- as.character(date)

    # Convert NULL to NA for database compatibility
    if (is.null(attachment_path)) {
        attachment_path <- NA_character_
    }
    if (is.null(hostname)) {
        hostname <- NA_character_
    }
    if (is.null(event)) {
        event <- NA_character_
    }

    query <- "
    INSERT INTO transactions (date, type, amount, category, description, attachment_path, hostname, event)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  "

    DBI::dbExecute(
        con, query,
        params = list(date_str, type, amount, category, description, attachment_path, hostname, event)
    )

    # Return the ID of the inserted row
    DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
}

#' Get Transactions
#'
#' Retrieve transactions from the database with optional filters.
#'
#' @param con Database connection
#' @param start_date Start date for filtering (optional)
#' @param end_date End date for filtering (optional)
#' @param type Transaction type filter (optional)
#' @param category Category filter (optional)
#' @param event Event filter (optional)
#' @return Data frame of transactions
#' @export
get_transactions <- function(con, start_date = NULL, end_date = NULL,
                             type = NULL, category = NULL, event = NULL) {
    query <- "SELECT * FROM transactions WHERE 1=1"
    params <- list()

    if (!is.null(start_date)) {
        query <- paste(query, "AND date >= ?")
        params <- c(params, as.character(start_date))
    }

    if (!is.null(end_date)) {
        query <- paste(query, "AND date <= ?")
        params <- c(params, as.character(end_date))
    }

    if (!is.null(type)) {
        query <- paste(query, "AND type = ?")
        params <- c(params, type)
    }

    if (!is.null(category)) {
        query <- paste(query, "AND category = ?")
        params <- c(params, category)
    }

    if (!is.null(event)) {
        query <- paste(query, "AND event = ?")
        params <- c(params, event)
    }

    query <- paste(query, "ORDER BY date DESC, created_at DESC")

    if (length(params) > 0) {
        result <- DBI::dbGetQuery(con, query, params = params)
    } else {
        result <- DBI::dbGetQuery(con, query)
    }

    # Convert date column to Date type
    if (nrow(result) > 0) {
        result$date <- as.Date(result$date)
    }

    result
}

#' Update Transaction
#'
#' Modify an existing transaction.
#'
#' @param con Database connection
#' @param id Transaction ID
#' @param date New date (optional)
#' @param type New type (optional)
#' @param amount New amount (optional)
#' @param category New category (optional)
#' @param description New description (optional)
#' @param attachment_path New attachment path (optional)
#' @param event New event (optional)
#' @return Number of rows affected
#' @export
update_transaction <- function(con, id, date = NULL, type = NULL, amount = NULL,
                               category = NULL, description = NULL,
                               attachment_path = NULL, event = NULL) {
    # Build dynamic update query
    updates <- c()
    params <- list()

    if (!is.null(date)) {
        updates <- c(updates, "date = ?")
        params <- c(params, as.character(date))
    }
    if (!is.null(type)) {
        updates <- c(updates, "type = ?")
        params <- c(params, type)
    }
    if (!is.null(amount)) {
        updates <- c(updates, "amount = ?")
        params <- c(params, amount)
    }
    if (!is.null(category)) {
        updates <- c(updates, "category = ?")
        params <- c(params, category)
    }
    if (!is.null(description)) {
        updates <- c(updates, "description = ?")
        params <- c(params, description)
    }
    if (!is.null(attachment_path)) {
        updates <- c(updates, "attachment_path = ?")
        params <- c(params, attachment_path)
    }
    if (!is.null(event)) {
        updates <- c(updates, "event = ?")
        params <- c(params, event)
    }

    if (length(updates) == 0) {
        return(0)
    }

    query <- sprintf(
        "UPDATE transactions SET %s WHERE id = ?",
        paste(updates, collapse = ", ")
    )
    params <- c(params, id)

    DBI::dbExecute(con, query, params = params)
}

#' Delete Transaction
#'
#' Remove a transaction from the database.
#'
#' @param con Database connection
#' @param id Transaction ID
#' @return Number of rows affected
#' @export
delete_transaction <- function(con, id) {
    DBI::dbExecute(con, "DELETE FROM transactions WHERE id = ?", params = list(id))
}

#' Get Categories
#'
#' Retrieve all categories or filter by type.
#'
#' @param con Database connection
#' @param type Filter by type ("inflow", "outflow", or NULL for all)
#' @return Data frame of categories
#' @export
get_categories <- function(con, type = NULL) {
    if (is.null(type)) {
        DBI::dbGetQuery(con, "SELECT * FROM categories ORDER BY name")
    } else {
        DBI::dbGetQuery(
            con,
            "SELECT * FROM categories WHERE type = ? OR type = 'both' ORDER BY name",
            params = list(type)
        )
    }
}

#' Add Category
#'
#' Add a new category to the database.
#'
#' @param con Database connection
#' @param name Category name
#' @param type Category type ('Inflow', 'Outflow', or 'both')
#' @return Invisible NULL
#' @export
add_category <- function(con, name, type) {
    if (!type %in% c("Inflow", "Outflow", "both")) {
        stop("Type must be 'Inflow', 'Outflow', or 'both'")
    }
    tryCatch(
        DBI::dbExecute(
            con,
            "INSERT INTO categories (name, type) VALUES (?, ?)",
            params = list(name, type)
        ),
        error = function(e) stop("Category already exists or invalid.")
    )
}

#' Get Events
#'
#' Retrieve all events.
#'
#' @param con Database connection
#' @return Data frame of events
#' @export
get_events <- function(con) {
    DBI::dbGetQuery(con, "SELECT * FROM events ORDER BY name")
}

#' Add Event
#'
#' Add a new event to the database.
#'
#' @param con Database connection
#' @param name Event name
#' @return Invisible NULL
#' @export
add_event <- function(con, name) {
    tryCatch(
        DBI::dbExecute(
            con,
            "INSERT INTO events (name) VALUES (?)",
            params = list(name)
        ),
        error = function(e) stop("Event already exists or invalid.")
    )
}
