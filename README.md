
# halkhata - Small Business Accounting App

A comprehensive R Shiny application for small business accounting. Track cash inflows and outflows, attach bills and receipts, generate periodic reports, and export data to Excel for tax filing.

## Features

- **Transaction Management**: Add, view, and manage cash inflows and outflows
- **File Attachments**: Attach bills and receipts (PDF, PNG, JPG) to transactions
- **Interactive Dashboard**: Visualize financial data with charts and summary metrics
- **Periodic Reports**: Generate daily, weekly, monthly, or yearly financial summaries
- **Category Breakdown**: Analyze spending and income by category
- **Excel Export**: Export transaction records and summaries as a reviewable workbook
- **SQLite Database**: Lightweight, file-based data storage with no server required

## Installation

### Install Required Packages

```r
user_library <- Sys.getenv("R_LIBS_USER")
dir.create(user_library, recursive = TRUE, showWarnings = FALSE)

# Install dependencies in the per-user library (no administrator access needed)
install.packages(c(
  "shiny",
  "shinydashboard",
  "DBI",
  "RSQLite",
  "dplyr",
  "lubridate",
  "openxlsx",
  "DT",
  "plotly",
  "RColorBrewer"
), lib = user_library, repos = "https://cloud.r-project.org")
```

## Usage

### Launch the App

```r
library(halkhata)

# Run with default settings (creates accounting.db in current directory)
run_accounting_app()

# Or specify custom paths
run_accounting_app(
  db_path = "my_accounting.db",
  attachments_dir = "my_attachments"
)
```

### Launch in an Electron Desktop Window

The Electron shell runs the Shiny app on a local-only server and displays it in
a desktop window. R and the `halkhata` package must be installed on the system
along with the packages listed under
[Install Required Packages](#install-required-packages) before running the
desktop app:

```sh
R CMD INSTALL --library="$(Rscript --vanilla -e 'cat(Sys.getenv("R_LIBS_USER"))')" .
npm install
npm start
```

The desktop app stores its SQLite database and attachments in Electron's
per-user application data directory. If `Rscript` is not on `PATH`, set
`RSCRIPT_PATH` to its full path before running `npm start`.

#### Data Storage and Backups

On macOS, the data directory is normally
`~/Library/Application Support/Halkhata/`. It contains `accounting.db` and the
`attachments/` folder. The exact directory is determined by Electron's
`app.getPath("userData")`.

Back up the entire data directory, not just the database. Time Machine can back
it up; check that the directory is included. For a manual backup, quit Halkhata
first, then copy the entire directory to an encrypted external drive. Keep
dated backups and periodically verify that a backup can be opened. Excel
exports are useful reports, but they are not complete, restorable backups.

### Build a Standalone Installer

The desktop installer does not bundle R, `halkhata`, or its R dependencies.
Users must install them separately before launching the app. On an Apple Silicon
Mac, build a `.dmg` with:

```sh
npm run dist:mac
```

The macOS DMG contains the app. Windows `.exe` installers are built by the
**Desktop installers** GitHub Actions workflow on a Windows runner. Workflow
artifacts contain the installers for both platforms.

Installers are unsigned, so macOS Gatekeeper and Windows SmartScreen may show
warnings.

### Using the App

#### 1. Dashboard
- View key financial metrics: total inflows, outflows, and net balance
- Interactive charts showing trends over time
- Category breakdowns with pie charts
- Customize date range to focus on specific periods

#### 2. Add Transaction
- Enter transaction details: date, type (inflow/outflow), amount, category
- Add optional description
- Attach bills or receipts (PDF or images)
- View recent transactions

#### 3. View Transactions
- Browse all transactions in a searchable, sortable table
- Filter by date range, type, or category
- Export filtered data to Excel

#### 4. Reports
- Generate periodic summaries (daily, weekly, monthly, yearly)
- View category breakdowns
- Analyze financial trends

### Excel Export

The Excel export feature creates a formatted workbook with three sheets:

1. **EÜR-Übersicht**: Recorded income, expenses, and preliminary surplus/loss
2. **Kategorien**: Recorded totals and transaction counts by category
3. **Buchungen**: Chronological transaction details and attached receipt filenames

On the Reports page, use **Generate and Save Excel Report** to open a save
dialog and choose the workbook location. **Update Report** refreshes the
on-screen summaries.

This workbook is a supporting transaction schedule, **not** the official
Anlage EÜR and not a substitute for filing it. It does not determine VAT,
deductibility, private-use shares, depreciation, or other tax adjustments.
Reconcile the records and transfer the applicable figures to the official
Anlage EÜR before filing.

## Database Schema

The app uses SQLite with two main tables:

### Transactions Table
- `id`: Unique transaction identifier
- `date`: Transaction date
- `type`: "inflow" or "outflow"
- `amount`: Transaction amount
- `category`: Transaction category
- `description`: Optional description
- `attachment_path`: Path to attached file
- `created_at`: Timestamp

### Categories Table
- `id`: Unique category identifier
- `name`: Category name
- `type`: "inflow", "outflow", or "both"

Default categories are automatically created on first run.

## File Structure

```
halkhata/
├── R/
│   ├── db_setup.R           # Database initialization
│   ├── db_operations.R      # CRUD operations
│   ├── file_handler.R       # File attachment management
│   ├── reports.R            # Report generation
│   ├── excel_export.R       # Excel export functionality
│   └── run_app.R            # App launcher
├── inst/
│   └── shiny-app/
│       ├── app.R            # Main Shiny application
│       └── www/
│           └── styles.css   # Custom styling
├── DESCRIPTION
├── NAMESPACE
└── README.md
```

## Development

### Building the Package

```r
# Load package for development
devtools::load_all()

# Generate documentation
devtools::document()

# Check package
devtools::check()
```

## License

MIT License - see LICENSE.md for details

## Author

Developed for small business accounting needs.

<!-- badges: start -->
<!-- badges: end -->

The goal of halkhata is to ...

