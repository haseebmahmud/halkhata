library(RSQLite)

filename <- "/inst/shiny-app/accounting.db"
sqlite.driver <- dbDriver("SQLite")
db <- dbConnect(sqlite.driver,
                dbname = filename)

## Some operations
dbListTables(db)
mytable <- dbReadTable(db,"transactions")
