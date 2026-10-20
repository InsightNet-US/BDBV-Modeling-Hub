The `target-data` directory contains the observed data on weekly confirmed cases to which the nowcasting an forecasting targets will be compared. Data is provided at the national level as well as by province and health zone. Cases are given by week of symptom onset rather than by the week the case was reported. Because of the evolving nature of this outbreak, as new versions of the target data become available backfill or other adjustments to case counts in already observed weeks may be observed. To reflect this, the data will be versioned such that teams can access the most recent data and all prior releases within the same file. New versions of the data will be made available by the 5:00 PM ET (US East Coast Time).

The target data file, `time-series.csv` has the following columns:

- `location`: a standardized code identifying the geographic location.
- `location_name`: the full name of the geographic location. The mapping between `location` and `location_name` can also be found in `auxiliary-data/locations.csv`.
- `location_type`: the administrative unit corresponding to the given 'location'
- `as_of`: the date the data was released. As new versions of the data become available each week it will be appended to `time-series.csv` such that each unique value of `as_of` corresponds to a single data release made on that date.
- `target_end_date`: the last day of the epi week in which the case experienced symptom onset.
-  `target`: the submission target corresponding to the given observation.
  - `wk inc confirmed cases` gives the incident confirmed cases with **symptom onset** in the given epi week. These values include cases for which the symptom onset date was imputed using the observed reporting delay distribution (see `auxiliary-data/` for more information about observed reporting delays).
- `observation`: the observed value.
