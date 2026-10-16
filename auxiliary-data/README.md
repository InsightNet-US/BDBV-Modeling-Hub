The `auxiliary-data/` directory contains additional data which may be of use to modeling teams. 

**Location Information**

`locations.csv` contains information about the target locations (provinces) and supplemental sub-target locations (health zones) within DRC. It contains the following comuns:

- `location`: the two letter code for the given location. This is only available for provinces (the target locations). Health zone information is auxiliary and does not have a code.
- `location_name`: the full name of the province or health zone.
- `location_type`: the administrative unit corresponding to the given location (province or health zone).
- `parent`: the administrative unit within which the given location resides. For provinces the parent is the whole country (DRC) and for health zones the parent is the province they are within.

**Daily Health Zone-Level Case Counts**

`daily-confirmed-case-by-hz.csv` contains the number of reported cases by the day of symptom onset at the health zone level and whether the date of symptom onset was observed or imputed. It contains the following columns:

- `as_of`: the date the data was released. As new versions of the data become available each week it will be appended to `time-series.csv` such that each unique value of `as_of` corresponds to a single data release made on that date.
- `target_end_date`: the day of the observation.
- `target`: the target corresponding to the given observation. In this case it is daily incident confirmed cases (`day inc confirmed cases`).
- `location': the name of the health zone.
- `location-type`: the administrative unit corresponding to the given 'location' (in this case health zone).
- `observation`: the observed or imputed value.
- `imputed`: whether or not the symptom onset date for the observation was directly observed (`FALSE`) or imputed (`TRUE`).

**Weekly Province-Level Reporting Delays**

`weekly-reporting-delays-asof-YYYY-MM-DD.csv` gives the observed reporting delays by week of symptom onset at the province level. The date in the file name indicates the version of the line list the reporting delay information was extracted from and corresponds to the `as_of` date in the auxiliary health zone data and target data. The file contains the following columns:

- `location`: a two letter code indicating province.
- `location_name`: the full name of the province. The mapping between province code and province name can also be found in auxiliary-data/locations.csv.
- `week_ending`: the last day of the epi week in which the case experienced symptom onset.
- `days_sym_to_report`: the number of days between the day in which the case experienced symptom onset and the day in which the case was reported. A value of zero indicates that the onset of symptoms and report of the case occurred on the same day.
