library(shiny)
library(shinydashboard)
library(DT)
library(plotly)

ui <- dashboardPage(
    dashboardHeader(title = "halkhata"),
    dashboardSidebar(
        sidebarMenu(
            menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
            menuItem("Add Transaction", tabName = "add_transaction", icon = icon("plus")),
            menuItem("View Transactions", tabName = "view_transactions", icon = icon("table")),
            menuItem("Reports", tabName = "reports", icon = icon("chart-bar"))
        )
    ),
    dashboardBody(
        tabItems(
            tabItem(
                tabName = "dashboard",
                h2("Halkhata Dashboard"),
                fluidRow(
                    valueBoxOutput("total_inflow"),
                    valueBoxOutput("total_outflow"),
                    valueBoxOutput("net_balance")
                )
            ),
            tabItem(
                tabName = "add_transaction",
                h2("Add New Transaction")
            ),
            tabItem(
                tabName = "view_transactions",
                h2("Transaction History")
            ),
            tabItem(
                tabName = "reports",
                h2("Financial Reports")
            )
        )
    )
)

server <- function(input, output, session) {
    # Placeholder for server logic
}

shinyApp(ui, server)

# Accounting Shiny App
# Main application file

# Suppress R CMD check warnings for dplyr NSE
utils::globalVariables(c("type", "name", "amount", "category", "description", "attachment_path", "hostname", "event"))

library(shiny)
library(shinydashboard)
library(DBI)
library(RSQLite)
library(dplyr)
library(lubridate)
library(openxlsx)
library(DT)
library(plotly)

# Get database path from options or use default
db_path <- getOption("halkhata.db_path", "accounting.db")
attachments_dir <- getOption("halkhata.attachments_dir", "attachments")

# Initialize database if not already done
halkhata::init_database(db_path)

# Create attachments directory if needed
if (!dir.exists(attachments_dir)) {
    dir.create(attachments_dir, recursive = TRUE)
}

# Capture the hostname / username of this machine once at startup
app_hostname <- tryCatch(Sys.info()[["nodename"]], error = function(e) Sys.getenv("USERNAME"))

# UI Definition
ui <- dashboardPage(
    skin = "blue",

    # Header
    dashboardHeader(title = "Accounting App"),

    # Sidebar
    dashboardSidebar(
        sidebarMenu(
            menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
            menuItem("Add Transaction", tabName = "add_transaction", icon = icon("plus-circle")),
            menuItem("View Transactions", tabName = "view_transactions", icon = icon("table")),
            menuItem("Reports", tabName = "reports", icon = icon("chart-bar"))
        )
    ),

    # Body
    dashboardBody(
        tags$head(
            tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
            # JS helper: relay row-level button clicks back to Shiny
            tags$script(HTML("
                function editTransaction(id) {
                    Shiny.setInputValue('edit_transaction_id', id, {priority: 'event'});
                }
                function deleteTransaction(id) {
                    Shiny.setInputValue('delete_transaction_id', id, {priority: 'event'});
                }
            "))
        ),
        tabItems(
            # Dashboard tab
            tabItem(
                tabName = "dashboard",
                h2("Halkhata Dashboard"),
                fluidRow(
                    box(
                        width = 12,
                        dateRangeInput(
                            "dashboard_date_range",
                            "Select Date Range:",
                            start = floor_date(Sys.Date(), "year"),
                            end = Sys.Date(),
                            max = Sys.Date()
                        ),
                        actionButton("refresh_dashboard", "Refresh", icon = icon("sync"))
                    )
                ),
                fluidRow(
                    valueBoxOutput("total_inflow_box", width = 4),
                    valueBoxOutput("total_outflow_box", width = 4),
                    valueBoxOutput("balance_box", width = 4)
                ),
                fluidRow(
                    box(
                        width = 12, title = "Inflows vs Outflows Over Time",
                        status = "primary", solidHeader = TRUE,
                        plotlyOutput("time_series_chart", height = 300)
                    )
                ),
                fluidRow(
                    box(
                        width = 6, title = "Inflow Categories",
                        status = "success", solidHeader = TRUE,
                        plotlyOutput("inflow_pie_chart", height = 300)
                    ),
                    box(
                        width = 6, title = "Outflow Categories",
                        status = "danger", solidHeader = TRUE,
                        plotlyOutput("outflow_pie_chart", height = 300)
                    )
                )
            ),

            # Add Transaction tab
            tabItem(
                tabName = "add_transaction",
                h2("Add New Transaction"),
                fluidRow(
                    box(
                        width = 6, title = "Transaction Details",
                        status = "primary", solidHeader = TRUE,
                        dateInput("trans_date", "Date:", value = Sys.Date(), max = Sys.Date()),
                        selectInput("trans_type", "Type:",
                            choices = c("Inflow" = "Inflow", "Outflow" = "Outflow"),
                            selected = "Inflow"
                        ),
                        numericInput("trans_amount", "Amount:", value = 0, min = 0, step = 0.01),
                        tags$div(
                            style = "display: flex; align-items: flex-end; margin-bottom: 15px;",
                            tags$div(style = "flex-grow: 1; margin-bottom: 0px;", div(style = "margin-bottom: 0px;", selectInput("trans_category", "Category:", choices = NULL, width = "100%"))),
                            actionButton("add_new_category_btn", "", icon = icon("plus"), style = "margin-left: 5px; height: 34px;")
                        ),
                        tags$div(
                            style = "display: flex; align-items: flex-end; margin-bottom: 15px;",
                            tags$div(style = "flex-grow: 1; margin-bottom: 0px;", div(style = "margin-bottom: 0px;", selectInput("trans_event", "Event:", choices = c("None" = ""), width = "100%"))),
                            actionButton("add_new_event_btn", "", icon = icon("plus"), style = "margin-left: 5px; height: 34px;")
                        ),
                        textAreaInput("trans_description", "Description:",
                            rows = 3,
                            placeholder = "Enter transaction description..."
                        ),
                        fileInput("trans_attachment", "Attach Bill/Receipt (PDF or Image):",
                            accept = c(".pdf", ".png", ".jpg", ".jpeg")
                        ),
                        actionButton("submit_transaction", "Submit",
                            icon = icon("check"), class = "btn-success"
                        ),
                        actionButton("reset_form", "Reset",
                            icon = icon("undo"), class = "btn-secondary"
                        )
                    ),
                    box(
                        width = 6, title = "Recent Transactions",
                        status = "info", solidHeader = TRUE,
                        DTOutput("recent_transactions_table")
                    )
                )
            ),

            # View Transactions tab
            tabItem(
                tabName = "view_transactions",
                h2("All Transactions"),
                fluidRow(
                    box(
                        width = 12, title = "Filters",
                        status = "primary", collapsible = TRUE,
                        fluidRow(
                            column(
                                width = 3,
                                dateRangeInput("filter_date_range", "Date Range:",
                                    start = Sys.Date() - 365, end = Sys.Date()
                                )
                            ),
                            column(
                                width = 3,
                                selectInput("filter_type", "Type:",
                                    choices = c("All" = "", "Inflow" = "Inflow", "Outflow" = "Outflow")
                                )
                            ),
                            column(
                                width = 3,
                                selectInput("filter_category", "Category:", choices = c("All" = ""))
                            ),
                            column(
                                width = 3,
                                selectInput("filter_event", "Event:", choices = c("All" = ""))
                            )
                        ),
                        actionButton("apply_filters", "Apply Filters",
                            icon = icon("filter"), class = "btn-primary"
                        ),
                        downloadButton("export_excel", "Export to Excel", class = "btn-success")
                    )
                ),
                fluidRow(
                    box(
                        width = 12, title = "Transactions",
                        status = "primary", solidHeader = TRUE,
                        DTOutput("all_transactions_table")
                    )
                )
            ),

            # Reports tab
            tabItem(
                tabName = "reports",
                h2("Financial Reports"),
                fluidRow(
                    box(
                        width = 12,
                        dateRangeInput("report_date_range", "Select Date Range:",
                            start = floor_date(Sys.Date(), "year"), end = Sys.Date()
                        ),
                        selectInput("report_period", "Aggregation Period:",
                            choices = c(
                                "Daily" = "day", "Weekly" = "week",
                                "Monthly" = "month", "Yearly" = "year"
                            ),
                            selected = "month"
                        ),
                        actionButton("generate_report", "Update Report",
                            icon = icon("chart-line"), class = "btn-primary"
                        ),
                        downloadButton(
                            "export_report_excel",
                            "Generate and Save Excel Report",
                            class = "btn-success"
                        ),
                        helpText("Choose where to save the generated Excel report.")
                    )
                ),
                fluidRow(
                    box(
                        width = 12, title = "Periodic Summary",
                        status = "primary", solidHeader = TRUE,
                        DTOutput("periodic_summary_table")
                    )
                ),
                fluidRow(
                    box(
                        width = 12, title = "Category Breakdown",
                        status = "info", solidHeader = TRUE,
                        DTOutput("category_breakdown_table")
                    )
                ),
                fluidRow(
                    box(
                        width = 12, title = "Event Breakdown",
                        status = "warning", solidHeader = TRUE,
                        DTOutput("event_breakdown_table")
                    )
                )
            )
        )
    )
)

# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {
    # Serve the attachments directory as a static resource
    shiny::addResourcePath("attachments", normalizePath(attachments_dir, mustWork = FALSE))

    # Reactive values
    rv <- reactiveValues(
        transactions    = NULL,
        categories      = NULL,
        events          = NULL,
        refresh_trigger = 0
    )

    # DB connection helper
    get_con <- function() halkhata::get_db_connection(db_path)

    # ── Categories & Events ─────────────────────────────────────────────────────────────
    observe({
        rv$refresh_trigger
        con <- get_con()
        rv$categories <- halkhata::get_categories(con)
        tryCatch(
            {
                rv$events <- halkhata::get_events(con)
            },
            error = function(e) rv$events <- data.frame(name = character())
        )
        DBI::dbDisconnect(con)
    })

    observe({
        req(rv$categories)
        cats <- if (tolower(input$trans_type) == "inflow") {
            rv$categories %>%
                filter(tolower(type) %in% c("inflow", "both")) %>%
                pull(name)
        } else {
            rv$categories %>%
                filter(tolower(type) %in% c("outflow", "both")) %>%
                pull(name)
        }
        updateSelectInput(session, "trans_category", choices = cats)
    })

    observe({
        req(rv$categories)
        updateSelectInput(session, "filter_category",
            choices = c("All" = "", setNames(rv$categories$name, rv$categories$name))
        )
    })

    observe({
        req(rv$events)
        updateSelectInput(session, "trans_event", choices = c("None" = "", setNames(rv$events$name, rv$events$name)))
        updateSelectInput(session, "filter_event", choices = c("All" = "", setNames(rv$events$name, rv$events$name)))
    })

    # ── Add Category / Event Modals ──────────────────────────────────────────────
    observeEvent(input$add_new_category_btn, {
        showModal(modalDialog(
            title = "Add New Category",
            textInput("new_category_name", "Category Name:"),
            selectInput("new_category_type", "Type:", choices = c("Inflow" = "Inflow", "Outflow" = "Outflow", "Both" = "both")),
            footer = tagList(
                actionButton("confirm_add_category", "Add", class = "btn-success"),
                modalButton("Cancel")
            ),
            easyClose = TRUE
        ))
    })

    observeEvent(input$confirm_add_category, {
        req(input$new_category_name)
        tryCatch(
            {
                con <- get_con()
                halkhata::add_category(con, input$new_category_name, input$new_category_type)
                DBI::dbDisconnect(con)
                removeModal()
                rv$refresh_trigger <- rv$refresh_trigger + 1
                showNotification("Category added successfully!", type = "message")
            },
            error = function(e) {
                showNotification(paste("Error:", e$message), type = "error")
            }
        )
    })

    observeEvent(input$add_new_event_btn, {
        showModal(modalDialog(
            title = "Add New Event",
            textInput("new_event_name", "Event Name:"),
            footer = tagList(
                actionButton("confirm_add_event", "Add", class = "btn-success"),
                modalButton("Cancel")
            ),
            easyClose = TRUE
        ))
    })

    observeEvent(input$confirm_add_event, {
        req(input$new_event_name)
        tryCatch(
            {
                con <- get_con()
                halkhata::add_event(con, input$new_event_name)
                DBI::dbDisconnect(con)
                removeModal()
                rv$refresh_trigger <- rv$refresh_trigger + 1
                showNotification("Event added successfully!", type = "message")
            },
            error = function(e) {
                showNotification(paste("Error:", e$message), type = "error")
            }
        )
    })

    # ── Submit transaction ──────────────────────────────────────────────────────
    observeEvent(input$submit_transaction, {
        req(input$trans_amount > 0)
        tryCatch(
            {
                attachment_path <- NULL
                if (!is.null(input$trans_attachment)) {
                    attachment_path <- halkhata::save_attachment(input$trans_attachment, attachments_dir)
                }
                con <- get_con()
                halkhata::add_transaction(
                    con,
                    date            = input$trans_date,
                    type            = input$trans_type,
                    amount          = input$trans_amount,
                    category        = input$trans_category,
                    description     = input$trans_description,
                    attachment_path = attachment_path,
                    hostname        = app_hostname,
                    event           = input$trans_event
                )
                DBI::dbDisconnect(con)
                rv$refresh_trigger <- rv$refresh_trigger + 1
                showNotification("Transaction added successfully!", type = "message")
            },
            error = function(e) {
                showNotification(paste("Error:", e$message), type = "error")
            }
        )
    })

    # Reset form
    observeEvent(input$reset_form, {
        updateDateInput(session, "trans_date", value = Sys.Date())
        updateSelectInput(session, "trans_type", selected = "Inflow")
        updateNumericInput(session, "trans_amount", value = 0)
        updateTextAreaInput(session, "trans_description", value = "")
        updateSelectInput(session, "trans_event", selected = "")
    })

    # ── Recent transactions ────────────────────────────────────────────────────
    output$recent_transactions_table <- renderDT({
        rv$refresh_trigger
        con <- get_con()
        trans <- halkhata::get_transactions(con)
        DBI::dbDisconnect(con)
        if (nrow(trans) > 0) {
            trans <- trans %>%
                select(date, type, amount, category, event) %>%
                head(10)
        }
        datatable(trans, options = list(pageLength = 5, dom = "t"), rownames = FALSE, colnames = c("Date", "Type", "Amount", "Category", "Event"))
    })

    # ── Dashboard ──────────────────────────────────────────────────────────────
    dashboard_data <- reactive({
        input$refresh_dashboard
        rv$refresh_trigger
        con <- get_con()
        trans <- halkhata::get_transactions(con,
            start_date = input$dashboard_date_range[1],
            end_date   = input$dashboard_date_range[2]
        )
        DBI::dbDisconnect(con)
        trans
    })

    output$total_inflow_box <- renderValueBox({
        total <- sum(dashboard_data()$amount[dashboard_data()$type == "Inflow"], na.rm = TRUE)
        valueBox(sprintf("€%.2f", total), "Total Inflows", icon = icon("arrow-up"), color = "green")
    })

    output$total_outflow_box <- renderValueBox({
        total <- sum(dashboard_data()$amount[dashboard_data()$type == "Outflow"], na.rm = TRUE)
        valueBox(sprintf("€%.2f", total), "Total Outflows", icon = icon("arrow-down"), color = "red")
    })

    output$balance_box <- renderValueBox({
        balance <- halkhata::calculate_balance(dashboard_data())
        valueBox(sprintf("€%.2f", balance), "Net Balance",
            icon  = icon("balance-scale"),
            color = if (balance >= 0) "blue" else "red"
        )
    })

    output$time_series_chart <- renderPlotly({
        trans <- dashboard_data()
        if (nrow(trans) == 0) {
            return(plotly_empty())
        }
        summary <- halkhata::get_periodic_summary(trans, "day")
        plot_ly(summary, x = ~period) %>%
            add_trace(
                y = ~inflows, name = "Inflows", type = "scatter",
                mode = "lines+markers", line = list(color = "#28a745")
            ) %>%
            add_trace(
                y = ~outflows, name = "Outflows", type = "scatter",
                mode = "lines+markers", line = list(color = "#dc3545")
            ) %>%
            layout(
                xaxis = list(title = "Date"), yaxis = list(title = "Amount"),
                hovermode = "x unified"
            )
    })

    output$inflow_pie_chart <- renderPlotly({
        trans <- dashboard_data()
        if (nrow(trans) == 0) {
            return(plotly_empty())
        }
        breakdown <- halkhata::get_category_breakdown(trans, "Inflow")
        if (nrow(breakdown) == 0) {
            return(plotly_empty())
        }
        plot_ly(breakdown,
            labels = ~category, values = ~total, type = "pie",
            marker = list(colors = RColorBrewer::brewer.pal(max(3, nrow(breakdown)), "Greens"))
        ) %>%
            layout(showlegend = TRUE)
    })

    output$outflow_pie_chart <- renderPlotly({
        trans <- dashboard_data()
        if (nrow(trans) == 0) {
            return(plotly_empty())
        }
        breakdown <- halkhata::get_category_breakdown(trans, "Outflow")
        if (nrow(breakdown) == 0) {
            return(plotly_empty())
        }
        plot_ly(breakdown,
            labels = ~category, values = ~total, type = "pie",
            marker = list(colors = RColorBrewer::brewer.pal(max(3, nrow(breakdown)), "Reds"))
        ) %>%
            layout(showlegend = TRUE)
    })

    # ── All Transactions (with clickable attachment & edit/delete buttons) ─────
    filtered_transactions <- reactive({
        input$apply_filters
        rv$refresh_trigger
        con <- get_con()
        trans <- halkhata::get_transactions(con,
            start_date = input$filter_date_range[1],
            end_date   = input$filter_date_range[2],
            type       = if (input$filter_type != "") input$filter_type else NULL,
            category   = if (input$filter_category != "") input$filter_category else NULL,
            event      = if (input$filter_event != "") input$filter_event else NULL
        )
        DBI::dbDisconnect(con)
        trans
    })

    # Helper: build a clickable attachment link from the stored path
    make_attachment_link <- function(path) {
        if (is.na(path) || path == "") {
            return("")
        }
        # Extract just the filename to build the Shiny-served URL
        filename <- basename(path)
        sprintf('<a href="attachments/%s" target="_blank" title="View attachment">&#128206;</a>', filename)
    }

    output$all_transactions_table <- renderDT({
        trans <- filtered_transactions()

        if (nrow(trans) > 0) {
            trans <- trans %>%
                select(id, date, type, amount, category, event, description, attachment_path, hostname)

            trans$attachment <- sapply(trans$attachment_path, make_attachment_link)

            # Per-row edit and delete buttons
            trans$actions <- sprintf(
                '<button class="btn btn-xs btn-warning" onclick="editTransaction(%d)" title="Edit">&#9998;</button> <button class="btn btn-xs btn-danger" onclick="deleteTransaction(%d)" title="Delete">&#128465;</button>',
                trans$id, trans$id
            )

            trans <- trans %>% select(id, date, type, amount, category, event, description, attachment, hostname, actions)
        }

        datatable(
            trans,
            escape = FALSE, # render HTML links and buttons
            options = list(pageLength = 25, order = list(list(1, "desc"))),
            rownames = FALSE,
            colnames = c("ID", "Date", "Type", "Amount", "Category", "Event", "Description", "Attachment", "Hostname", "Actions")
        )
    })

    # ── Edit transaction modal ─────────────────────────────────────────────────
    observeEvent(input$edit_transaction_id, {
        id <- input$edit_transaction_id
        con <- get_con()
        row <- DBI::dbGetQuery(con, "SELECT * FROM transactions WHERE id = ?", params = list(id))
        DBI::dbDisconnect(con)
        req(nrow(row) > 0)

        showModal(modalDialog(
            title = paste("Edit Transaction #", id),
            footer = tagList(
                actionButton("confirm_edit", "Save Changes", class = "btn-success"),
                modalButton("Cancel")
            ),
            # Hidden field to carry the id
            tags$input(type = "hidden", id = "edit_id", value = id),
            dateInput("edit_date", "Date:", value = as.Date(row$date)),
            selectInput("edit_type",   "Type:",
                choices  = c("Inflow" = "Inflow", "Outflow" = "Outflow"),
                selected = ifelse(tolower(row$type) == "inflow", "Inflow", "Outflow")
            ),
            numericInput("edit_amount", "Amount:", value = row$amount, min = 0, step = 0.01),
            selectInput("edit_category", "Category:", choices = {
                con2 <- get_con()
                cats <- halkhata::get_categories(con2)
                DBI::dbDisconnect(con2)
                setNames(cats$name, cats$name)
            }, selected = row$category),
            selectInput("edit_event", "Event:", choices = {
                con3 <- get_con()
                evts <- tryCatch(halkhata::get_events(con3)$name, error = function(e) character(0))
                DBI::dbDisconnect(con3)
                c("None" = "", setNames(evts, evts))
            }, selected = row$event %||% ""),
            textAreaInput("edit_description", "Description:", value = row$description %||% "", rows = 3),
            easyClose = TRUE
        ))
    })

    # Null-coalescing operator helper
    `%||%` <- function(a, b) if (!is.null(a) && !is.na(a)) a else b

    observeEvent(input$confirm_edit, {
        id <- isolate(input$edit_transaction_id)
        req(!is.null(id))
        tryCatch(
            {
                con <- get_con()
                halkhata::update_transaction(
                    con,
                    id = id,
                    date = input$edit_date,
                    type = input$edit_type,
                    amount = input$edit_amount,
                    category = input$edit_category,
                    description = input$edit_description,
                    event = input$edit_event
                )
                DBI::dbDisconnect(con)
                removeModal()
                rv$refresh_trigger <- rv$refresh_trigger + 1
                showNotification("Transaction updated successfully!", type = "message")
            },
            error = function(e) {
                showNotification(paste("Error:", e$message), type = "error")
            }
        )
    })

    # ── Delete transaction modal ───────────────────────────────────────────────
    observeEvent(input$delete_transaction_id, {
        id <- input$delete_transaction_id
        showModal(modalDialog(
            title = "Confirm Delete",
            paste0("Are you sure you want to delete transaction #", id, "? This cannot be undone."),
            footer = tagList(
                actionButton("confirm_delete", "Delete", class = "btn-danger"),
                modalButton("Cancel")
            ),
            easyClose = TRUE
        ))
    })

    observeEvent(input$confirm_delete, {
        id <- isolate(input$delete_transaction_id)
        req(!is.null(id))
        tryCatch(
            {
                con <- get_con()
                halkhata::delete_transaction(con, id)
                DBI::dbDisconnect(con)
                removeModal()
                rv$refresh_trigger <- rv$refresh_trigger + 1
                showNotification("Transaction deleted.", type = "warning")
            },
            error = function(e) {
                showNotification(paste("Error:", e$message), type = "error")
            }
        )
    })

    # ── Export to Excel ────────────────────────────────────────────────────────
    output$export_excel <- downloadHandler(
        filename = function() paste0("accounting_report_", format(Sys.Date(), "%Y%m%d"), ".xlsx"),
        content = function(file) {
            halkhata::export_to_excel(filtered_transactions(), file)
        }
    )

    # ── Reports ────────────────────────────────────────────────────────────────
    report_data <- reactive({
        input$generate_report
        rv$refresh_trigger
        con <- get_con()
        trans <- halkhata::get_transactions(con,
            start_date = input$report_date_range[1],
            end_date   = input$report_date_range[2]
        )
        DBI::dbDisconnect(con)
        trans
    })

    output$periodic_summary_table <- renderDT({
        trans <- report_data()
        if (nrow(trans) == 0) {
            return(datatable(data.frame()))
        }
        summary <- halkhata::get_periodic_summary(trans, input$report_period)
        datatable(summary, options = list(pageLength = 25), rownames = FALSE, colnames = c("Period", "Inflows", "Outflows", "Balance")) %>%
            formatCurrency(c("inflows", "outflows", "balance"), "€")
    })

    output$category_breakdown_table <- renderDT({
        trans <- report_data()
        if (nrow(trans) == 0) {
            return(datatable(data.frame()))
        }
        breakdown <- halkhata::get_category_breakdown(trans)
        datatable(breakdown, options = list(pageLength = 25), rownames = FALSE, colnames = c("Category", "Type", "Total", "Count")) %>%
            formatCurrency("total", "€")
    })

    output$event_breakdown_table <- renderDT({
        trans <- report_data()
        if (nrow(trans) == 0) {
            return(datatable(data.frame()))
        }
        breakdown <- halkhata::get_event_breakdown(trans)
        datatable(breakdown, options = list(pageLength = 25), rownames = FALSE, colnames = c("Event", "Inflows", "Outflows", "Balance")) %>%
            formatCurrency(c("inflows", "outflows", "balance"), "€")
    })

    output$export_report_excel <- downloadHandler(
        filename = function() {
            report_dates <- input$report_date_range
            paste0(
                "eur_report_",
                format(report_dates[1], "%Y%m%d"),
                "_",
                format(report_dates[2], "%Y%m%d"),
                ".xlsx"
            )
        },
        content = function(file) {
            halkhata::export_to_excel(report_data(), file)
        }
    )
}

# Run the application
shinyApp(ui = ui, server = server)
