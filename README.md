# BDBV Modeling Hub

This modeling hub collects nowcasts and short-term forecasts of the 2026 Bundibugyo (Ebola) virus disease outbreak in the Democratic Republic of the Congo. Its first round, now closed, collected estimates of total outbreak size; see [Information on Past Rounds](#information-on-past-rounds).

This repository follows the guidelines and standards outlined by the [hubverse](https://hubverse.io), which provides a set of data formats and open source tools for modeling hubs.

This Hub is a joint effort of [Inisght Net](https://insightnet.us) centers ([ACCIDDA](https://accidda.org) and [epiEngage](https://epiengage.org)) and the [University of Kinshasa](https://www.unikin.ac.cd/).

## Current round: nowcasting and forecasting weekly confirmed cases

Participating teams submit, each week, sample trajectories of the number of confirmed cases by week of symptom onset in each province. Because cases are reported with a delay, recent weeks are incomplete when the data are released, so submissions cover both nowcasts of already-elapsed weeks and forecasts of weeks to come.

**Target:** `wk inc confirmed cases`, the number of confirmed cases with symptom onset in a given epi week (Sunday to Saturday). The observed data are in [`target-data/`](target-data/), with supporting data on reporting delays and health zone counts in [`auxiliary-data/`](auxiliary-data/).

**Locations:** the 26 provinces of the Democratic Republic of the Congo and the full country, identified by two-letter codes listed in [`auxiliary-data/locations.csv`](auxiliary-data/locations.csv).

**Dates:** each round is identified by a `reference_date`, the Saturday ending the epi week in which estimates are made. Submissions are accepted from Sunday through Tuesday of that week. Each file may cover any epi week from the start of the outbreak through three weeks after the reference date.

**Output:** 100 sample trajectories per province. Full details and an example file are in the [model-output README](model-output/README.md), and the exact task configuration is in [`hub-config/tasks.json`](hub-config/tasks.json).

**How to submit:** register a model by adding a metadata file to [`model-metadata/`](model-metadata/), then submit each week's file to [`model-output/`](model-output/) by pull request. Automated validation runs on every pull request. Sync your fork with this repository before each submission, since the target data and the accepted dates in `hub-config/tasks.json` change weekly.


## Accessing BVBD data on the cloud

To ensure greater access to the data created by and submitted to this hub, real-time copies of files in the following directories are hosted on the Hubverse's Amazon Web Services (AWS) infrastructure, in a public S3 bucket: `bdbv-modeling-hub`.

- hub-config
- model-metadata
- model-output
- target-data

GitHub remains the primary interface for operating the hub and collecting forecasts from modelers. However, the mirrors of hub files on S3 are the most convenient way to access hub data without using git/GitHub or cloning the entire hub to your local machine.

The sections below provide examples for accessing hub data on the cloud, depending on your goals and preferred tools. The options include:

| Access Method              | Description                                                                           |
| -------------------------- | ------------------------------------------------------------------------------------- |
| hubData (R)                | Hubverse R client and R code for accessing hub data                                   |
| Pyarrow (Python)           | Python open-source library for data manipulation                                      |
| AWS command line interface | Download data and use hubData, Pyarrow, or another tool for fast local access         |

In general, accessing the data directly from S3 (instead of downloading it first) is more convenient. However, if performance is critical (for example, you're building an interactive visualization), or if you need to work offline, we recommend downloading the data first.

<!-------------------------------------------------- hubData ------------------------------------------------------->

<details>

<summary>hubData (R)</summary>

[hubData](https://hubverse-org.github.io/hubData), the Hubverse R client, can create an interactive session for accessing, filtering, and transforming hub model output data stored in S3.

hubData is a good choice if you:

- already use R for data analysis
- want to interactively explore hub data from the cloud without downloading it
- want to save a subset of the hub's data (*e.g.*, forecasts for a specific date or target) to your local machine
- want to save hub data in a different file format (*e.g.*, parquet to .csv)

### Installing hubData

To install hubData and its dependencies (including the dplyr and arrow packages), follow the [instructions in the hubData documentation](https://hubverse-org.github.io/hubData/#installation).

### Using hubData

hubData's [`connect_hub()` function](https://hubverse-org.github.io/hubData/reference/connect_hub.html) returns an [Arrow multi-file dataset](https://arrow.apache.org/docs/r/reference/Dataset.html) that represents a hub's model output data. The dataset can be filtered and transformed using dplyr and then materialized into a local data frame using the [`collect_hub()` function](https://hubverse-org.github.io/hubData/reference/collect_hub.html).

#### Accessing model output data

Use hubData to connect to a hub on S3 and retrieve all model-output files into a local dataframe. (note: depending on the size of the hub, this operation will take a few minutes):

```r
library(dplyr)
library(hubData)

bucket_name <- "bdbv-modeling-hub"
hub_bucket <- s3_bucket(bucket_name)
hub_con <- hubData::connect_hub(hub_bucket, file_format = "parquet", skip_checks = TRUE)
model_output <- hub_con %>%
  hubData::collect_hub()

model_output
# A tibble: 135 × 7
#    model_id        reference_date location target           output_type output_type_id value
#  * <chr>           <date>         <chr>    <chr>            <chr>                <dbl> <dbl>
#  1 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.025  149.
#  2 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.1    286.
#  3 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.25   519 
#  4 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.5    882.
#  5 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.75  1374.
#  6 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.9   1987.
#  7 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases quantile             0.975 2858.
#  8 MOBS-GLEAM_BDBV 2026-05-24     CD       cumulative cases mean                NA     1040.
#  9 MOBS-GLEAM_BDBV 2026-06-13     CD       cumulative cases quantile             0.025  291.
# 10 MOBS-GLEAM_BDBV 2026-06-13     CD       cumulative cases quantile             0.1    560.
# ℹ 125 more rows
# ℹ Use `print(n = ...)` to see more rows
```

Use hubData to connect to a hub on S3 and filter model output data before "collecting" it into a local dataframe:

```r
library(dplyr)
library(hubData)

bucket_name <- "bdbv-modeling-hub"
hub_bucket <- s3_bucket(bucket_name)
hub_con <- hubData::connect_hub(hub_bucket, file_format = "parquet", skip_checks = TRUE)
hub_con %>%
  dplyr::filter(target == "wk inc confirmed cases", location == "IT") %>%
  hubData::collect_hub() %>%
  dplyr::select(reference_date, model_id, target_end_date, location, output_type_id, value)

# returns one row per model, target end date and sample for Ituri province
```

- [full hubData documentation](https://hubverse-org.github.io/hubData/)

</details>

<!--------------------------------------------------- Pyarrow ------------------------------------------------------->

<details>

<summary>Pyarrow (Python)</summary>

Python users can use [Pyarrow](https://arrow.apache.org/docs/python/index.html) to work with hub data in S3.

Pandas users can access hub data as described below and then use the `to_pandas()` method to get a Pandas dataframe.

Pyarrow is a good choice if you:

- already use Python for data analysis
- want to interactively explore hub data from the cloud without downloading it
- want to save a subset of the hub's data (*e.g.*, forecasts for a specific date or target) to your local machine
- want to save hub data in a different file format (*e.g.*, parquet to .csv)

### Installing pyarrow

Use pip to install Pyarrow:

```sh
python -m pip install pyarrow
```

### Using Pyarrow

The examples below start by creating a Pyarrow dataset that references the hub files on S3.

#### Accessing target data

Target data are mirrored to `s3://bdbv-modeling-hub/target-data/`. See the AWS command line section below for downloading them, or read `target-data/time-series.csv` directly from this repository.

#### Accessing model output data

Get all model-output files. This example creates an in-memory [Pyarrow table](https://arrow.apache.org/docs/python/generated/pyarrow.Table.html) with all model-output files from the hub (it will take a few minutes to run).

```python
import pyarrow.dataset as ds
import pyarrow.fs as fs

# define an S3 filesystem with anonymous access (no credentials required)
s3 = fs.S3FileSystem(access_key=None, secret_key=None, anonymous=True)

# create a Pyarrow dataset that references the hub's model-output files
# and convert it to an in-memory Pyarrow table
mo = ds.dataset("bdbv-modeling-hub/model-output/", filesystem=s3, format="parquet").to_table()

# to convert the Pyarrow table to a Pandas dataframe:
df = mo.to_pandas()
```

Get the model-output files for a specific team (all rounds).

```python
import pandas as pd
import pyarrow.dataset as ds
import pyarrow.fs as fs

# define an S3 filesystem with anonymous access (no credentials required)
s3 = fs.S3FileSystem(access_key=None, secret_key=None, anonymous=True)

# create a Pyarrow dataset that references a team's model-output files
# and convert it to an in-memory Pyarrow table
mo = ds.dataset("bdbv-modeling-hub/model-output/<model_id>/", filesystem=s3, format="parquet").to_table()

# to convert the Pyarrow table to a Pandas dataframe:
df = mo.to_pandas()
df.head()
```

- [Full documentation of Pyarrow table API](https://arrow.apache.org/docs/python/generated/pyarrow.Table.html)

Add a filter to model output data before converting it to a Pyarrow table. Filters are expressed as a [Pyarrow dataset Expression](https://arrow.apache.org/docs/python/generated/pyarrow.dataset.Expression.html#pyarrow.dataset.Expression).

```python
from datetime import datetime
import pandas as pd
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.dataset as ds
import pyarrow.fs as fs

# define an S3 filesystem with anonymous access (no credentials required)
s3 = fs.S3FileSystem(access_key=None, secret_key=None, anonymous=True)

# create a Pyarrow dataset that references a team's model-output files, apply filters,
# and convert it to an in-memory Pyarrow table
mo = ds.dataset("bdbv-modeling-hub/model-output/", filesystem=s3, format="parquet").to_table(
  filter=(
    pc.field("target") == "wk inc confirmed cases") &
    pc.equal(pc.field("reference_date"), pa.scalar(datetime(2026, 10, 31), type=pa.date32())))

# to convert the Pyarrow table to a Pandas dataframe:
df = mo.to_pandas()
df.head()
```

</details>

<!--------------------------------------------------- AWS CLI ------------------------------------------------------->

<details>

<summary>AWS CLI</summary>

AWS provides a terminal-based command line interface (CLI) for exploring and downloading S3 files. This option is ideal if you:

- plan to work with hub data offline but don't want to use git or GitHub
- want to download a subset of the data (instead of the entire hub)
- are using the data for an application that requires local storage or fast response times

### Installing the AWS CLI

- Install the AWS CLI using the
[instructions here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- You can skip the instructions for setting up security credentials, since Hubverse data is public

### Using the AWS CLI

When using the AWS CLI, the `--no-sign-request` option is required, since it tells AWS to bypass a credential check (*i.e.*, `--no-sign-request` allows anonymous access to public S3 data).

> [!NOTE]
> Files in the bucket's `raw` directory should not be used for analysis (they're for internal use only).

List all directories in the hub's S3 bucket:

```sh
aws s3 ls bdbv-modeling-hub --no-sign-request
```

List all files in the hub's bucket:

```sh
aws s3 ls bdbv-modeling-hub --recursive --no-sign-request
```

Download all of target-data contents to your current working directory:

```sh
aws s3 cp s3://bdbv-modeling-hub/target-data/ . --recursive --no-sign-request
```

Download the model-output files for a specific team:

```sh
aws s3 cp s3://bdbv-modeling-hub/model-output/<model_id>/ . --recursive --no-sign-request
```

- [Full documentation for `aws s3 ls`](https://docs.aws.amazon.com/cli/latest/reference/s3/ls.html)
- [Full documentation for `aws s3 cp`](https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html)

</details>

## Information on Past Rounds

### Cumulative outbreak size estimates (May to October 2026)

The hub's first round collected country-level estimates of the cumulative number of symptomatic cases that had occurred as of a reference date. It opened with estimates published by several groups in May and June 2026, before the hub launched, which the hub standardized into hubverse format from the published papers and code, and continued with regular submissions through reference date 2026-10-12. Not all early estimates targeted the same outcome; some reported total infections rather than symptomatic cases, and the model metadata files document each model's definition.

Submissions in that round used location `CD` and target `cumulative cases`, with quantile, mean and median output types. The round no longer accepts submissions. Its files remain in `model-output/` and on S3, and its format is described under "Previous rounds" in the [model-output README](model-output/README.md#previous-rounds).

## Acknowledgments
This hub is built with the data formats and open source tools of the [hubverse](https://docs.hubverse.io/).
