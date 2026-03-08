# Test script for halkhata package
# This script tests the basic functionality of the accounting app

library(halkhata)

# Set up test database
test_db <- "test_accounting.db"
test_attachments <- "test_attachments"

# Clean up any existing test files
if (file.exists(test_db)) file.remove(test_db)
if (dir.exists(test_attachments)) unlink(test_attachments, recursive = TRUE)

# Initialize database
cat("Testing database initialization...\n")
init_database(test_db)
cat("✓ Database initialized\n\n")

# Get connection
con <- get_db_connection(test_db)

# Test adding transactions
cat("Testing transaction operations...\n")

# Add inflow transaction
id1 <- add_transaction(
    con,
    date = Sys.Date(),
    type = "inflow",
    amount = 1000.00,
    category = "Sales",
    description = "Test sale transaction"
)
cat(sprintf("✓ Added inflow transaction (ID: %d)\n", id1))

# Add outflow transaction
id2 <- add_transaction(
    con,
    date = Sys.Date() - 1,
    type = "outflow",
    amount = 250.50,
    category = "Rent",
    description = "Monthly rent payment"
)
cat(sprintf("✓ Added outflow transaction (ID: %d)\n", id2))

# Get all transactions
transactions <- get_transactions(con)
cat(sprintf("✓ Retrieved %d transactions\n\n", nrow(transactions)))

# Test balance calculation
cat("Testing report functions...\n")
balance <- calculate_balance(transactions)
cat(sprintf("✓ Calculated balance: $%.2f\n", balance))

# Test periodic summary
summary <- get_periodic_summary(transactions, "day")
cat(sprintf("✓ Generated periodic summary (%d periods)\n", nrow(summary)))

# Test category breakdown
breakdown <- get_category_breakdown(transactions)
cat(sprintf("✓ Generated category breakdown (%d categories)\n\n", nrow(breakdown)))

# Test Excel export
cat("Testing Excel export...\n")
export_file <- "test_export.xlsx"
export_to_excel(transactions, export_file)
if (file.exists(export_file)) {
    cat(sprintf("✓ Excel file created: %s\n", export_file))
    file.info(export_file)$size
    cat(sprintf("  File size: %d bytes\n\n", file.info(export_file)$size))
}

# Test categories
cat("Testing category retrieval...\n")
all_cats <- get_categories(con)
cat(sprintf("✓ Retrieved %d categories\n", nrow(all_cats)))

inflow_cats <- get_categories(con, "inflow")
cat(sprintf("✓ Retrieved %d inflow categories\n", nrow(inflow_cats)))

outflow_cats <- get_categories(con, "outflow")
cat(sprintf("✓ Retrieved %d outflow categories\n\n", nrow(outflow_cats)))

# Close connection
dbDisconnect(con)

# Summary
cat("===========================================\n")
cat("All tests completed successfully!\n")
cat("===========================================\n\n")

cat("Summary:\n")
cat(sprintf("- Database: %s\n", test_db))
cat(sprintf("- Transactions: %d\n", nrow(transactions)))
cat(sprintf("- Balance: $%.2f\n", balance))
cat(sprintf("- Export file: %s\n", export_file))

cat("\nTo launch the app, run:\n")
cat("  library(halkhata)\n")
cat("  run_accounting_app()\n")
