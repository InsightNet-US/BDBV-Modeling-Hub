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

Entry point for the [PR submission workflow](../.github/workflows/validate-submission.yaml). In addition to the standard `hubValidations`, this script will check for valid `forecast_date` entries:
* For every added or modified model-output file, it requires exactly one `forecast_date` column containing a single nonblank, valid `YYYY-MM-DD` date across all rows. 
* That `forecast_date` date must be within one day of the validation date (Africa/Kinshasa timezone) and on or before each row's `reference_date`.
* If a file exists at the same path in the PR's base commit, it must have a `forecast_date` column and none of its dates may appear in the PR version. The comparison is skipped only when no file exists at that path. Files are checked independently; the script stops on the first custom validation failure.

Requires R packages `hubValidations`, `gh`, and `jsonlite`, Git access to the PR base commit, and environment variables `GITHUB_REPOSITORY`, `PR_NUMBER`, `PR_BASE_SHA`, and `GITHUB_PAT`. 
