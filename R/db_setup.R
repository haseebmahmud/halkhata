#' Initialize the database
#' @param db_path Path to the SQLite database
#' @export
setup_database <- function(db_path = "accounting.db") {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con))
  
  # Create transactions table
  if (!DBI::dbExistsTable(con, "transactions")) {
    DBI::dbExecute(con, "
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        attachment_path TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ")
  }
  
  # Create categories table
  if (!DBI::dbExistsTable(con, "categories")) {
    DBI::dbExecute(con, "
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ")
    
    # Insert default categories
    default_categories <- data.frame(
      name = c("Sales", "Services", "Rent", "Utilities", "Salary", "Supplies", "Marketing", "Other"),
      type = c("inflow", "inflow", "outflow", "outflow", "outflow", "outflow", "outflow", "both")
    )
    DBI::dbWriteTable(con, "categories", default_categories, append = TRUE)
  }
}

#' Initialize Database
#'
#' Creates the SQLite database and required tables if they don't exist.
#' Also runs schema migrations for existing databases.
#'
#' @param db_path Path to the SQLite database file
#' @return Invisible NULL
#' @export
init_database <- function(db_path = "accounting.db") {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # ── Migration: rename lowercase type values to Title Case ─────────────────
  # Run before CREATE TABLE so old data is fixed before any new inserts.
  tryCatch(
    {
      # Transactions table
      DBI::dbExecute(con, "UPDATE transactions SET type = 'Inflow'  WHERE type = 'inflow'")
      DBI::dbExecute(con, "UPDATE transactions SET type = 'Outflow' WHERE type = 'outflow'")
      # Categories table
      DBI::dbExecute(con, "UPDATE categories SET type = 'Inflow'  WHERE type = 'inflow'")
      DBI::dbExecute(con, "UPDATE categories SET type = 'Outflow' WHERE type = 'outflow'")
    },
    error = function(e) invisible(NULL)
  ) # tables may not exist yet — safe to ignore

  # ── Migration: recreate transactions with updated CHECK constraint ─────────
  # SQLite doesn't allow ALTER TABLE to change a CHECK constraint, so we
  # recreate the table when the old check (lowercase) still exists.
  tbl_sql <- tryCatch(
    DBI::dbGetQuery(
      con,
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='transactions'"
    )$sql,
    error = function(e) ""
  )
  old_check <- length(tbl_sql) > 0 &&
    !is.na(tbl_sql) &&
    grepl("'inflow'", tbl_sql, fixed = TRUE)

  if (old_check) {
    DBI::dbExecute(con, "PRAGMA foreign_keys = OFF")
    DBI::dbExecute(con, "BEGIN TRANSACTION")
    tryCatch(
      {
        DBI::dbExecute(con, "
            CREATE TABLE transactions_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              type TEXT NOT NULL CHECK(type IN ('Inflow', 'Outflow')),
              amount REAL NOT NULL CHECK(amount > 0),
              category TEXT NOT NULL,
              description TEXT,
              attachment_path TEXT,
              hostname TEXT,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )")
        DBI::dbExecute(con, "
            INSERT INTO transactions_new
              SELECT id, date,
                CASE WHEN type='inflow'  THEN 'Inflow'
                     WHEN type='outflow' THEN 'Outflow'
                     ELSE type END,
                amount, category, description, attachment_path, hostname, created_at
              FROM transactions")
        DBI::dbExecute(con, "DROP TABLE transactions")
        DBI::dbExecute(con, "ALTER TABLE transactions_new RENAME TO transactions")
        DBI::dbExecute(con, "COMMIT")
      },
      error = function(e) {
        DBI::dbExecute(con, "ROLLBACK")
      }
    )
    DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  }

  # ── Create transactions table (new databases) ───────────────────────────
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('Inflow', 'Outflow')),
      amount REAL NOT NULL CHECK(amount > 0),
      category TEXT NOT NULL,
      description TEXT,
      attachment_path TEXT,
      hostname TEXT,
      event TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Migration: add hostname column to databases that pre-date it
  tryCatch(
    DBI::dbExecute(con, "ALTER TABLE transactions ADD COLUMN hostname TEXT"),
    error = function(e) invisible(NULL)
  )

  # Migration: add event column to databases that pre-date it
  tryCatch(
    DBI::dbExecute(con, "ALTER TABLE transactions ADD COLUMN event TEXT"),
    error = function(e) invisible(NULL)
  )

  # ── Create events table ──────────────────────────────────────────────
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL
    )
  ")

  # ── Create categories table ──────────────────────────────────────────────
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('Inflow', 'Outflow', 'both'))
    )
  ")

  # ── Define the canonical set of categories ───────────────────────────────
  canonical_categories <- data.frame(
    name = c(
      # Inflow categories (6)
      "Ticket Sales", "Donations", "Rent", "Membership Fees",
      "Other Income", "Funding",
      # Outflow categories (11)
      "Utilities", "Salaries", "Supplies", "Equipment",
      "Stationaries", "Food and Beverages",
      "Marketing", "Insurance", "Taxes", "Loan Payment", "Other Expense"
    ),
    type = c(
      "Inflow", "Inflow", "Inflow", "Inflow", "Inflow", "Inflow",
      "Outflow", "Outflow", "Outflow", "Outflow", "Outflow", "Outflow",
      "Outflow", "Outflow", "Outflow", "Outflow", "Outflow"
    ),
    stringsAsFactors = FALSE
  )

  # Remove any stale categories not in the canonical list
  canonical_names_sql <- paste0(
    "'", paste(canonical_categories$name, collapse = "','"), "'"
  )
  tryCatch(
    DBI::dbExecute(con, sprintf(
      "DELETE FROM categories WHERE name NOT IN (%s)", canonical_names_sql
    )),
    error = function(e) invisible(NULL)
  )

  # Upsert: insert canonical categories that don't exist yet; update type if changed
  for (i in seq_len(nrow(canonical_categories))) {
    tryCatch(
      DBI::dbExecute(
        con,
        "INSERT INTO categories (name, type) VALUES (?, ?)
                 ON CONFLICT(name) DO UPDATE SET type = excluded.type",
        params = list(canonical_categories$name[i], canonical_categories$type[i])
      ),
      error = function(e) invisible(NULL)
    )
  }

  DBI::dbDisconnect(con)
  invisible(NULL)
}

#' Get Database Connection
#'
#' Opens a connection to the SQLite database.
#'
#' @param db_path Path to the SQLite database file
#' @return A DBI connection object
#' @export
get_db_connection <- function(db_path = "accounting.db") {
  DBI::dbConnect(RSQLite::SQLite(), db_path)
}
