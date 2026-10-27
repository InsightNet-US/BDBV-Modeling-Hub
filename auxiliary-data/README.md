The `auxiliary-data/` directory contains additional data which may be of use to modeling teams. 

**Location Information**

`locations.csv` contains information about the target locations (provinces) and supplemental sub-target locations (health zones) within DRC. It contains the following comuns:

- `location`: the standardized code for the given location.
- `location_name`: the full name of the location.
- `location_type`: the administrative unit corresponding to the given location.
- `parent`: the administrative unit within which the given location resides. For provinces the parent is the whole country (DRC) and for health zones the parent is the province they are within.

We also provide the mapping between our location codes for each health zone, the P-Code, and the DHIS2 code in `health-zone-code-mapping.csv`. These codes were obtainted from the [Humanitarian Data Exchange](https://data.humdata.org/dataset/drc-health-data). 

**Daily Case Counts**

`daily-confirmed-case.csv` contains the number of reported cases by the day of symptom onset at the health zone, province, and national level and whether the date of symptom onset was observed or imputed. It contains the following columns:

- `as_of`: the date the data was released. As new versions of the data become available each week it will be appended to `time-series.csv` such that each unique value of `as_of` corresponds to a single data release made on that date.
- `target_end_date`: the day of the observation.
- `target`: the target corresponding to the given observation. In this case it is daily incident confirmed cases (`day inc confirmed cases`).
- `location`: the location code.
- `location_name`: the name of the location.
- `location-type`: the administrative unit corresponding to the given 'location'.
- `observation`: the observed or imputed value.
- `imputed`: whether or not the symptom onset date for the observation was directly observed (`FALSE`) or imputed (`TRUE`).

An additional source of daily case counts is the [DRC Ebola Bundibugyo - Epidemic Intelligence Dashboard](https://inrb-umie.github.io/BDBV2026-Epidemic_Dashboard/), which displays daily reported cases at the national, provincial, health zone, and health area levels, as well as information on spatial risk and the public health context.

**Weekly Province-Level Reporting Delays**

`weekly-reporting-delays-by-province.csv` gives the observed reporting delays by week of symptom onset at the province level. The file contains the following columns:

- `location_name`: the full name of the province. The mapping between province code and province name can also be found in auxiliary-data/locations.csv.
- `week_ending`: the last day of the epi week in which the case experienced symptom onset.
- `days_sym_to_report`: the number of days between the day in which the case experienced symptom onset and the day in which the case was reported. A value of zero indicates that the onset of symptoms and report of the case occurred on the same day.
- `as_of`: the date the data was released.
