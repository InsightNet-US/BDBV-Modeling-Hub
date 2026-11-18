# parse dates without aborting so independent validation issues can accumulate
inspect_dates <- function(values) {
  dates <- suppressWarnings(as.Date(values, format = "%Y-%m-%d"))
  valid <- !is.na(values) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", values) &
    !is.na(dates) & format(dates, "%Y-%m-%d") == values &
    substr(values, 1, 4) != "0000"
  valid[is.na(valid)] <- FALSE
  list(dates = dates, valid = valid)
}

# read the accepted file at this path, if one exists in the PR's base commit
# new file must contain original file + a new forecast_date
read_previous_output <- function(file, base_sha, source_hub = ".") {
  existing <- system2("git", c(
    "-C", shQuote(source_hub), "ls-tree", "--name-only", "-r", shQuote(base_sha), "--",
    shQuote(paste0(":(literal)", file))
  ), stdout = TRUE)
  if (!is.null(attr(existing, "status"))) stop("Could not inspect base version of ", file)
  if (!length(existing)) return(NULL)

  previous_file <- tempfile(fileext = ".csv")
  on.exit(unlink(previous_file))
  status <- system2("git", c("-C", shQuote(source_hub), "show", shQuote(paste0(base_sha, ":", file))),
                    stdout = previous_file)
  if (status != 0L) stop("Could not read base version of ", file)
  previous <- read.csv(previous_file, colClasses = "character", check.names = FALSE,
                       na.strings = NULL, fill = FALSE, row.names = NULL)
  if (!"forecast_date" %in% names(previous)) {
    stop(file, ": base-branch file is missing the required forecast_date column",
         call. = FALSE)
  }
  if (sum(names(previous) == "forecast_date") != 1L) {
    stop(file, ": base-branch forecast_date column must occur exactly once", call. = FALSE)
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

# collect independent custom failures
prepare_output <- function(file, validation_hub, base_sha, today, hub_timezone, source_hub = ".") {
  if (!startsWith(file, "model-output/") || any(strsplit(file, "/", fixed = TRUE)[[1]] == "..")) {
    stop("Invalid model output path: ", file)
  }
  if (!endsWith(file, ".csv")) stop("Unsupported model output format: ", file)
  tbl <- read.csv(file.path(source_hub, file), colClasses = "character", check.names = FALSE,
                  na.strings = NULL, fill = FALSE, row.names = NULL)
  issues <- character()
  blocked <- FALSE
  add_issue <- function(message, blocking = FALSE) {
    issues <<- c(issues, paste0(file, ": ", message))
    blocked <<- blocked || blocking
  }
  collect <- function(expr, blocking = FALSE) {
    tryCatch(expr, error = function(e) {
      issues <<- c(issues, conditionMessage(e))
      blocked <<- blocked || blocking
      NULL
    })
  }
  dates <- list()
  for (column in c("forecast_date", "reference_date")) {
    count <- sum(names(tbl) == column)
    if (count != 1L) {
      add_issue(if (count == 0L) paste0("missing required ", column, " column")
                else paste0(column, " column must occur exactly once"),
                blocking = column == "forecast_date")
      next
    }
    dates[[column]] <- inspect_dates(tbl[[column]])
    if (!all(dates[[column]]$valid)) {
      lines <- which(!dates[[column]]$valid) + 1L
      add_issue(paste0(column, " must contain valid, nonblank YYYY-MM-DD dates; CSV lines ",
                       paste(head(lines, 20L), collapse = ", "),
                       if (length(lines) > 20L) paste0(" (", length(lines), " invalid rows total)")))
    }
  }
  if (all(c("forecast_date", "reference_date") %in% names(dates))) {
    comparable <- dates$forecast_date$valid & dates$reference_date$valid
    after_reference <- which(comparable & dates$forecast_date$dates > dates$reference_date$dates)
    if (length(after_reference)) {
      add_issue(paste0("forecast_date must be on or before reference_date; CSV lines ",
                       paste(head(after_reference + 1L, 20L), collapse = ", ")))
    }
  }
  previous <- collect(read_previous_output(file, base_sha, source_hub), blocking = TRUE)
  new_rows <- NULL
  if (!is.null(dates$forecast_date) && !blocked) {
    collect(new_submission_rows(tbl, previous, file))
    new_rows <- if (is.null(previous)) tbl else {
      tbl[!tbl$forecast_date %in% previous$forecast_date, , drop = FALSE]
    }
    new_dates <- unique(new_rows$forecast_date)
    if (length(new_dates) != 1L) {
      add_issue("new data must contain exactly one new forecast_date", blocking = TRUE)
    } else {
      parsed <- inspect_dates(new_dates)
      if (isTRUE(parsed$valid) && abs(as.integer(parsed$dates - today)) > 1L) {
        add_issue(paste0("new forecast_date must be within one day of today's date in ",
                         hub_timezone, " (", format(today, "%Y-%m-%d"), "); found ", new_dates))
      }
    }
  }
  if (!blocked) {
    new_rows$forecast_date <- NULL
    destination <- file.path(validation_hub, file)
    collect({
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      write.csv(new_rows, destination, row.names = FALSE)
    }, blocking = TRUE)
  }
  if (blocked) {
    add_issue("Standard content checks cannot run safely because the new forecast could not be isolated or prepared.")
  }
  list(issues = issues, prepared = !blocked)
}

check_forecast_date <- function(hub_path, file_path, today = NULL) {
  result <- tryCatch({
    source_hub <- Sys.getenv("FORECAST_SOURCE_HUB")
    if (!nzchar(source_hub)) stop("FORECAST_SOURCE_HUB must identify the original hub checkout.")
    source_hub <- normalizePath(source_hub, mustWork = TRUE)
    if (identical(normalizePath(hub_path, mustWork = TRUE), source_hub)) {
      stop("Forecast validation requires a separate staged hub; refusing to rewrite the original checkout.")
    }
    base_sha <- Sys.getenv("PR_BASE_SHA")
    if (!grepl("^[0-9a-fA-F]{40}$", base_sha) ||
        system2("git", c("-C", shQuote(source_hub), "cat-file", "-e",
                         shQuote(paste0(base_sha, "^{commit}"))),
                stdout = FALSE, stderr = FALSE) != 0L) {
      stop("PR_BASE_SHA must identify a locally available PR base commit.")
    }
    timezone <- jsonlite::fromJSON(file.path(hub_path, "hub-config/admin.json"))$timezone
    if (length(timezone) != 1L || !timezone %in% OlsonNames()) {
      stop("hub-config/admin.json must specify a valid timezone to determine today's date.")
    }
    if (is.null(today)) {
      # capture the date once per hub per R process (including a midnight crossing)
      dates <- getOption("bdbv.forecast_validation_dates", list())
      key <- paste(source_hub, timezone)
      if (is.null(dates[[key]])) {
        dates[[key]] <- as.Date(format(Sys.time(), tz = timezone, format = "%Y-%m-%d"))
        options(bdbv.forecast_validation_dates = dates)
      }
      today <- dates[[key]]
    }
    prepare_output(paste0("model-output/", file_path), hub_path, base_sha,
                   as.Date(today), timezone, source_hub)
  }, error = identity)
  if (inherits(result, "error")) {
    result <- list(issues = conditionMessage(result), prepared = FALSE)
  }
  hubValidations::capture_check_cnd(
    check = length(result$issues) == 0L,
    file_path = file_path,
    msg_subject = "Forecast dates and appended rows",
    msg_attribute = "valid.",
    # ordinary failures remain failing checks but let native data checks run
    # unsafe/unreadable inputs retain check_error to stop only this file
    error = !result$prepared,
    details = if (length(result$issues)) paste0("- ", result$issues, collapse = "\n") else NULL
  )
}

