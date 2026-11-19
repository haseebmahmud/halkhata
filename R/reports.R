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
#' Prepare transaction data for an Excel accounting schedule.
#'
#' @param transactions Data frame of transactions
#' @return List containing the reporting period, transaction count, summary,
#'   category breakdown, and transaction detail for export
#' @export
prepare_export_data <- function(transactions) {
    dates <- as.Date(transactions$date)
    type_values <- tolower(as.character(transactions$type))
    amounts <- as.numeric(transactions$amount)
    inflows <- sum(amounts[type_values == "inflow"], na.rm = TRUE)
    outflows <- sum(amounts[type_values == "outflow"], na.rm = TRUE)

    valid_dates <- dates[!is.na(dates)]
    reporting_period <- if (length(valid_dates) > 0L) {
        paste(
            format(min(valid_dates), "%d.%m.%Y"),
            format(max(valid_dates), "%d.%m.%Y"),
            sep = " bis "
        )
    } else {
        "Keine Buchungen"
    }

    transaction_kind <- ifelse(
        type_values == "inflow", "Einnahme",
        ifelse(type_values == "outflow", "Ausgabe", as.character(transactions$type))
    )
    transactions_export <- data.frame(
        `Buchungs-ID` = if ("id" %in% names(transactions)) {
            transactions$id
        } else {
            seq_len(nrow(transactions))
        },
        Datum = dates,
        Art = transaction_kind,
        Kategorie = as.character(transactions$category),
        Beschreibung = as.character(transactions$description),
        Veranstaltung = if ("event" %in% names(transactions)) {
            as.character(transactions$event)
        } else {
            rep(NA_character_, nrow(transactions))
        },
        `Betrag (EUR)` = amounts,
        `Belegdatei` = if ("attachment_path" %in% names(transactions)) {
            attachment_paths <- as.character(transactions$attachment_path)
            attachment_paths[is.na(attachment_paths) | attachment_paths == ""] <- NA_character_
            basename(gsub("\\\\", "/", attachment_paths))
        } else {
            rep(NA_character_, nrow(transactions))
        },
        check.names = FALSE,
        stringsAsFactors = FALSE
    )
    if (nrow(transactions_export) > 0L) {
        transactions_export <- transactions_export[
            order(is.na(transactions_export$Datum), transactions_export$Datum,
                transactions_export$`Buchungs-ID`, na.last = TRUE
            ),
            ,
            drop = FALSE
        ]
        rownames(transactions_export) <- NULL
    }

    category_data <- data.frame(
        Art = transaction_kind,
        Kategorie = as.character(transactions$category),
        Betrag = amounts,
        stringsAsFactors = FALSE
    )
    if (nrow(category_data) > 0L) {
        category_breakdown <- stats::aggregate(
            Betrag ~ Art + Kategorie,
            data = category_data,
            FUN = sum,
            na.rm = TRUE
        )
        category_counts <- stats::aggregate(
            Betrag ~ Art + Kategorie,
            data = category_data,
            FUN = function(x) length(x)
        )
        names(category_breakdown)[names(category_breakdown) == "Betrag"] <- "Summe (EUR)"
        names(category_counts)[names(category_counts) == "Betrag"] <- "Anzahl Buchungen"
        category_breakdown <- merge(
            category_breakdown,
            category_counts,
            by = c("Art", "Kategorie"),
            sort = FALSE
        )
        category_breakdown <- category_breakdown[
            order(category_breakdown$Art, category_breakdown$Kategorie),
            c("Art", "Kategorie", "Anzahl Buchungen", "Summe (EUR)"),
            drop = FALSE
        ]
    } else {
        category_breakdown <- data.frame(
            Art = character(0),
            Kategorie = character(0),
            `Anzahl Buchungen` = integer(0),
            `Summe (EUR)` = numeric(0),
            check.names = FALSE
        )
    }

    summary <- data.frame(
        Kennzahl = c(
            "Betriebseinnahmen (erfasst)",
            "Betriebsausgaben (erfasst)",
            "Vorläufiger Überschuss / Verlust"
        ),
        `Betrag (EUR)` = c(inflows, outflows, inflows - outflows),
        check.names = FALSE,
        stringsAsFactors = FALSE
    )

    list(
        reporting_period = reporting_period,
        transaction_count = nrow(transactions),
        transactions = transactions_export,
        summary = summary,
        category_breakdown = category_breakdown
    )
}
