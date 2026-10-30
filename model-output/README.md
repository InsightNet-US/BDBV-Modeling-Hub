# Model outputs folder

This folder contains a set of subdirectories, one for each model, that contains submitted model output files for that model. The structure of these directories and their contents follows [the model output guidelines in our documentation](https://docs.hubverse.io/en/latest/user-guide/model-output.html). Documentation for hub submissions specifically is provided below.

# Data submission instructions

All estimates should be submitted directly to the [model-output/](./) folder. Data in this directory should be added to the repository through a pull request so that automatic data validation checks are run.

These instructions provide detail about the [data format](#data-formatting) as well as [validation](#Forecast-validation) that you can do prior to this pull request. In addition, we describe
[metadata](https://github.com/hubverse-org/hubTemplate/blob/master/model-metadata/README.md) that each model should provide in the model-metadata folder.

*Table of Contents*

-   [Data formatting](#data-formatting)
-   [File format](#file-format)
-   [Forecast data validation](#forecast-validation)
-   [Previous rounds](#previous-rounds)


## Data formatting

The automatic checks in place for forecast files submitted to this repository validates both the filename and file contents to ensure the file can be used in the visualization and ensemble forecasting.

### Subdirectory

Each model that submits model output for this project will have a unique subdirectory within the [model-output/](model-output/) directory in this GitHub repository where estimates will be submitted. Each subdirectory must be named

    team-model

where

-   `team` is the team name and
-   `model` is the name of your model.

Both team and model should be less than 15 characters and not include
hyphens or other special characters, with the exception of "\_".

The combination of `team` and `model` should be unique from any other model in the project.


### Metadata

The metadata file will be saved within the model-metadata directory in the Hub's GitHub repository, and should have the following naming convention:

      team-model.yml

Details on the content and formatting of metadata files are provided in the [model-metadata README](https://github.com/hubverse-org/hubTemplate/blob/master/model-metadata/README.md).


### Estimates

Each model output file should have the following format

    YYYY-MM-DD-team-model.csv

where

-   `YYYY` is the 4 digit year,
-   `MM` is the 2 digit month,
-   `DD` is the 2 digit day,
-   `team` is the team name, and
-   `model` is the name of your model.

The date YYYY-MM-DD is the [`reference_date`](#reference_date) of the round being submitted to, i.e. the Saturday ending the epi week in which the nowcast is made (see below). It is not the date the file is created.

The `team` and `model` in this file must match the `team` and `model` in the directory this file is in. Both `team` and `model` should be less than 16 characters, alpha-numeric and underscores only, with no spaces or hyphens.

## File format

The hub is currently collecting **nowcasts and forecasts of weekly incident confirmed cases by location (country, province or health zone)** (round `BDBV 2026 nowcasting and forecasting` in [`hub-config/tasks.json`](../hub-config/tasks.json)). The file must be a comma-separated value (csv) file with the following columns (in any order):

-   `reference_date`
-   `forecast_date`
-   `target`
-   `target_end_date`
-   `location`
-   `output_type`
-   `output_type_id`
-   `value`

No additional columns are allowed.

Each row of the file is the value of expected final number of reported cases for a particular combination of location and target_end_date for one of 100 sample trajectories sampled from the distribution of epidemic trajectories produced by that model. The observed data these estimates are compared against are in the [`target-data/`](../target-data/) folder, and will themselves be updated weekly while the epidemic continues and the hub is still running. The final values in this file after all revisions are the ultimate model target.

### `reference_date`

Values in the `reference_date` column must be a date in the ISO format

    YYYY-MM-DD

The `reference_date` identifies the round. It is a Saturday, the last day of the epi week in which the estimates are made, and must match the date in the filename. The accepted reference dates are listed under the `BDBV 2026 nowcasting and forecasting` round in `hub-config/tasks.json`; a new one is added automatically each week. Submissions for a given `reference_date` are accepted from six to four days before it (Sunday through Tuesday of that week).

### `forecast_date`

The date the model was run to produce the submitted estimates. Every submitted model-output file must include exactly one column named `forecast_date`, with the same nonblank date in every row. Values must be valid calendar dates in exactly `YYYY-MM-DD` format; `NA`, timestamps, and other date formats are rejected.

The date must:

- Be yesterday, today, or tomorrow relative to the date when validation runs in **Africa/Kinshasa** timezone.
- Be on or before every row's `reference_date`.
- Differ from every `forecast_date` in the pre-existing file at the same path on the PR's base branch, if such a file exists. If no file exists there, this comparison is skipped. 

Submitting a file for which there is already a `model-output/` file at the same path will append the new submission to the old file, with the different submissions differentiated by `forecast_date`.

`forecast_date` is validated by the hub's custom PR script rather than configured in `tasks.json` because `forecast_date` values can take any valid `YYYY-MM-DD` and have no set required dates.

### `target`

Values in the `target` column must be the string `wk inc confirmed cases`: the number of confirmed cases with **symptom onset** in the epi week ending on `target_end_date`. This value will be the same for all rows in the file, but is required to be present for human readability and validation. See [`target-data/README.md`](../target-data/README.md) for the definition of the observed target data.

### `target_end_date`

Values in the `target_end_date` column must be a date in the ISO format

    YYYY-MM-DD

and must be a Saturday, the last day of the epi week (Sunday to Saturday) that the row refers to. Estimates may be submitted for any epi week from the start of the outbreak (`2026-02-14`) through three weeks after the `reference_date`, so a single file can contain nowcasts for recent, incompletely reported weeks and short-term forecasts of weeks to come. The full list of accepted values is in `hub-config/tasks.json` and is extended by one week each time a new `reference_date` is added. Teams are not required to submit every `target_end_date`.

### `location`

Values in the `location` column must be a location code listed in [`auxiliary-data/locations.csv`](../auxiliary-data/locations.csv). Three levels are accepted:

-   `CD` for the Democratic Republic of the Congo as a whole,
-   `CD-XX` for a province, where `XX` is the two-letter province code in the table below, and
-   `CD-XX-NN` for a health zone, where `NN` is the two-digit health zone number within province `XX` (for example `CD-IT-22`); the full list of health zone codes is in `locations.csv` and [`auxiliary-data/health-zone-code-mapping.csv`](../auxiliary-data/health-zone-code-mapping.csv).

| code | province | code | province |
|---|---|---|---|
| `CD-BU` | Bas Uele | `CD-LO` | Lomami |
| `CD-EQ` | Equateur | `CD-LU` | Lualaba |
| `CD-HK` | Haut Katanga | `CD-MN` | Mai Ndombe |
| `CD-HL` | Haut Lomami | `CD-MA` | Maniema |
| `CD-HU` | Haut Uele | `CD-MO` | Mongala |
| `CD-IT` | Ituri | `CD-NU` | Nord Ubangi |
| `CD-KS` | Kasai | `CD-NK` | Nord Kivu |
| `CD-KC` | Kasai Central | `CD-SA` | Sankuru |
| `CD-KE` | Kasai Oriental | `CD-SK` | Sud Kivu |
| `CD-KN` | Kinshasa | `CD-SU` | Sud Ubangi |
| `CD-BC` | Kongo Central | `CD-TA` | Tanganyika |
| `CD-KG` | Kwango | `CD-TO` | Tshopo |
| `CD-KL` | Kwilu | `CD-TU` | Tshuapa |

Teams are not required to submit every location; any subset of the country, provinces and health zones may be submitted.

### `output_type`

Values in the `output_type` column must be the string `sample`. Only sample-based output is accepted in this round; quantiles, means and medians are not.

### `output_type_id`

Values in the `output_type_id` column are integer sample indices. Each file must contain **exactly 100 samples** for every combination of `reference_date`, `location` and `target` that it includes.

The sample index identifies a trajectory: a given `output_type_id` for a given `location` must appear once for every `target_end_date` submitted for that location, and those rows together are one joint draw from the model's predictive distribution across weeks. In other words, for each location the file contains 100 complete trajectories, each covering the same set of `target_end_date`s. Sample indices may be reused across locations (for example `1` to `100` within each location) or be unique across the whole file; either is valid.

### `value`

Values in the `value` column are non-negative numbers giving the sampled weekly count of confirmed cases for that trajectory, location and `target_end_date`.

### Example

For estimates generated on `2026-10-26`, the first rows of `model-output/team-model/2026-10-31-team-model.csv` might look like the following. This example satisfies the forecast-date recency check only when validation runs within one day of `2026-10-26`; the round submission window must also be satisfied.

    reference_date,forecast_date,target,target_end_date,location,output_type,output_type_id,value
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-10,CD-IT,sample,1,209
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-17,CD-IT,sample,1,215
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-24,CD-IT,sample,1,190
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-31,CD-IT,sample,1,241
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-11-07,CD-IT,sample,1,253
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-10,CD-IT,sample,2,203
    ...

## Forecast validation

Pull requests that add or modify model-output files are validated automatically. Each file must meet the requirements above.

### Pull request forecast validation

The [submission workflow](../.github/workflows/validate-submission.yaml) calls [`src/validate-submission.R`](../src/validate-submission.R). The script checks `forecast_date` first, then runs the standard [Hubverse validations](https://github.com/hubverse-org/hubValidations), including the round submission window. To let Hubverse validate the configured task columns, the script creates a temporary hub copy with `forecast_date` removed from the submitted files. The original files retain the column, and all other columns are passed through to the standard checks.

Only added or modified model-output files in the PR are checked; unchanged historical files are not revalidated. The existing-file comparison uses the PR's base commit. If any file fails a custom check, the workflow stops; later files and the standard Hubverse checks will not run until the failure is resolved. Please [report validation issues](https://github.com/InsightNet-US/BDBV-Modeling-Hub/issues).

### Local forecast validation

The PR workflow runs all required checks automatically. Calling `hubValidations::validate_submission()` directly on a submitted file does not reproduce the custom checks and will reject `forecast_date` because it is not configured in `tasks.json`.

To reproduce the full workflow locally for an existing PR, check out that PR's files and run R from the repository root. Install `hubValidations`, `gh`, and `jsonlite`, and configure a GitHub token through the `GITHUB_PAT` environment variable. Set the PR number below, fetch its base commit, and run the same script used by CI:

```r
Sys.setenv(
  GITHUB_REPOSITORY = "InsightNet-US/BDBV-Modeling-Hub",
  PR_NUMBER = "123" # Replace with your PR number.
)
pr <- gh::gh(
  "/repos/{repo}/pulls/{number}",
  repo = Sys.getenv("GITHUB_REPOSITORY"),
  number = Sys.getenv("PR_NUMBER")
)
Sys.setenv(PR_BASE_SHA = pr$base$sha)
status <- system2("git", c("fetch", shQuote(pr$base$repo$clone_url), shQuote(pr$base$sha)))
stopifnot(status == 0L)
source("src/validate-submission.R")
```

The script requires PR context and checks the current date and submission window when run locally, just as it does in CI.

## Previous rounds

Files from earlier rounds are kept in this folder for archival purposes and remain available through the hub's data access tools. They no longer accept new or updated submissions, and their formats differ from the current round described above.

### Cumulative outbreak size estimates (May to October 2026)

The hub's first round, `BVBD 2026 cumulative outbreak size estimate`, collected estimates of the cumulative number of symptomatic Bundibugyo virus disease cases that had occurred in the Democratic Republic of the Congo as a whole as of the `reference_date`. Estimates were accepted for reference dates from `2026-05-18` to `2026-10-12`. The round included estimates published by several groups in May and June 2026, before the hub launched, which the hub standardized into hubverse format, as well as regular submissions through mid-October. The `reference_date` in that round was the date on which the estimate was generated.

Files in that round have the columns `reference_date`, `target`, `location`, `output_type`, `output_type_id` and `value`, where

-   `target` is always `cumulative cases`,
-   `location` is always `CD`, the ISO code for the Democratic Republic of the Congo,
-   `output_type` is `quantile`, `mean` or `median`,
-   `output_type_id` is the quantile level (`0.025`, `0.1`, `0.25`, `0.5`, `0.75`, `0.9`, `0.975`) for quantile rows and `NA` for mean and median rows, and
-   `value` is the non-negative estimate.

The configuration for this round is retained in `hub-config/tasks.json` so that the archived files continue to validate and load.
