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

 This value indicates the quantile probability level for for the
`value` in this row.

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

 *[TO BE ADDED: Add description for local forecast validation]*