# Append one week to target_end_date and reference_date 
# optional lists in the "BDBV 2026 nowcasting and forecasting" round

# calculate the next date from the list's last entry
next_week <- function(values, name) {
  if (!is.list(values) || length(values) == 0L ||
      !all(vapply(values, function(x) is.character(x) && length(x) == 1L, logical(1)))) {
    stop(name, ".optional must be a nonempty list of YYYY-MM-DD strings")
  }
  values <- unlist(values, use.names = FALSE)
  dates <- as.Date(values, format = "%Y-%m-%d")
  # confirm correct date format
  if (anyNA(dates) || !identical(format(dates, "%Y-%m-%d"), values)) {
    stop(name, ".optional must contain valid YYYY-MM-DD dates")
  }
  if (is.unsorted(dates, strictly = TRUE)) {
    stop(name, ".optional must be sorted and contain no duplicates")
  }
  format(tail(dates, 1L) + 7L, "%Y-%m-%d")
}

append_optional_date <- function(text, name, addition, expected) {
  # locate candidate task-ID arrays (selects second round)
  pattern <- paste0('"', name, '"\\s*:\\s*\\{[^{}]*"optional"\\s*:\\s*\\[[^\\[\\]]*\\]')
  starts <- gregexpr(pattern, text, perl = TRUE)[[1]]
  lengths <- attr(starts, "match.length")
  candidates <- character()
  for (i in seq_along(starts)) {
    if (starts[i] < 0L) next
    start <- starts[i]
    end <- start + lengths[i] - 1L
    fragment <- substr(text, start, end)
    array_start <- regexpr("\\[[^\\[\\]]*\\]$", fragment, perl = TRUE)[[1]]
    array <- substr(fragment, array_start, nchar(fragment))
    inside <- substr(array, 1L, nchar(array) - 1L)
    space_start <- regexpr("[[:space:]]*$", inside, perl = TRUE)[[1]]
    prefix <- substr(inside, 1L, space_start - 1L)
    closing_space <- substring(inside, space_start)
    if (grepl("\n", array, fixed = TRUE)) {
      indent <- regmatches(array, regexpr('(?<=\\n)[ \\t]*(?=")', array, perl = TRUE))
      separator <- paste0(",\n", indent)
    } else {
      separator <- ", "
    }
    replacement <- paste0(
      substr(fragment, 1L, array_start - 1L), prefix, separator,
      jsonlite::toJSON(addition, auto_unbox = TRUE), closing_space, "]"
    )
    candidate <- paste0(substr(text, 1L, start - 1L), replacement, substring(text, end + 1L))
    if (identical(jsonlite::fromJSON(candidate, simplifyVector = FALSE), expected)) {
      candidates <- c(candidates, candidate)
    }
  }
  if (length(candidates) != 1L) stop("Could not uniquely edit second-round ", name, ".optional")
  candidates[[1]]
}

advance_weekly_dates <- function(text) {
  # preserve JSON object structure for eventual full-document comparison
  config <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  round <- config$rounds[[2]]
  # fail if the rounds are reordered or the intended round is renamed.
  if (!identical(round$round_name, "BDBV 2026 nowcasting and forecasting")) {
    stop('The second round must be "BDBV 2026 nowcasting and forecasting"')
  }
  if (!identical(round$round_id, "reference_date") || !isTRUE(round$round_id_from_variable)) {
    stop("The second round must use reference_date as its round ID")
  }
  if (length(round$model_tasks) != 1L) stop("Expected exactly one model task in the second round")
  task_ids <- round$model_tasks[[1]]$task_ids
  targets <- unlist(c(task_ids$target$required, task_ids$target$optional), use.names = FALSE)
  if (!"wk inc confirmed cases" %in% targets) {
    stop("The second round is not the weekly confirmed-case task")
  }
  additions <- lapply(c("reference_date", "target_end_date"), function(name) {
    next_week(task_ids[[name]]$optional, name)
  })
  names(additions) <- c("reference_date", "target_end_date")
  for (name in names(additions)) {
    # build the expected parsed config for this one change
    values <- config$rounds[[2]]$model_tasks[[1]]$task_ids[[name]]$optional
    config$rounds[[2]]$model_tasks[[1]]$task_ids[[name]]$optional <- c(values, unname(additions[name]))
    text <- append_optional_date(text, name, additions[[name]], config)
  }
  # return edited document and date additions
  list(text = text, additions = additions)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 1L) stop("Usage: Rscript src/advance-weekly-dates.R [tasks.json]")
  path <- if (length(args)) args[[1]] else "hub-config/tasks.json"
  text <- readChar(path, nchars = file.info(path)$size, useBytes = TRUE)
  updated <- advance_weekly_dates(text)
  writeChar(updated$text, path, eos = NULL, useBytes = TRUE)
  for (name in names(updated$additions)) {
    cat("Added", name, ":", updated$additions[[name]], "\n")
  }
  # GitHub Actions supplies this file path
  output <- Sys.getenv("GITHUB_OUTPUT")
  if (nzchar(output)) {
    cat(paste0(names(updated$additions), "=", unlist(updated$additions), "\n"),
        file = output, append = TRUE, sep = "")
  }
}

# logic executes file changes only when invoked directly with Rscript
if (sys.nframe() == 0L) main()
