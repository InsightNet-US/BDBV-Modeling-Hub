# important deviation: keep hubverse file-status result unless the PR modified an existing CSV
# and the custom check confirmed that the edit only added a new forecast
allow_append_only_resubmissions <- function(results, pr_files) {
  candidates <- names(results)[vapply(results, function(checks) {
    inherits(checks[["forecast_date"]], "check_success") &&
      inherits(checks[["valid_file_status"]], "check_error")
  }, logical(1))]
  if (!length(candidates)) return(results)

  modified_files <- vapply(Filter(function(file) {
    identical(file$status, "modified")
  }, pr_files), function(file) file$filename, character(1))
  for (path in candidates) {
    if (endsWith(path, ".csv") && paste0("model-output/", path) %in% modified_files) {
      results[[path]][["valid_file_status"]] <- NULL
    }
  }
  results
}

run_submission_validation <- function() {
  source(Sys.getenv("HUBVERSE_SUMMARY_R"), local = TRUE)
  options(cli.num_colors = 1)
  summary_path <- Sys.getenv("SUMMARY_PATH")
  gh_repo <- Sys.getenv("GITHUB_REPOSITORY")
  pr_number <- Sys.getenv("PR_NUMBER")

  results <- tryCatch({
    results <- hubValidations::validate_pr(
      hub_path = Sys.getenv("HUB_PATH"),
      gh_repo = gh_repo,
      pr_number = pr_number,
      skip_submit_window_check = FALSE,
      file_modification_check = "error"
    )
    allow_append_only_resubmissions(results, tryCatch({
      gh::gh(
        "/repos/{gh_repo}/pulls/{pr_number}/files",
        gh_repo = gh_repo,
        pr_number = pr_number,
        per_page = 100,
        .limit = Inf,
        .progress = FALSE
      )
    }, error = function(e) {
      message("Keeping Hubverse file-status checks because PR file statuses could not be confirmed: ",
              conditionMessage(e))
      list()
    }))
  }, error = identity)

  if (inherits(results, "error")) {
    message <- conditionMessage(results)
    writeLines(render_exec_error(message), summary_path, useBytes = TRUE)
    stop(message, call. = FALSE)
  }

  checked <- capture_check(results)
  writeLines(render_summary(checked$lines, checked$failure), summary_path, useBytes = TRUE)
  writeLines(checked$lines, stderr())
  if (!is.null(checked$failure)) stop("Submission validation failed.", call. = FALSE)
}

if (sys.nframe() == 0L) run_submission_validation()
