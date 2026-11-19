#' Export to Excel
#'
#' Create a German-language workbook with an EÜR-oriented summary and detailed
#' transaction schedule. The workbook is supporting documentation and is not
#' an official Anlage EÜR.
#'
#' @param transactions Data frame of transactions
#' @param filename Output filename
#' @return Path to created Excel file
#' @export
export_to_excel <- function(transactions, filename = "accounting_report.xlsx") {
    export_data <- prepare_export_data(transactions)
    wb <- openxlsx::createWorkbook()
    header_style <- openxlsx::createStyle(
        fontColour = "#FFFFFF",
        fgFill = "#4F81BD",
        halign = "center",
        valign = "center",
        textDecoration = "bold",
        border = "TopBottomLeftRight",
        wrapText = TRUE
    )
    title_style <- openxlsx::createStyle(
        fontSize = 14,
        textDecoration = "bold"
    )
    note_style <- openxlsx::createStyle(
        fontColour = "#666666",
        textDecoration = "italic",
        wrapText = TRUE,
        valign = "top"
    )
    currency_style <- openxlsx::createStyle(numFmt = '#,##0.00 [$€-407]')

    openxlsx::addWorksheet(wb, "EÜR-Übersicht")
    openxlsx::writeData(wb, "EÜR-Übersicht", "Einnahmen- und Ausgabenübersicht", startRow = 1)
    openxlsx::mergeCells(wb, "EÜR-Übersicht", cols = 1:2, rows = 1)
    openxlsx::addStyle(wb, "EÜR-Übersicht", title_style, rows = 1, cols = 1:2)
    openxlsx::writeData(
        wb,
        "EÜR-Übersicht",
        data.frame(
            Angabe = c("Berichtszeitraum", "Anzahl Buchungen", "Erstellt am"),
            Wert = c(
                export_data$reporting_period,
                as.character(export_data$transaction_count),
                format(Sys.Date(), "%d.%m.%Y")
            ),
            stringsAsFactors = FALSE
        ),
        startRow = 3
    )
    openxlsx::writeData(
        wb,
        "EÜR-Übersicht",
        paste(
            "Diese Übersicht ist eine Aufstellung der in Halkhata erfassten Buchungen,",
            "keine amtliche Anlage EÜR und keine steuerliche Prüfung.",
            "Die Beträge und Kategorien sind nicht auf Umsatzsteuer, Abzugsfähigkeit,",
            "Privatanteile oder weitere steuerliche Korrekturen geprüft.",
            "Bitte vor Verwendung mit den Belegen abgleichen und in die amtliche Anlage EÜR übernehmen."
        ),
        startRow = 7,
        colNames = FALSE
    )
    openxlsx::mergeCells(wb, "EÜR-Übersicht", cols = 1:2, rows = 7:8)
    openxlsx::addStyle(wb, "EÜR-Übersicht", note_style, rows = 7:8, cols = 1:2)
    openxlsx::writeData(
        wb,
        "EÜR-Übersicht",
        export_data$summary,
        startRow = 10
    )
    openxlsx::addStyle(wb, "EÜR-Übersicht", header_style, rows = 10, cols = 1:2)
    openxlsx::addStyle(
        wb,
        "EÜR-Übersicht",
        currency_style,
        rows = 11:(10 + nrow(export_data$summary)),
        cols = 2
    )
    openxlsx::setColWidths(wb, "EÜR-Übersicht", cols = 1, widths = 43)
    openxlsx::setColWidths(wb, "EÜR-Übersicht", cols = 2, widths = 22)
    openxlsx::freezePane(wb, "EÜR-Übersicht", firstActiveRow = 10)

    openxlsx::addWorksheet(wb, "Kategorien")
    openxlsx::writeData(wb, "Kategorien", export_data$category_breakdown)
    openxlsx::addStyle(
        wb,
        "Kategorien",
        header_style,
        rows = 1,
        cols = 1:ncol(export_data$category_breakdown),
        gridExpand = TRUE
    )
    if (nrow(export_data$category_breakdown) > 0) {
        openxlsx::addStyle(
            wb,
            "Kategorien",
            currency_style,
            rows = 2:(nrow(export_data$category_breakdown) + 1),
            cols = 4
        )
        openxlsx::addFilter(
            wb,
            "Kategorien",
            rows = 1,
            cols = 1:ncol(export_data$category_breakdown)
        )
    }
    openxlsx::setColWidths(
        wb,
        "Kategorien",
        cols = 1:ncol(export_data$category_breakdown),
        widths = "auto"
    )
    openxlsx::freezePane(wb, "Kategorien", firstActiveRow = 2)

    openxlsx::addWorksheet(wb, "Buchungen")
    openxlsx::writeData(wb, "Buchungen", export_data$transactions)
    openxlsx::addStyle(
        wb,
        "Buchungen",
        header_style,
        rows = 1,
        cols = 1:ncol(export_data$transactions),
        gridExpand = TRUE
    )
    openxlsx::addFilter(
        wb,
        "Buchungen",
        rows = 1,
        cols = 1:ncol(export_data$transactions)
    )
    if (nrow(export_data$transactions) > 0) {
        openxlsx::addStyle(
            wb,
            "Buchungen",
            openxlsx::createStyle(numFmt = "dd.mm.yyyy"),
            rows = 2:(nrow(export_data$transactions) + 1),
            cols = 2
        )
        openxlsx::addStyle(
            wb,
            "Buchungen",
            currency_style,
            rows = 2:(nrow(export_data$transactions) + 1),
            cols = 7
        )
    }
    openxlsx::setColWidths(
        wb,
        "Buchungen",
        cols = 1:ncol(export_data$transactions),
        widths = "auto"
    )
    openxlsx::freezePane(wb, "Buchungen", firstActiveRow = 2)

    openxlsx::saveWorkbook(wb, filename, overwrite = TRUE)
    filename
}
