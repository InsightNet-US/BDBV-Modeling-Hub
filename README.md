# BDBV Modeling Hub

This modeling hub has been built to collect outbreak size estimates of the Bundibugyo (Ebola) virus outbreak in 2026.

This repository follows the guidelines and standards outlined by the [hubverse](https://hubverse.io), which provides a set of data formats and open source tools for modeling hubs.


## Outbreak size

As of mid-June 2026, several groups have generated estimates of outbreak size. 
Not all of these estimates have been for the same exact outcome. 
For example, some have predicted the total number of infections by a given date. 
Others have predicted the total number of symptomatic cases.

## Early estimates
This hub collects estimates made in May and June prior to the launch of this hub, and standardizes them using [hubverse](https://hubverse.io) data formats. 
Teams are encouraged to submit their own estimates.


**Dates:** 
Daily submissions (including dates in file names) will be specified in terms of the reference date, which should refer to the date the model estimates were generated. 

**Estimation Targets:**
Participating teams are asked to provide country-level estimates for the cumulative number of symptomatic cases occurring by the reference date.

**Locations:**
Upon launch, the hub is collecting estimates for the Democratic Republic of the Congo (ISO code `CD`) only. Other locations may be added later.


## Accessing BVBD data on the cloud

To ensure greater access to the data created by and submitted to this hub, real-time copies of files in the following directories are hosted on the Hubverse's Amazon Web Services (AWS) infrastructure, in a public S3 bucket: `bdbv-modeling-hub`.

- hub-config
- model-metadata
- model-output

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
  dplyr::filter(reference_date == as.Date("2026-06-13"), output_type == "quantile") %>%
  hubData::collect_hub() %>%
  dplyr::select(reference_date, model_id, target, location, output_type_id, value)

# A tibble: 14 × 6
#    reference_date model_id             target           location output_type_id value
#    <date>         <chr>                <chr>            <chr>             <dbl> <dbl>
#  1 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.025  291.
#  2 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.1    560.
#  3 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.25  1195.
#  4 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.5   2261 
#  5 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.75  4051.
#  6 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.9   6105.
#  7 2026-06-13     MOBS-GLEAM_BDBV      cumulative cases CD                0.975 9932.
#  8 2026-06-13     epiforecasts-renewal cumulative cases CD                0.025 1523 
#  9 2026-06-13     epiforecasts-renewal cumulative cases CD                0.1   1877 
# 10 2026-06-13     epiforecasts-renewal cumulative cases CD                0.25  2186 
# 11 2026-06-13     epiforecasts-renewal cumulative cases CD                0.5   2760 
# 12 2026-06-13     epiforecasts-renewal cumulative cases CD                0.75  3561 
# 13 2026-06-13     epiforecasts-renewal cumulative cases CD                0.9   4768 
# 14 2026-06-13     epiforecasts-renewal cumulative cases CD                0.975 6336 
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

*Coming soon: directions for accessing Hubverse-formatted target data.*

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
mo = ds.dataset("bdbv-modeling-hub/model-output/epiforecasts-renewal/", filesystem=s3, format="parquet").to_table()

# to convert the Pyarrow table to a Pandas dataframe:
df = mo.to_pandas()
df.head()

#   model_id             reference_date location target           output_type output_type_id value
# 0 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.025  1523
# 1 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.1    1877
# 2 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.25   2186
# 3 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.5    2760
# 4 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.75   3561
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
    pc.field("target") == "wk inc flu hosp") &
    pc.equal(pc.field("reference_date"), pa.scalar(datetime(2023, 10, 14), type=pa.date32())))

# to convert the Pyarrow table to a Pandas dataframe:
df = mo.to_pandas()
df.head()

#   model_id             reference_date location target           output_type output_type_id value
# 0 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.025 1523 
# 1 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.1   1877 
# 2 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.25  2186 
# 3 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.5   2760 
# 4 epiforecasts-renewal 2026-06-13     CD       cumulative cases quantile             0.75  3561 
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
aws s3 cp s3://bdbv-modeling-hub/model-output/epiforecasts-renewal/ . --recursive --no-sign-request
```

- [Full documentation for `aws s3 ls`](https://docs.aws.amazon.com/cli/latest/reference/s3/ls.html)
- [Full documentation for `aws s3 cp`](https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html)

</details>

## Acknowledgments
This repository follows the guidelines and standards outlined by the [hubverse]([url](https://hubdocs.readthedocs.io/en/latest/)), which provides a set of data formats and open source tools for modeling hubs.
