# Please restore the renv file first:
# if you have not installed renv, please first install: install.packages("renv")
renv::activate()
#renv::restore()

library("odbc")
library("RPostgres")
library("DBI")
library("dplyr")
library("dbplyr")
library("CirceR")
library("CDMConnector")
library("here")
library("log4r")
library("zip")
library("DrugExposureDiagnostics")

##TEST PASI's Idea
extralibpath = "C:/Users/HUS72904793/AppData/Local/R/cache/R/renv/library/EhdenAlopecia-f6fe3e41/R-4.2/x86_64-w64-mingw32"
library("DatabaseConnector", lib.loc = extralibpath)
library("SqlRender", lib.loc = extralibpath)
library("urltools", lib.loc = extralibpath)

jarpath <- "C:/Users/HUS72904793/Documents/jars" 
Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = jarpath)

# Database connection details -----
source("C:/Users/HUS72904793/Documents/GitHub/EHDEN/.0_setUserDetails.R")

connectionDetails <- createConnectionDetails(dbms = "synapse",
                                             user = Sys.getenv("HUSOMOPUSER"),
                                             password = Sys.getenv("HUSOMOPPWD"),
                                             connectionString = Sys.getenv("HUSOMOPCONSTR"),
)
con = connect(connectionDetails)

# Test connection
querySql(con, "SELECT COUNT(*) FROM omop54.person")

# Pasis trick:
cdm = CDMConnector::cdm_from_con(con, cdm_schema = "omop54")

#now for real (this study needs some extra)
cdmSchema <- "omop54" # schema where cdm tables are located
writeSchema <- "ohdsieric" # schema with writing permission
writePrefix <- "mega_" # combination of at least 5 letters + _ (eg. "abcde_") that will lead any table written in the cdm
dbName <- "HUS" # name of the database, use acronym in capital letters (eg. "CPRD GOLD")
#cdm <- CDMConnector::cdm_from_con(con, 
#  cdmSchema = c(schema = "omop54"),
#  writeSchema = c(schema = writeSchema, prefix = writePrefix),
#  cdmName = dbName
#  )


### ORIGNAL SOLUTION:

# Connect to database
# please see examples to connect here:
# https://darwin-eu.github.io/CDMConnector/articles/a04_DBI_connection_examples.html
db <- DBI::dbConnect(odbc::odbc(),
                Driver = "ODBC DRIVER 18 for SQL Server",
                Server = "husdltu1omopss.database.windows.net",  
                Database = "husdltu1omopdb",
                UID = "ohdsieric", 
                PWD = "mbf=4a,:8xTNdn9UL_LRVunvk:9m",
                TrustServerCertificate="yes"
                #Encrypt="True",
                #Port = 1433
                )
# Test connection:
DBI::dbListTables(db)  
# list schemas
all_schemas <- DBI::dbGetQuery(db, "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA")

#Test to resolve issue: https://github.com/oxford-pharmacoepi/MegaStudy/issues/2
cdm <- cdmFromCon(
  con = db,
  #cdmSchema = c(schema = "omop54"),
  cdmSchema = c("omop54"),
  writeSchema = c(schema = "ohdsieric", prefix = "mega_"),
  cdmName = "HUS"
)
cdm$person

# parameters to connect to create cdm object
cdmSchema <- "omop54" # schema where cdm tables are located
writeSchema <- "ohdsieric" # schema with writing permission
writePrefix <- "mega_" # combination of at least 5 letters + _ (eg. "abcde_") that will lead any table written in the cdm
dbName <- "HUS" # name of the database, use acronym in capital letters (eg. "CPRD GOLD")


# Run the study
source(here("RunFeasibility.R"))


# Troubleshooting:

# 1. 
# Error in line 36 executeChecks(...)
# > Error: nanodbc/nanodbc.cpp:1769: 42S02: [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Invalid object name 'tempdb.pdw.sysobjects'. 
# <SQL> 'select * from tempdb..sysobjects'

# Ref: https://database.guide/5-ways-to-list-temporary-tables-using-t-sql/#google_vignette

# Solution?: Test different way of looking up temp tables:
sql -> "
SELECT name
FROM tempdb.sys.tables
WHERE name LIKE '#%';
"
#1.1
queryresult <-  DBI::dbGetQuery(db, "SELECT name FROM tempdb.sys.tables")
# >Error: nanodbc/nanodbc.cpp:1769: 42S02: [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Invalid object name 'tempdb.pdw.tables'. 
# <SQL> 'SELECT name FROM tempdb.sys.tables'

#1.2
queryresult <-  DBI::dbGetQuery(db, "SELECT name FROM tempdb.sys.objects WHERE type='U';")
# Error: nanodbc/nanodbc.cpp:1769: 42S02: [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Invalid object name 'tempdb.pdw.objects'. 
# <SQL> 'SELECT name FROM tempdb.sys.objects WHERE type='U';'

queryresult <-  DBI::dbGetQuery(db, "SELECT TABLE_NAME FROM TempDB.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'Base Table';")
# Error: nanodbc/nanodbc.cpp:1769: 42S02: [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Invalid object name 'tempdb.pdw.INFORMATION_SCHEMA_TABLES'. 
# <SQL> 'SELECT TABLE_NAME FROM TempDB.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'Base Table';'

queryresult <-  DBI::dbGetQuery(db, "SELECT name FROM pdw.sysobjects")


#digging deeper:
queryresult <-  DBI::dbGetQuery(db, "SELECT * FROM SYSOBJECTS")

queryresult <-  DBI::dbGetQuery(db, "SELECT * FROM information_schema.tables")

# Top level objects
odbcListObjects(db)

# Tables in a schema
odbcListObjects(db, catalog="husdltu1omopdb", schema="sys")
odbcListObjects(db, catalog="master", schema="pdw")

queryresult <-  DBI::dbGetQuery(db, "SELECT name FROM sys.tables WHERE name LIKE '#%';")

DBI::dbGetQuery(db, "SELECT COUNT(*) FROM omop54.person")

