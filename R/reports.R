# Suppress R CMD check warnings for dplyr NSE
utils::globalVariables(c("amount", "type", "period", "inflows", "outflows", "category", "total", "event", "balance"))

#' Calculate Balance
#'
#' Compute net balance (inflows - outflows) for a period.
#'
#' @param transactions Data frame of transactions
#' @return Numeric balance
#' @export
calculate_balance <- function(transactions) {
    if (nrow(transactions) == 0) {
        return(0)
    }

    inflows <- sum(transactions$amount[transactions$type == "Inflow"], na.rm = TRUE)
    outflows <- sum(transactions$amount[transactions$type == "Outflow"], na.rm = TRUE)

    inflows - outflows
}

#' Get Periodic Summary
#'
#' Aggregate inflows and outflows by time period.
#'
#' @param transactions Data frame of transactions
#' @param period Period to aggregate by ("day", "week", "month", "year")
#' @return Data frame with period, inflows, outflows, and balance
#' @export
get_periodic_summary <- function(transactions, period = "month") {
    if (nrow(transactions) == 0) {
        return(data.frame(
            period = character(0),
            inflows = numeric(0),
            outflows = numeric(0),
            balance = numeric(0)
        ))
    }

    # Ensure date is Date type
    transactions$date <- as.Date(transactions$date)

    # Create period column
    transactions$period <- switch(period,
        "day" = as.character(transactions$date),
        "week" = format(lubridate::floor_date(transactions$date, "week"), "%Y-W%U"),
        "month" = format(transactions$date, "%Y-%m"),
        "year" = format(transactions$date, "%Y"),
        format(transactions$date, "%Y-%m") # default to month
    )

    # Aggregate by period
    summary <- transactions |>
        dplyr::group_by(period) |>
        dplyr::summarise(
            inflows = sum(amount[type == "Inflow"], na.rm = TRUE),
            outflows = sum(amount[type == "Outflow"], na.rm = TRUE),
            .groups = "drop"
        ) |>
        dplyr::mutate(balance = inflows - outflows) |>
        dplyr::arrange(period)

    as.data.frame(summary)
}

#' Get Category Breakdown
#'
#' Summarize transactions by category.
#'
#' @param transactions Data frame of transactions
#' @param type Filter by type ("inflow", "outflow", or NULL for all)
#' @return Data frame with category, type, total, and count
#' @export
get_category_breakdown <- function(transactions, type = NULL) {
    if (nrow(transactions) == 0) {
        return(data.frame(
            category = character(0),
            type = character(0),
            total = numeric(0),
            count = integer(0)
        ))
    }

    # Filter by type if specified
    if (!is.null(type)) {
        transactions <- transactions[transactions$type == type, ]
    }

    # Aggregate by category
    breakdown <- transactions |>
        dplyr::group_by(category, type) |>
        dplyr::summarise(
            total = sum(amount, na.rm = TRUE),
            count = dplyr::n(),
            .groups = "drop"
        ) |>
        dplyr::arrange(dplyr::desc(total))

    as.data.frame(breakdown)
}

#' Get Event Breakdown
#'
#' Summarize transactions by event.
#'
#' @param transactions Data frame of transactions
#' @param type Filter by type ("inflow", "outflow", or NULL for all)
#' @return Data frame with event, inflows, outflows, and balance
#' @export
get_event_breakdown <- function(transactions, type = NULL) {
    if (nrow(transactions) == 0) {
        return(data.frame(
            event = character(0),
            inflows = numeric(0),
            outflows = numeric(0),
            balance = numeric(0)
        ))
    }

    # Filter by type if specified
    if (!is.null(type)) {
        transactions <- transactions[transactions$type == type, ]
    }

    # Handle NA events
    transactions$event[is.na(transactions$event) | transactions$event == ""] <- "Not event specific"

    # Aggregate by event
    breakdown <- transactions |>
        dplyr::group_by(event) |>
        dplyr::summarise(
            inflows = sum(amount[type == "Inflow"], na.rm = TRUE),
            outflows = sum(amount[type == "Outflow"], na.rm = TRUE),
            .groups = "drop"
        ) |>
        dplyr::mutate(balance = inflows - outflows) |>
        dplyr::arrange(dplyr::desc(inflows + outflows))

    as.data.frame(breakdown)
}

#' Prepare Export Data
#'
#' Format transaction data for Excel export.
#'
#' @param transactions Data frame of transactions
#' @return List with formatted data frames for export
#' @export
prepare_export_data <- function(transactions) {
    # Main transactions sheet
    transactions_export <- transactions
    if (nrow(transactions_export) > 0) {
        transactions_export$date <- as.Date(transactions_export$date)
        # Remove internal columns
        transactions_export <- transactions_export[, c(
            "id", "date", "type", "amount",
            "category", "description",
            "attachment_path"
        )]
    }

    # Summary sheet
    summary <- data.frame(
        Metric = c(
            "Total Inflows", "Total Outflows", "Net Balance",
            "Number of Transactions", "Date Range"
        ),
        Value = c(
            sum(transactions$amount[transactions$type == "Inflow"], na.rm = TRUE),
            sum(transactions$amount[transactions$type == "Outflow"], na.rm = TRUE),
            calculate_balance(transactions),
            nrow(transactions),
            if (nrow(transactions) > 0) {
                sprintf("%s to %s", min(transactions$date), max(transactions$date))
            } else {
                "No data"
            }
        ),
        stringsAsFactors = FALSE
    )

    # Category breakdown
    category_breakdown <- get_category_breakdown(transactions)

    list(
        transactions = transactions_export,
        summary = summary,
        category_breakdown = category_breakdown
    )
}
