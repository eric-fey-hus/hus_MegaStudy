
# Define output folder ----
outputFolder <- here::here("storage")   
# Create output folder if it doesn't exist
if (!file.exists(outputFolder)){
  dir.create(outputFolder, recursive = TRUE)}


# Start log ----
log_file <- here::here(outputFolder, paste0(dbName, "_log.txt"))
logger <- create.logger()
logfile(logger) <- log_file
level(logger) <- "INFO"

# Create cdm object ----
info(logger, 'CREATE CDM OBJECT')
cdm <- cdmFromCon(
  con = db,
  cdmSchema = c(schema = cdmSchema),
  writeSchema = c(schema = writeSchema, prefix = writePrefix),
  cdmName = dbName
)


# cdm snapshot ----
info(logger, 'CREATE SNAPSHOT')
write.csv(
  x = snapshot(cdm),
  file = here(outputFolder, paste0("snapshot_", cdmName(cdm), ".csv")),
  row.names = FALSE
)


# if SIDIAP filter cdm$drug_exposure
if (cdmName(cdm) == "SIDIAP") {
  info(logger, "FILTER DRUG EXPOSURE TABLE SIDIAP")
  cdm$drug_exposure <- cdm$drug_exposure %>%
    filter(drug_type_concept_id == 32839) %>%
    computeQuery()
}

## Generate drug concepts ----
info(logger, "GENERATE DRUG CONCEPTS")
source(here("drugs.R"))

## Generate drug cohorts---
info(logger, "GENERATE DRUG COHORTS")
cdm <- generateDrugUtilisationCohortSet(
  cdm = cdm,
  name = "drug_cohorts",
  conceptSet = concept_drugs,
  durationRange = c(1, Inf),
  imputeDuration = "none",
  gapEra = 0,
  priorUseWashout = 0,
  priorObservation = 0,
  cohortDateRange = as.Date(c("2010-01-01",NA)),
  limit = "all"
)

## get denominator population ----
info(logger, "GENERATE DENOMINATOR COHORT")
cdm <- generateDenominatorCohortSet(
  cdm = cdm, 
  name = "denominator",
  cohortDateRange = as.Date(c("2010-01-01",NA)),
  ageGroup = list(
    c(0, 150),
    c(0, 17),
    c(18, 64),
    c(65, 150)
  ),
  sex = c("Both", "Female", "Male"),
  daysPriorObservation = c(0,30),   
  requirementInteractions = TRUE,
  overwrite = TRUE
)


## get incidence rates ---
info(logger, "ESTIMATE INCIDENCE RATES")
inc <- estimateIncidence(
  cdm = cdm,
  denominatorTable = "denominator",
  outcomeTable = "drug_cohorts",
  interval = "years",
  completeDatabaseIntervals = FALSE,
  outcomeWashout = 30,
  repeatedEvents = TRUE,
  minCellCount = 10,
  temporary = TRUE
)
info(logger, "INCIDENCE ATTRITION")
write.csv(incidenceAttrition(inc),
          here("storage", paste0(
            "incidence_attrition_", cdmName(cdm), ".csv"
          )))

## get annual period prevalence ---
info(logger, "ESTIMATE PERIOD PREVALENCE")
prev <- estimatePeriodPrevalence(
  cdm = cdm,
  denominatorTable = "denominator",
  outcomeTable = "drug_cohorts",
  interval = "years",
  completeDatabaseIntervals = FALSE,
  minCellCount = 10,
  temporary = TRUE
)

info(logger, "PREVALENCE ATTRITION")
write.csv(prevalenceAttrition(prev),
          here("storage", paste0(
            "prevalence_attrition_", cdmName(cdm), ".csv"
          )))

## export results
info(logger, "ZIP INCPREV RESULTS")
exportIncidencePrevalenceResults(
  resultList = list("prevalence" = prev, "incidence" = inc),
  zipName = paste0(cdmName(cdm), "_IncidencePrevalenceResults"),
  outputFolder = outputFolder
)


## zip everything together ---
info(logger, "ZIP EVERYTHING")
zip(
  zipfile = here::here(paste0("Results_", cdmName(cdm), ".zip")),
  files = list.files(outputFolder),
  root = outputFolder
)

## remove storyage, caused confusion ---
info(logger, "REMOVE STORAGE FOLDER")
unlink(here("storage"), recursive = TRUE)

print("Done!")
print("If all has worked, there should now be a zip file with your Incidence Prevalence results in the same level as the .Rproj")
print("Thank you for running the Incidence Prevalence analysis!")