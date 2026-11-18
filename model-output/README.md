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

The hub collects nowcasts and forecasts of **weekly incident confirmed cases** and estimates of the **weekly effective reproduction number** by location (country, province or health zone). Both targets are defined in the `BDBV 2026 nowcasting and forecasting` round in [`hub-config/tasks.json`](../hub-config/tasks.json). Submit a CSV file with the following columns in any order.

-   `reference_date`
-   `forecast_date`
-   `target`
-   `target_end_date`
-   `location`
-   `output_type`
-   `output_type_id`
-   `value`

No additional columns are allowed.

### `reference_date`

Values in the `reference_date` column must be a date in the ISO format

    YYYY-MM-DD

The `reference_date` identifies the round. It is a Saturday, the last day of the epi week in which the estimates are made, and must match the date in the filename. The accepted reference dates are listed under the `BDBV 2026 nowcasting and forecasting` round in `hub-config/tasks.json`; a new one is added automatically each week. Submissions for a given `reference_date` are accepted from six to four days before it (Sunday through Tuesday of that week).

### `forecast_date`

The date the model was run to produce the forecasts in that row. Every submitted model-output file must include the `forecast_date` column. Every value must be a nonblank, valid calendar date in exactly `YYYY-MM-DD` format; `NA`, timestamps, and other date formats are rejected. Each row's `forecast_date` must be on or before its `reference_date`.

For a **new file**, all rows count as new data. They must share exactly one `forecast_date`, within one day of the date when validation runs in Africa/Kinshasa.

To **resubmit** (i.e., update an existing file with more forecasts), append the new forecast rows to your original file before opening or updating the PR. Validation does not append rows automatically. Compared with the file at the same path in the PR's base commit:

- Preserve every existing row unchanged, including duplicate-row counts. Row and column order may change, but the column set and parsed cell text must stay unchanged. For example, changing an existing value from `1.0` to `1` fails the preservation check.
- Add rows with exactly one new `forecast_date` that does not appear in the existing file. Submitting no new rows, adding rows to an existing forecast date, or introducing multiple new dates fails validation.
- The new date must be today (+/- one day for timezone difference) relative to the validation date in Africa/Kinshasa. Retained forecast dates are not subject to this recency check.

Files may contain multiple forecast dates after resubmission, each identifying a separate forecast. For example, to revise a forecast dated `2026-10-25` with a new forecast dated `2026-10-27`, retain all `2026-10-25` rows and add the new rows with `forecast_date` set to `2026-10-27`.

The filename still uses `reference_date`. Each file is checked independently, so different files may share a forecast date. The validation date is captured once per run; a later rerun can fail if the newly added date falls outside the one-day allowance. The standard round submission window still applies; appending a new forecast does not extend it.

`forecast_date` is validated by the hub's [custom HubValidations check](../src/validations/forecast-date.R), registered in [hub-config/validations.yml](../hub-config/validations.yml), rather than configured as a task ID in `tasks.json`. It has no fixed list of accepted or required values.

### `target`

Use one of the following target names in each row.

- `wk inc confirmed cases` is the number of confirmed cases with **symptom onset** in the epi week ending on `target_end_date`. The [observed target data](../target-data/README.md) are updated weekly, and the final revised counts serve as the comparison for these estimates.
- `wk R_t` is the weekly effective reproduction number for the epi week ending on `reference_date`. There is no observed target data for this target, as it is not an observed value.

### `target_end_date`

Values in the `target_end_date` column must be a date in the ISO format

    YYYY-MM-DD

and must be a Saturday, the last day of the epi week (Sunday to Saturday) that the row refers to.

- For `wk inc confirmed cases`, estimates may cover any epi week from the start of the outbreak (`2026-02-14`) through three weeks after `reference_date`. Teams may submit a subset of those dates.
- For `wk R_t`, set `target_end_date` equal to `reference_date` on every row. Submit one predictive distribution at **horizon 0** per location and `forecast_date`. The 23 quantile rows describe that single weekly estimate.

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

Use `sample` for `wk inc confirmed cases` and `quantile` for `wk R_t`.

### `output_type_id`

For `wk inc confirmed cases`, values in the `output_type_id` column are integer sample indices. Each forecast identified by `forecast_date` must contain **exactly 100 samples** for every combination of `reference_date`, `location` and `target` that it includes.

Within each `forecast_date`, the sample index identifies a trajectory. A given `output_type_id` for a given `location` must appear once for every `target_end_date` submitted for that location, and those rows together are one joint draw from the model's predictive distribution across weeks. In other words, for each location and `forecast_date` the file contains 100 complete trajectories, each covering the same set of `target_end_date`s. Sample indices may be reused across locations (for example `1` to `100` within each location) or be unique across the whole file; either is valid. Sample indices may also be reused across different forecast dates.

For `wk R_t`, use these 23 quantile levels as `output_type_id`. Include each level once per submitted location and `forecast_date` at horizon 0. Write levels without trailing zeros, such as `0.1`.

```text
0.01, 0.025, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5,
0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 0.975, 0.99
```

### `value`

Values must be non-negative numbers. For `wk inc confirmed cases`, give the sampled weekly case count for that trajectory, location and `target_end_date`. For `wk R_t`, give the estimated reproduction number at the quantile level in `output_type_id`.

### Examples

For estimates generated on `2026-10-26`, the first rows of `model-output/team-model/2026-10-31-team-model.csv` might look like the following. This example satisfies the forecast-date recency check only when validation runs within one day of `2026-10-26`; the round submission window must also be satisfied.

    reference_date,forecast_date,target,target_end_date,location,output_type,output_type_id,value
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-10,CD-IT,sample,1,209
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-17,CD-IT,sample,1,215
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-24,CD-IT,sample,1,190
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-31,CD-IT,sample,1,241
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-11-07,CD-IT,sample,1,253
    2026-10-31,2026-10-26,wk inc confirmed cases,2026-10-10,CD-IT,sample,2,203
    ...

The following excerpt shows three of the 23 required quantile rows for a `wk R_t` estimate for Ituri. Both `reference_date` and `target_end_date` are `2026-11-21`.

    reference_date,forecast_date,target,target_end_date,location,output_type,output_type_id,value
    2026-11-21,2026-11-16,wk R_t,2026-11-21,CD-IT,quantile,0.01,0.62
    2026-11-21,2026-11-16,wk R_t,2026-11-21,CD-IT,quantile,0.025,0.68
    2026-11-21,2026-11-16,wk R_t,2026-11-21,CD-IT,quantile,0.05,0.73
    ...

## Forecast validation

Pull requests that add or modify model-output files are validated automatically. Each file must meet the requirements above.

### Pull request forecast validation

The [submission workflow](../.github/workflows/validate-submission.yaml) uses the native `hubverse-org/hubverse-actions/validate-submission@v2` action, which runs [HubValidations](https://github.com/hubverse-org/hubValidations). The hub's [custom forecast-date check](../src/validations/forecast-date.R) is registered through [hub-config/validations.yml](../hub-config/validations.yml) and runs during file-level validation.

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
