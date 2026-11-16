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

# read the accepted file at this path, if one exists in the PR's base commit
# new file must contain original file + a new forecast_date
read_previous_output <- function(file, base_sha) {
  existing <- system2("git", c(
    "ls-tree", "--name-only", "-r", shQuote(base_sha), "--",
    shQuote(paste0(":(literal)", file))
  ), stdout = TRUE)
  if (!is.null(attr(existing, "status"))) stop("Could not inspect base version of ", file)
  if (!length(existing)) return(NULL)

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
  previous
}
row_keys <- function(tbl) {
  cells <- lapply(tbl, function(values) {
    ifelse(is.na(values), "N", paste0("S", nchar(values, type = "bytes"), ":", values))
  })
  do.call(paste0, cells)
}

new_submission_rows <- function(tbl, previous, file) {
  if (is.null(previous)) return(tbl)
  if (ncol(tbl) != ncol(previous) || !setequal(names(tbl), names(previous))) {
    stop(file, ": appended submission must preserve the existing file's columns",
         call. = FALSE)
  }
  old_dates <- tbl$forecast_date %in% previous$forecast_date
  retained <- tbl[old_dates, names(previous), drop = FALSE]
  if (!identical(sort(row_keys(retained)), sort(row_keys(previous)))) {
    stop(file, ": all existing rows must be preserved unchanged, including duplicate counts; ",
         "new rows must use a new forecast_date", call. = FALSE)
  }
  tbl[!old_dates, , drop = FALSE]
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
  if (!"reference_date" %in% names(tbl)) stop(file, ": missing reference_date")
  reference <- parse_dates(tbl$reference_date, "reference_date", file)
  if (any(forecast > reference)) {
    stop(file, ": forecast_date must be on or before reference_date; CSV line ",
         which(forecast > reference)[1] + 1L)
  }
  previous <- read_previous_output(file, base_sha)
  new_rows <- new_submission_rows(tbl, previous, file)
  new_dates <- unique(new_rows$forecast_date)
  if (length(new_dates) != 1L) {
    stop(file, ": new data must contain exactly one new forecast_date",
         call. = FALSE)
  }
  if (abs(as.integer(as.Date(new_dates, format = "%Y-%m-%d") - today)) > 1L) {
    stop(file, ": new forecast_date must be within one day of today's date in ", hub_timezone,
         " (", format(today, "%Y-%m-%d"), "); found ", new_dates,
         call. = FALSE)
  }
  # isolate and validate the new forecast independently
  new_rows$forecast_date <- NULL
  destination <- file.path(validation_hub, file)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  write.csv(new_rows, destination, row.names = FALSE)
  !is.null(previous)
}

allow_verified_appends <- function(validations, verified_appends) {
  for (i in seq_along(validations)) {
    checks <- validations[[i]]
    status <- checks$valid_file_status
    if (!is.null(status) &&
        identical(status$call, "check_valid_file_status") &&
        (inherits(status, "check_error") || inherits(status, "check_failure")) &&
        !inherits(status, "check_exec_error") &&
        isTRUE(status$where %in% verified_appends)) {
      message("Accepted append-only update: ", status$where)
      validations[[i]] <- checks[names(checks) != "valid_file_status"]
    }
  }
  validations
}

# only ordinary submission_time failures may be ignored here
only_submission_window_failures <- function(validations) {
  checks <- unlist(lapply(validations, unclass), recursive = FALSE)
  if (!length(checks)) return(FALSE)
  window_failure <- vapply(checks, function(check) {
    inherits(check, "check_failure") &&
      identical(check$call, "check_submission_time")
  }, logical(1))
  passed <- vapply(checks, function(check) {
    inherits(check, "check_success") || inherits(check, "check_info")
  }, logical(1))
  any(window_failure) && all(passed | window_failure)
}

pr_number <- Sys.getenv("PR_NUMBER")
if (!nzchar(pr_number)) stop("Run this validation on a pull request (PR_NUMBER is required).")
# default to false so custom-check failures also invalidate an earlier comment
summary_path <- Sys.getenv("VALIDATION_SUMMARY_PATH")
write_validation_summary <- function(window_only) {
  if (nzchar(summary_path)) {
    jsonlite::write_json(list(
      pr_number = as.integer(pr_number), window_only = window_only
    ), summary_path, auto_unbox = TRUE)
  }
}
write_validation_summary(FALSE)
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
# capture today once so all files use the same date even if the run crosses midnight (edgecase)
today <- as.Date(format(Sys.time(), tz = hub_timezone, format = "%Y-%m-%d"))
modified_outputs <- vapply(Filter(function(f) {
  identical(f$status, "modified") && f$filename %in% outputs
}, files), function(f) f$filename, character(1))
verified_appends <- character()
for (file in outputs) {
  is_append <- prepare_output(file, validation_hub, base_sha, today, hub_timezone)
  if (is_append && file %in% modified_outputs) {
    # hubValidations identifies output files relative to model-output/.
    verified_appends <- c(verified_appends, substring(file, nchar("model-output/") + 1L))
  }
}

# standard hubverse validations
v <- hubValidations::validate_pr(
  hub_path = validation_hub,
  gh_repo = repo,
  pr_number = pr_number,
  skip_submit_window_check = FALSE
)
v <- allow_verified_appends(v, verified_appends)
# write the summary *before* check_for_errors() exits with the original failure
write_validation_summary(length(outputs) > 0L && only_submission_window_failures(v))
hubValidations::check_for_errors(v, verbose = TRUE)
