# local entry point. CI uses the native validate-submission@v2 action and
# registers the same custom check through hub-config/validations.yml
source("src/validations/forecast-date.R")

validate_submission <- function() {
  pr_number <- Sys.getenv("PR_NUMBER")
  if (!nzchar(pr_number)) stop("PR_NUMBER is required.")
  source_hub <- normalizePath(".")
  validation_hub <- tempfile("forecast-validation-")
  dir.create(validation_hub)
  on.exit(unlink(validation_hub, recursive = TRUE), add = TRUE)
  for (directory in c("hub-config", "model-output", "model-metadata",
                      "auxiliary-data", "target-data", "src")) {
    if (dir.exists(directory) && !file.copy(directory, validation_hub, recursive = TRUE)) {
      stop("Could not copy ", directory)
    }
  }
  previous <- Sys.getenv("FORECAST_SOURCE_HUB", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("FORECAST_SOURCE_HUB")
    else Sys.setenv(FORECAST_SOURCE_HUB = previous)
  }, add = TRUE)
  Sys.setenv(FORECAST_SOURCE_HUB = source_hub)
  hubValidations::validate_pr(
    hub_path = validation_hub,
    gh_repo = Sys.getenv("GITHUB_REPOSITORY"),
    pr_number = pr_number,
    skip_submit_window_check = FALSE
  )
}

hubValidations::check_for_errors(validate_submission(), verbose = TRUE)
