#' Export to Excel
#'
#' Create a formatted Excel workbook with transaction data.
#'
#' @param transactions Data frame of transactions
#' @param filename Output filename
#' @return Path to created Excel file
#' @export
export_to_excel <- function(transactions, filename = "accounting_report.xlsx") {
    # Prepare data
    export_data <- prepare_export_data(transactions)

    # Create workbook
    wb <- openxlsx::createWorkbook()

    # Add Transactions sheet
    openxlsx::addWorksheet(wb, "Transactions")
    openxlsx::writeData(wb, "Transactions", export_data$transactions)

    # Format transactions sheet
    if (nrow(export_data$transactions) > 0) {
        # Header style
        header_style <- openxlsx::createStyle(
            fontColour = "#FFFFFF",
            fgFill = "#4F81BD",
            halign = "center",
            valign = "center",
            textDecoration = "bold",
            border = "TopBottomLeftRight"
        )
        openxlsx::addStyle(wb, "Transactions", header_style,
            rows = 1,
            cols = 1:ncol(export_data$transactions), gridExpand = TRUE
        )

        # Number format for amount
        amount_col <- which(names(export_data$transactions) == "amount")
        openxlsx::addStyle(wb, "Transactions",
            openxlsx::createStyle(numFmt = "#,##0.00"),
            rows = 2:(nrow(export_data$transactions) + 1),
            cols = amount_col, gridExpand = TRUE
        )

        # Date format
        date_col <- which(names(export_data$transactions) == "date")
        openxlsx::addStyle(wb, "Transactions",
            openxlsx::createStyle(numFmt = "yyyy-mm-dd"),
            rows = 2:(nrow(export_data$transactions) + 1),
            cols = date_col, gridExpand = TRUE
        )

        # Auto-width columns
        openxlsx::setColWidths(wb, "Transactions",
            cols = 1:ncol(export_data$transactions),
            widths = "auto"
        )
    }

    # Add Summary sheet
    openxlsx::addWorksheet(wb, "Summary")
    openxlsx::writeData(wb, "Summary", export_data$summary)
    openxlsx::addStyle(wb, "Summary", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = c(25, 20))

    # Add Category Breakdown sheet
    openxlsx::addWorksheet(wb, "Category Breakdown")
    openxlsx::writeData(wb, "Category Breakdown", export_data$category_breakdown)

    if (nrow(export_data$category_breakdown) > 0) {
        openxlsx::addStyle(wb, "Category Breakdown", header_style,
            rows = 1,
            cols = 1:ncol(export_data$category_breakdown), gridExpand = TRUE
        )

        # Number format for total
        total_col <- which(names(export_data$category_breakdown) == "total")
        openxlsx::addStyle(wb, "Category Breakdown",
            openxlsx::createStyle(numFmt = "#,##0.00"),
            rows = 2:(nrow(export_data$category_breakdown) + 1),
            cols = total_col, gridExpand = TRUE
        )

        openxlsx::setColWidths(wb, "Category Breakdown",
            cols = 1:ncol(export_data$category_breakdown),
            widths = "auto"
        )
    }

    # Save workbook
    openxlsx::saveWorkbook(wb, filename, overwrite = TRUE)

    filename
}
