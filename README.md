
# halkhata - Small Business Accounting App

A comprehensive R Shiny application for small business accounting. Track cash inflows and outflows, attach bills and receipts, generate periodic reports, and export data to Excel for tax filing.

## Features

- **Transaction Management**: Add, view, and manage cash inflows and outflows
- **File Attachments**: Attach bills and receipts (PDF, PNG, JPG) to transactions
- **Interactive Dashboard**: Visualize financial data with charts and summary metrics
- **Periodic Reports**: Generate daily, weekly, monthly, or yearly financial summaries
- **Category Breakdown**: Analyze spending and income by category
- **Excel Export**: Export transaction data to formatted Excel workbooks for tax filing
- **SQLite Database**: Lightweight, file-based data storage with no server required

## Installation

### Install Required Packages

```r
# Install from CRAN (if available) or from source
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
))

# Install halkhata package (from local directory)
devtools::install()
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
a desktop window. This development setup requires R and the `halkhata` package
to be installed:

```sh
R CMD INSTALL .
npm install
npm start
```

The desktop app stores its SQLite database and attachments in Electron's
per-user application data directory. If `Rscript` is not on `PATH`, set
`RSCRIPT_PATH` to its full path before running `npm start`.

### Build a Standalone Installer

The standalone build bundles the current platform's R runtime and package
dependencies. On an Apple Silicon Mac, build a `.dmg` with:

```sh
npm run dist:mac
```

The macOS DMG contains a `.pkg` installer. It installs the app in
`/Applications` and activates its bundled R under `/Library/Frameworks`
(administrator approval is required; this changes the system's active R
framework version). Windows `.exe` installers are built by the **Desktop installers**
GitHub Actions workflow on a Windows runner and include a private Windows R
runtime. Workflow artifacts contain the installers for both platforms.

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

1. **Transactions**: Complete transaction history with all details
2. **Summary**: Key metrics including total inflows, outflows, and balance
3. **Category Breakdown**: Spending and income analysis by category

Perfect for tax filing and financial record-keeping!

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

