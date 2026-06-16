#!/usr/bin/env Rscript
#
# Parse the latest epiforecasts/BVDOutbreakSize renewal-model release into a
# hubverse submission file for the BVBD Modeling Hub (model epiforecasts-renewal).
#
# Unlike the one-off historical parser (src/parse_epiforecasts_estimates.R),
# this script is designed to be run repeatedly - by hand or from CI - to pick
# up the CURRENT renewal-model estimate. The upstream repository publishes a
# rolling "results-<build>" GitHub release on every push to its `main`
# (make_latest = true), attaching the fitted outputs. This script downloads the
# latest such release, parses the headline cumulative symptomatic-case
# posterior, and writes the corresponding hub model-output CSV.
#
# Target semantics. The hub target ("cumulative cases") is the cumulative
# number of *symptomatic* cases. The renewal model now publishes this directly:
# `posterior_draws.csv` carries a `cumulative_onsets_T` column - the cumulative
# symptom onsets ("symptomatic cases") by the data cut-off, per draw (the onset
# analogue of `C_T`, which is cumulative *infections*). This script uses
# `cumulative_onsets_T`, so the submission maps cleanly onto the hub target.
#
# Usage:
#   Rscript src/parse_epiforecasts_renewal.R                # latest release
#   Rscript src/parse_epiforecasts_renewal.R results-780    # a specific release tag
#
# Environment overrides (useful in CI):
#   BVD_UPSTREAM_REPO   upstream repo (default epiforecasts/BVDOutbreakSize)
#   BVD_HUB_PATH        hub root to write into (default: parent of this script)
#
# Requires the `gh` CLI installed and authenticated, plus base R (`utils`,
# `stats`). Exits non-zero on any failure so CI can detect problems.

suppressWarnings(suppressMessages({
  library(utils)
  library(stats)
}))

## ---------------------------------------------------------------------------
## Configuration
## ---------------------------------------------------------------------------

UPSTREAM_REPO <- Sys.getenv("BVD_UPSTREAM_REPO", "epiforecasts/BVDOutbreakSize")

## Hub-required quantile probability levels (see hub-config/tasks.json).
QUANTILE_LEVELS <- c(0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975)
TARGET <- "cumulative cases"
LOCATION <- "CD"
TEAM_ABBR <- "epiforecasts"
MODEL_ABBR <- "renewal"
MODEL_ID <- paste0(TEAM_ABBR, "-", MODEL_ABBR)

## The posterior-draws column carrying the cumulative symptomatic-case posterior.
DRAWS_COL <- "cumulative_onsets_T"

## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------

## Run `gh` capturing stdout; stop with context on a non-zero exit.
gh <- function(args) {
  out <- suppressWarnings(
    system2("gh", args, stdout = TRUE, stderr = TRUE)
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    stop(sprintf("`gh %s` failed:\n%s",
                 paste(args, collapse = " "), paste(out, collapse = "\n")))
  }
  out
}

## Resolve the tag of the most recent (make_latest) upstream release.
latest_release_tag <- function() {
  tag <- gh(c("release", "view", "-R", UPSTREAM_REPO,
              "--json", "tagName", "--jq", ".tagName"))
  tag <- trimws(paste(tag, collapse = ""))
  if (!nzchar(tag)) stop("could not resolve the latest release tag")
  tag
}

## Download a single named asset from a release into `dir`, returning its path.
fetch_asset <- function(tag, file, dir) {
  dest <- file.path(dir, file)
  status <- system2(
    "gh",
    c("release", "download", tag, "-R", UPSTREAM_REPO,
      "-p", file, "-O", dest, "--clobber"),
    stdout = FALSE, stderr = FALSE
  )
  if (status != 0 || !file.exists(dest)) {
    stop(sprintf("failed to download asset '%s' from release '%s'", file, tag))
  }
  dest
}

## Read the data cut-off date (`as_of_date`) from an observations.toml file.
read_as_of_date <- function(toml_path) {
  lines <- readLines(toml_path, warn = FALSE)
  hit <- grep("^\\s*as_of_date\\s*=", lines, value = TRUE)
  if (length(hit) == 0) stop(sprintf("no as_of_date found in %s", toml_path))
  date_str <- sub('.*=\\s*"?([0-9]{4}-[0-9]{2}-[0-9]{2})"?.*', "\\1", hit[1])
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date_str)) {
    stop(sprintf("could not parse as_of_date from line: %s", hit[1]))
  }
  date_str
}

## Build the long-format hubverse table from a vector of posterior draws.
build_submission <- function(reference_date, draws) {
  q_values <- round(as.numeric(quantile(draws, probs = QUANTILE_LEVELS,
                                         names = FALSE, type = 7)))
  quantile_rows <- data.frame(
    reference_date = reference_date,
    target = TARGET,
    location = LOCATION,
    output_type = "quantile",
    output_type_id = as.character(QUANTILE_LEVELS),
    value = q_values,
    stringsAsFactors = FALSE
  )
  point_rows <- data.frame(
    reference_date = reference_date,
    target = TARGET,
    location = LOCATION,
    output_type = c("median", "mean"),
    output_type_id = c("NA", "NA"),
    value = c(round(median(draws)), round(mean(draws))),
    stringsAsFactors = FALSE
  )
  rbind(quantile_rows, point_rows)
}

## Resolve the hub root: explicit override, else the parent of this script.
resolve_hub_root <- function() {
  override <- Sys.getenv("BVD_HUB_PATH", "")
  if (nzchar(override)) return(normalizePath(override, mustWork = TRUE))
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) == 1) {
    return(normalizePath(file.path(dirname(sub("^--file=", "", file_arg)), "..")))
  }
  normalizePath(getwd())
}

## ---------------------------------------------------------------------------
## Main
## ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
tag <- if (length(args) >= 1 && nzchar(args[1])) args[1] else latest_release_tag()

message(sprintf("Upstream repo : %s", UPSTREAM_REPO))
message(sprintf("Release tag   : %s", tag))

hub_root <- resolve_hub_root()
message(sprintf("Hub root      : %s", hub_root))

tmp <- tempfile("bvd_renewal_")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

obs_path <- fetch_asset(tag, "observations.toml", tmp)
draws_path <- fetch_asset(tag, "posterior_draws.csv", tmp)

reference_date <- read_as_of_date(obs_path)
message(sprintf("Reference date: %s", reference_date))

draws_df <- utils::read.csv(draws_path, check.names = FALSE)
if (!DRAWS_COL %in% names(draws_df)) {
  stop(sprintf(paste0("column '%s' not found in posterior_draws.csv for %s.\n",
                      "This release predates the symptom-onset outputs ",
                      "(epiforecasts/BVDOutbreakSize PR #270); use a newer build.\n",
                      "Available columns: %s"),
               DRAWS_COL, tag, paste(names(draws_df), collapse = ", ")))
}
draws <- draws_df[[DRAWS_COL]]

submission <- build_submission(reference_date, draws)

out_dir <- file.path(hub_root, "model-output", MODEL_ID)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_file <- file.path(out_dir, sprintf("%s-%s.csv", reference_date, MODEL_ID))
utils::write.csv(submission, out_file, row.names = FALSE, quote = FALSE)

message(sprintf("Wrote %s", out_file))
message(sprintf("  draws: %d | median: %s | quantity: cumulative symptomatic cases (%s)",
                length(draws), round(median(draws)), DRAWS_COL))
