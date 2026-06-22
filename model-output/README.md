# Model outputs folder

This folder contains a set of subdirectories, one for each model, that contains submitted model output files for that model. The structure of these directories and their contents follows [the model output guidelines in our documentation](https://docs.hubverse.io/en/latest/user-guide/model-output.html). Documentation for hub submissions specifically is provided below.

# Data submission instructions

All estimates should be submitted directly to the [model-output/](./)
folder. Data in this directory should be added to the repository through
a pull request so that automatic data validation checks are run.

These instructions provide detail about the [data
format](#data-formatting) as well as [validation](#Forecast-validation) that
you can do prior to this pull request. In addition, we describe
[metadata](https://github.com/hubverse-org/hubTemplate/blob/master/model-metadata/README.md)
that each model should provide in the model-metadata folder.

*Table of Contents*

-   [Data formatting](#data-formatting)
-   [File format](#Forecast-file-format)
-   [Forecast data validation](#Forecast-validation)
-   [Weekly ensemble build](#Weekly-ensemble-build)
-   [Policy on late submissions](#policy-on-late-or-updated-submissions)


## Data formatting

The automatic checks in place for forecast files submitted to this
repository validates both the filename and file contents to ensure the
file can be used in the visualization and ensemble forecasting.

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

The date YYYY-MM-DD is the [`reference_date`](#reference_date). This should be the date on which the model estimates were generated, and ideally the day on which the estimates are submitted.

The `team` and `model` in this file must match the `team` and `model` in
the directory this file is in. Both `team` and `model` should be less
than 16 characters, alpha-numeric and underscores only, with no spaces
or hyphens.

## File format

The file must be a comma-separated value (csv) file with the following
columns (in any order):

-   `reference_date`
-   `target`
-   `location`
-   `output_type`
-   `output_type_id`
-   `value`

No additional columns are allowed.

The value in each row of the file is a quantile for a particular combination of location, target and reference_date.

### `reference_date`

Values in the `reference_date` column must be a date in the ISO format

    YYYY-MM-DD

This is the date on which the model output was generated. The `reference_date` should be the same as the date in the filename but should be included in the file itself as well to facilitate human readability, validation and analysis.

### `target`

Values in the `target` column must be a character (string) and be the string `cumulative cases`. Again, as long as the hub is only collecting estimates for this one target, this value will be the same for all rows in the data, but is required to be present for human readability and validation.


### `location`

The values in the `location` column must be `CD`, the ISO code for the Democratic Republic of the Congo. As models generate output for other locations, they may be added as well. As above, these values are required to be repeated for each row to ensure completeness and ensure that data validation passes.

### `output_type`

Values in the `output_type` column are one of the following

-   "quantile"
-   "mean"
-   "median"

This value indicates whether that row corresponds to a probabilistic quantile forecast or a point forecast (mean or median)

### `output_type_id`

Values in the `output_type_id` column specify identifying information for the output type.

#### quantile output

When the predictions are quantiles, values in the `output_type_id` column are a quantile probability level in the format

    0.###

This value indicates the quantile probability level for for the `value` in this row.

Teams must provide the following 7 quantiles:

    0.025, 0.1, 0.25, 0.5, 0.75, 0.90, 0.975

#### mean and median output

For mean and median output type values, the value in the `output_type_id` column should be `"NA"`.

### `value`

Values in the `value` column are non-negative numbers indicating the "quantile", "mean" or "median" prediction for this row. For a "quantile" prediction, `value` is the inverse of the cumulative distribution function (CDF) for the target, location, and quantile associated with that row. For example, the 2.5 and 97.5 quantiles for a given target and location should capture 95% of the predicted values and correspond to the central 95% Prediction Interval.

## Forecast validation

To ensure proper data formatting, pull requests for new data in
`model-output/` will be automatically run. Optionally, you may also run these validations locally.

### Pull request forecast validation

When a pull request is submitted, the data are validated through [Github
Actions](https://docs.github.com/en/actions) which runs the tests
present in [the hubValidations
package](https://github.com/hubverse-org/hubValidations). The
intent for these tests are to validate the requirements above. Please
[let us know](https://github.com/InsightNet-US/BDBV-Modeling-Hub/issues) if you are facing issues while running the tests.

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
    file_path="epiforecasts-renewal/2026-06-13-epiforecasts-renewal.csv"
)
```
The function returns the output of each validation check.

If all is well, all checks should either be prefixed with a `✓` indicating success or `ℹ` indicating a check was skipped, e.g.:
```
✓ FluSight-forecast-hub: All hub config files are valid.
✓ 2026-06-13-epiforecasts-renewal.csv: File exists at path model-output/epiforecasts-renewal/2026-06-13-epiforecasts-renewal.csv.
✓ 2026-06-13-epiforecasts-renewal.csv: File name "2026-06-13-epiforecasts-renewal.csv" is valid.
✓ 2026-06-13-epiforecasts-renewal.csv: File directory name matches `model_id` metadata in file name.
✓ 2026-06-13-epiforecasts-renewal.csv: `round_id` is valid.
✓ 2026-06-13-epiforecasts-renewal.csv: File is accepted hub format.
...
```

If there are any failed checks or execution errors, the check's output will be prefixed with a `✖` or `!` and include a message describing the problem.

To get an overall assessment of whether the file has passed validation checks, you can pass the output of `validate_submission()` to `check_for_errors()`
```r
library(hubValidations)

validations <- validate_submission(
    hub_path = ".",
    file_path = "epiforecasts-renewal/2026-06-13-epiforecasts-renewal.csv"
)

check_for_errors(validations)
```
If the file passes all validation checks, the function will return the following output:

```r
✓ All validation checks have been successful.
```
If test failures or execution errors are detected, the function throws an error and prints the messages of checks affected. For example, the following output is returned when all other checks have passed but the file is being validated outside the submission time window for the round:

```r
! 2026-06-20-epiforecasts-renewal.csv: Submission time must be within accepted submission window for round.  Current time
  2026-06-06 12:23:08 is outside window 2026-06-13 EDT--2026-07-18 23:59:59 EDT.
Error in `check_for_errors()`:
! 
The validation checks produced some failures/errors reported above.
```
