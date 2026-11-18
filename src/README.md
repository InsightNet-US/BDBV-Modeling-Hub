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

## `validations/forecast-date.R`

Custom file-level checks used by the [submission workflow](../.github/workflows/validate-submission.yaml). [hub-config/validations.yml](../hub-config/validations.yml) registers `check_forecast_date()` with HubValidations.

The custom checks require:

- Every row to have a nonblank, valid `YYYY-MM-DD` `forecast_date` on or before its `reference_date`.
- Existing rows and columns to be preserved, including duplicate counts. Row and column reordering are allowed. The comparison uses the file at the same path in the PR's base commit; base files without exactly one `forecast_date` column fail.
- Exactly one new forecast date in the added rows, absent from the accepted file and within one day of the validation date in the hub's configured timezone (currently Africa/Kinshasa). For new files, all rows count as added data. Retained dates are exempt from the recency check; submitting no new rows fails.

The workflow creates a disposable hub copy. After the native file checks reach the custom hook, it checks the full submitted file against the original checkout and base commit. When one new forecast can be isolated, it replaces only the staged output with those new rows and removes `forecast_date` before native content validation. This prevents retained forecasts from inflating sample counts or creating duplicate tasks. The submitted files remain unchanged.

Independent custom issues are collected in the native `[forecast_date]` result. Date or history failures do not stop native content checks when preparation remains safe. Missing or duplicate forecast-date columns, multiple new forecast dates, unavailable base history, or unreadable data can prevent preparation; in that case the custom result blocks content checks for that file. Other files can continue. Native checks may also stop when their own prerequisites fail. Any custom failure still fails validation overall.

The custom hook requires `FORECAST_SOURCE_HUB` to identify the original checkout and `PR_BASE_SHA` to identify the locally available PR base commit. It refuses to rewrite the original checkout. The validation date is captured once per hub per R process; later reruns may fail the recency check.

## `validations/validate-pr.R`

The workflow calls `hubValidations::validate_pr()` through this script. When GitHub reports an existing model-output CSV as modified and its `forecast_date` check passes, the script removes the built-in `valid_file_status` error for that file.
