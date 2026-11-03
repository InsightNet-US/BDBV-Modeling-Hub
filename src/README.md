# src

Code used by the hub to validate submissions and standardize externally published
estimates into [hubverse](https://hubverse.io) format.

## `derive_mccabe_quantiles.R`

Reconstructs the quantile distributions for the two McCabe et al. outbreak-size
estimates and (re)writes the corresponding `model-output/mccabe-*` CSV files.

The McCabe et al. paper (Lancet Infect Dis 2026,
[doi:10.1016/S1473-3099(26)00299-9](https://doi.org/10.1016/S1473-3099(26)00299-9),
code at <https://github.com/mrc-ide/evd-2026-outbreak-size>) reports a point
estimate and a 95% confidence interval for each method, "as of 27 May 2026". The
script reconstructs the full sampling distribution implied by each reported
interval and reads off the 7 hubverse quantiles:

- **Method 1 (back-calculation):** `1.879846 × Gamma(shape = 240.5, rate = 1)`,
  with the 2.5% quantile anchored to the paper's reported CI lower bound (396).
- **Method 2 (geographical spread):**
  `qnbinom(p, size = 3, prob = 0.0031736) + 3`.

These intervals reflect only the sampling uncertainty in the observed counts
(deaths for Method 1, exported cases for Method 2); they do **not** propagate
parameter uncertainty in the CFR, attributable-death fraction, travel volumes,
source population, or growth rate. See the `IMPORTANT UNCERTAINTY CAVEAT` in
each `model-metadata/mccabe-*.yml`. These estimates were transcribed by the hub,
not submitted by the original authors.

### Usage

```sh
Rscript src/derive_mccabe_quantiles.R
```

Re-running the script reproduces the committed CSVs exactly. It depends only on
base R (`qgamma`, `qnbinom`).

## `validate-submission.R`

Entry point for the [PR submission workflow](../.github/workflows/validate-submission.yaml). In addition to standard Hubverse validation, the script checks the appended forecast:

- Every row must have a nonblank, valid `YYYY-MM-DD` `forecast_date` on or before its `reference_date`.
- The PR must preserve all rows of the file at the same path in the base commit, including duplicate counts. Column and row reordering are allowed; parsed cell text and the column set must stay unchanged. Existing files without `forecast_date` fail.
- Added rows must contain exactly one new forecast date, absent from the base file, within one day of the validation date in Africa/Kinshasa. For a new file, all rows count as added data. Retained dates are exempt from the recency check. Submitting no new rows fails.

The script passes only the new forecast rows, without `forecast_date`, to Hubverse in a temporary hub copy. This prevents retained forecasts with reused sample or task IDs from being validated as a single forecast. The original PR file retains the full appended history. Standard submission-window checks remain enabled. Files are checked independently, and the script stops on the first custom validation failure.

The date is captured once for all files in a run. Later reruns may fail the recency check. See the [model-output README](../model-output/README.md#forecast_date) for submission requirements and [local validation instructions](../model-output/README.md#local-forecast-validation).

Requires R packages `hubValidations`, `gh`, and `jsonlite`, Git access to the PR base commit, and environment variables `GITHUB_REPOSITORY`, `PR_NUMBER`, `PR_BASE_SHA`, and `GITHUB_PAT`. 
