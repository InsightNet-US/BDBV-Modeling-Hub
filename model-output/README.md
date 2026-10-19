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

The hub is currently collecting **nowcasts and forecasts of weekly incident confirmed cases by province** (round `BDBV 2026 nowcasting and forecasting` in [`hub-config/tasks.json`](../hub-config/tasks.json)). The file must be a comma-separated value (csv) file with the following columns (in any order):

-   `reference_date`
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

### `target`

Values in the `target` column must be the string `wk inc confirmed cases`: the number of confirmed cases with **symptom onset** in the epi week ending on `target_end_date`. This value will be the same for all rows in the file, but is required to be present for human readability and validation. See [`target-data/README.md`](../target-data/README.md) for the definition of the observed target data.

### `target_end_date`

Values in the `target_end_date` column must be a date in the ISO format

    YYYY-MM-DD

and must be a Saturday, the last day of the epi week (Sunday to Saturday) that the row refers to. Estimates may be submitted for any epi week from the start of the outbreak (`2026-02-14`) through three weeks after the `reference_date`, so a single file can contain nowcasts for recent, incompletely reported weeks and short-term forecasts of weeks to come. The full list of accepted values is in `hub-config/tasks.json` and is extended by one week each time a new `reference_date` is added. Teams are not required to submit every `target_end_date`.

### `location`

Values in the `location` column must be the two-letter code of a province of the Democratic Republic of the Congo, as listed in [`auxiliary-data/locations.csv`](../auxiliary-data/locations.csv):

| code | province | code | province |
|---|---|---|---|
| `BU` | Bas Uele | `LO` | Lomami |
| `EQ` | Equateur | `LU` | Lualaba |
| `HK` | Haut Katanga | `MN` | Mai Ndombe |
| `HL` | Haut Lomami | `MA` | Maniema |
| `HU` | Haut Uele | `MO` | Mongala |
| `IT` | Ituri | `NU` | Nord Ubangi |
| `KS` | Kasai | `NK` | Nord Kivu |
| `KC` | Kasai Central | `SA` | Sankuru |
| `KE` | Kasai Oriental | `SK` | Sud Kivu |
| `KN` | Kinshasa | `SU` | Sud Ubangi |
| `BC` | Kongo Central | `TA` | Tanganyika |
| `KG` | Kwango | `TO` | Tshopo |
| `KL` | Kwilu | `TU` | Tshuapa |

Teams are not required to submit every province; any subset may be submitted.

### `output_type`

Values in the `output_type` column must be the string `sample`. Only sample-based output is accepted in this round; quantiles, means and medians are not.

### `output_type_id`

Values in the `output_type_id` column are integer sample indices. Each file must contain **exactly 100 samples** for every combination of `reference_date`, `location` and `target` that it includes.

The sample index identifies a trajectory: a given `output_type_id` for a given `location` must appear once for every `target_end_date` submitted for that location, and those rows together are one joint draw from the model's predictive distribution across weeks. In other words, for each location the file contains 100 complete trajectories, each covering the same set of `target_end_date`s. Sample indices may be reused across locations (for example `1` to `100` within each province) or be unique across the whole file; either is valid.

### `value`

Values in the `value` column are non-negative numbers giving the sampled weekly count of confirmed cases for that trajectory, location and `target_end_date`.

### Example

The first rows of a valid file `model-output/team-model/2026-10-31-team-model.csv` might look like

    reference_date,target,target_end_date,location,output_type,output_type_id,value
    2026-10-31,wk inc confirmed cases,2026-10-10,IT,sample,1,209
    2026-10-31,wk inc confirmed cases,2026-10-17,IT,sample,1,215
    2026-10-31,wk inc confirmed cases,2026-10-24,IT,sample,1,190
    2026-10-31,wk inc confirmed cases,2026-10-31,IT,sample,1,241
    2026-10-31,wk inc confirmed cases,2026-11-07,IT,sample,1,253
    2026-10-31,wk inc confirmed cases,2026-10-10,IT,sample,2,203
    ...

## Forecast validation

To ensure proper data formatting, pull requests for new data in
`model-output/` will be automatically run. Optionally, you may also run these validations locally.

### Pull request forecast validation

When a pull request is submitted, the data are validated through [Github Actions](https://docs.github.com/en/actions) which runs the tests present in [the hubValidations package](https://github.com/hubverse-org/hubValidations). The  intent for these tests are to validate the requirements above. Please [let us know](https://github.com/InsightNet-US/BDBV-Modeling-Hub/issues) if you are facing issues while running the tests.

### Local forecast validation

Optionally, you may validate a forecast file locally before submitting it to the hub in a pull request. Note that this is not required, since the validations will also run on the pull request. To run the validations locally, follow these steps:

1. Create a fork of the `BDBV-Modeling-Hub` repository and then clone the fork to your computer.
2. Create a draft of the model submission file for your model and place it in the `model-output/<your model id>` folder of this clone.
3. Install the hubValidations package for R by running the following command from within an R session:
  ``` r
  remotes::install_github("hubverse-org/hubValidations")
  ```
4. Validate your draft forecast submission file by running the following command in an R session:
  ``` r
  library(hubValidations)
  hubValidations::validate_submission(
      hub_path="<path to your clone of the hub repository>",
      file_path="<path to your file, relative to the model-output folder>"
  )
  ```
  
  For example, if your working directory is the root of the hub repository, you can use a command similar to the following:
  ``` r
  library(hubValidations)
  hubValidations::validate_submission(
      hub_path=".",
      file_path="team-model/2026-10-31-team-model.csv"
  )
  ```
  The function returns the output of each validation check.
  
  If all is well, all checks should either be prefixed with a `✓` indicating success or `ℹ` indicating a check was skipped, e.g.:
  ```
  ✓ FluSight-forecast-hub: All hub config files are valid.
  ✓ 2026-10-31-team-model.csv: File exists at path model-output/team-model/2026-10-31-team-model.csv.
  ✓ 2026-10-31-team-model.csv: File name "2026-10-31-team-model.csv" is valid.
  ✓ 2026-10-31-team-model.csv: File directory name matches `model_id` metadata in file name.
  ✓ 2026-10-31-team-model.csv: `round_id` is valid.
  ✓ 2026-10-31-team-model.csv: File is accepted hub format.
  ...
  ```
  
  If there are any failed checks or execution errors, the check's output will be prefixed with a `✖` or `!` and include a message describing the problem.
  
  To get an overall assessment of whether the file has passed validation checks, you can pass the output of `validate_submission()` to `check_for_errors()`
  ```r
  library(hubValidations)
  
  validations <- validate_submission(
      hub_path = ".",
      file_path = "team-model/2026-10-31-team-model.csv"
  )
  
  check_for_errors(validations)
  ```
  If the file passes all validation checks, the function will return the following output:
  
  ```r
  ✓ All validation checks have been successful.
  ```
  If test failures or execution errors are detected, the function throws an error and prints the messages of checks affected. For example, the following output is returned when all other checks have passed but the file is being validated outside the submission time window for the round:
  
  ```r
  ! 2026-10-31-team-model.csv: Submission time must be within accepted submission window for round.  Current time
    2026-10-18 12:23:08 is outside window 2026-10-25 WAT--2026-10-27 23:59:59 WAT.
  Error in `check_for_errors()`:
  ! 
  The validation checks produced some failures/errors reported above.
  ```

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
