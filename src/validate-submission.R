# standard hubValidation call + custom validation for our forecast_date column, which is not
# configured in tasks.json 

# date must be YYYY-MM-DD parseable
parse_dates <- function(values, column, file) {
  dates <- as.Date(values, format = "%Y-%m-%d")
  valid <- !is.na(values) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", values) &
    !is.na(dates) & format(dates, "%Y-%m-%d") == values &
    substr(values, 1, 4) != "0000"
  if (!all(valid)) {
    stop(file, ": ", column, " must contain valid, nonblank YYYY-MM-DD dates; CSV line ",
         which(!valid)[1] + 1L, call. = FALSE)
  }
  dates
}

# confirm that the forecast_date in model output does not appear in pre-existing file (if there is a pre-existing file)
# this check is skipped if there is no pre-existing file of the same name
check_existing_forecast_dates <- function(file, forecast_dates, base_sha) {
  existing <- system2("git", c(
    "ls-tree", "--name-only", "-r", shQuote(base_sha), "--",
    shQuote(paste0(":(literal)", file))
  ), stdout = TRUE)
  if (!is.null(attr(existing, "status"))) stop("Could not inspect base version of ", file)
  if (!length(existing)) return(invisible(NULL))

  previous_file <- tempfile(fileext = ".csv")
  on.exit(unlink(previous_file))
  status <- system2("git", c("show", shQuote(paste0(base_sha, ":", file))),
                    stdout = previous_file)
  if (status != 0L) stop("Could not read base version of ", file)
  previous <- read.csv(previous_file, colClasses = "character", check.names = FALSE,
                       na.strings = NULL, fill = FALSE, row.names = NULL)
  if (!"forecast_date" %in% names(previous)) {
    stop(file, ": base-branch file is missing the required forecast_date column",
         call. = FALSE)
  }
  overlap <- intersect(forecast_dates, previous$forecast_date)
  if (length(overlap)) {
    stop(file, ": forecast_date values already present in the base branch: ",
         paste(overlap, collapse = ", "), call. = FALSE)
  }
}

# output/failures
prepare_output <- function(file, validation_hub, base_sha, today, hub_timezone) {
  if (!startsWith(file, "model-output/") || any(strsplit(file, "/", fixed = TRUE)[[1]] == "..")) {
    stop("Invalid model output path: ", file)
  }
  if (!endsWith(file, ".csv")) stop("Unsupported model output format: ", file)
  tbl <- read.csv(file, colClasses = "character", check.names = FALSE,
                  na.strings = NULL, fill = FALSE, row.names = NULL)
  if (!"forecast_date" %in% names(tbl)) {
    stop(file, ": missing required forecast_date column")
  }
  if (sum(names(tbl) == "forecast_date") != 1L) {
    stop(file, ": forecast_date column must occur exactly once")
  }
  forecast <- parse_dates(tbl$forecast_date, "forecast_date", file)
  if (length(unique(forecast)) != 1L) {
    stop(file, ": forecast_date must have exactly one unique value across the entire file",
         call. = FALSE)
  }
  if (forecast[1] != today) {
    stop(file, ": forecast_date must match today's date in ", hub_timezone,
         " (", format(today, "%Y-%m-%d"), "); found ", tbl$forecast_date[1],
         call. = FALSE)
  }
  if (!"reference_date" %in% names(tbl)) stop(file, ": missing reference_date")
  reference <- parse_dates(tbl$reference_date, "reference_date", file)
  if (any(forecast > reference)) {
    stop(file, ": forecast_date must be on or before reference_date; CSV line ",
         which(forecast > reference)[1] + 1L)
  }
  check_existing_forecast_dates(file, tbl$forecast_date, base_sha)
  tbl$forecast_date <- NULL
  destination <- file.path(validation_hub, file)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  write.csv(tbl, destination, row.names = FALSE)
}

pr_number <- Sys.getenv("PR_NUMBER")
if (!nzchar(pr_number)) stop("Run this validation on a pull request (PR_NUMBER is required).")
repo <- Sys.getenv("GITHUB_REPOSITORY")
base_sha <- Sys.getenv("PR_BASE_SHA")
if (!grepl("^[0-9a-fA-F]{40}$", base_sha) ||
    system2("git", c("cat-file", "-e", shQuote(paste0(base_sha, "^{commit}"))),
            stdout = FALSE, stderr = FALSE) != 0L) {
  stop("PR_BASE_SHA must identify a locally available PR base commit.")
}
files <- gh::gh(
  "/repos/{repo}/pulls/{number}/files",
  repo = repo, number = pr_number, per_page = 100, .limit = Inf
)
outputs <- vapply(Filter(function(f) {
  startsWith(f$filename, "model-output/") &&
    !grepl("README", f$filename, fixed = TRUE) && f$status != "removed"
}, files), function(f) f$filename, character(1))

validation_hub <- tempfile(pattern = "forecast-validation-")
dir.create(validation_hub)
for (directory in c("hub-config", "model-metadata", "auxiliary-data", "target-data")) {
  if (dir.exists(directory) && !file.copy(directory, validation_hub, recursive = TRUE)) {
    stop("Could not copy ", directory)
  }
}
dir.create(file.path(validation_hub, "model-output"))
hub_timezone <- jsonlite::fromJSON("hub-config/admin.json")$timezone
if (length(hub_timezone) != 1L || !hub_timezone %in% OlsonNames()) {
  stop("hub-config/admin.json must specify a valid timezone to determine today's date.")
}
# Capture today once so all files use the same date even if the run crosses midnight.
today <- as.Date(format(Sys.time(), tz = hub_timezone, format = "%Y-%m-%d"))
for (file in outputs) prepare_output(file, validation_hub, base_sha, today, hub_timezone)

# standard hubverse validations
v <- hubValidations::validate_pr(
  hub_path = validation_hub,
  gh_repo = repo,
  pr_number = pr_number,
  skip_submit_window_check = FALSE
)
hubValidations::check_for_errors(v, verbose = TRUE)
