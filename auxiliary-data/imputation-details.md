
For confirmed cases where the date of symptom onset is missing in the line list,
we impute symptom onset dates according to the following methodology:

1. Using the line list data as of 2026-10-17, the observed reporting delay in days
is calculated as the number of calendar days elapsed between the date case began to 
exhibit symptoms and the date the case was reported. Because both the symptom onset
date and the report date are recorded to the day, this is treated as a double
interval censored observation of the reporting delay in hours: the time of symptom
onset is unknown within its 24 hour day (assumed uniform) and the time of report is
unknown within its 24 hour day.

2. Fit a generalized gamma distribution to the double interval censored hourly
reporting delay observations using `primarycensored::fitdistdoublecens()`, with the
generalized gamma distribution functions from the `flexsurv` package. A delay of
$d$ days corresponds to a primary (onset) window of 24 hours and a secondary
(report) window of $[24d, 24(d+1))$ hours.

3. For each missing symptom onset data, set the random seed equal to the integer
hash of the `alert_id`.

4. Sample the hour of day which the case was reported from a $\mathrm{Unif}(0,24)$
distribution.

5. Sample the reporting delay in hours from the fitted distribution in step 2.

6. Calculate the imputed date of symptom onset by subtracting the sampled reporting
delay from the sampled hour of report.

The following code chunk gives the function used to impute symptom onset dates as
part of the data processing pipeline.

```

impute_symptom_onset <- function(ll) {
  
  # The input to this function is the line list data frame which contains the 
  # following columns relevant to the imputation:
  # alert_id: unique identifier for a confirmed case
  # symptom_date: date of symptom onset, NA if missing
  # report_date: date the case was reported
  ll <- data.frame(alert_id = character(),
                   symptom_date = Date(),
                   report_date = Date())
  
  delays <- read.csv("auxiliary-data/archived-delay-data/weekly-reporting-delays-by-province-2026-10-17.csv")
  
  # Fit delay distribution to non-negative delays. Treat as a double interval
  # censored observation with hours as the unit: symptom onset is uniform
  # within a 24 hour primary window and the report falls in the 24 hour
  # secondary window [left, right). E.g. 0 days delay corresponds to a report
  # 0 to 24 hours after the start of the onset day, 1 day delay to 24 to 48
  # hours, etc. No right truncation is applied (D = Inf).
  cens <- delays %>%
    filter(days_sym_to_report >= 0) %>%
    mutate(left = days_sym_to_report*24,
           right = (days_sym_to_report+1)*24,
           pwindow = 24,
           D = Inf)
  
  # Fit generalized gamma distribution (pgengamma/dgengamma from flexsurv)
  fitgg <- fitdistdoublecens(cens, distr = "gengamma",
                             start = list(mu = 5, sigma = 1, Q = 0.5))
  
  # Filter to observations missing symptom onset date
  ll_miss <- ll %>%
    mutate(symptom_date = ifelse(symptom_date < "2026-01-01", NA, symptom_date)) %>%
    filter(is.na(symptom_date))
  
  rep_hours <- numeric(nrow(ll_miss))
  del_hours <- numeric(nrow(ll_miss))
  
  # Fix delay distribution parameters
  # Based on fit to 10/17/2026 data 
  sigma <- fitgg$estimate["sigma"]
  mu <- fitgg$estimate["mu"]
  Q <- fitgg$estimate["Q"]
  
  for(i in 1:nrow(ll_miss)) {
    
    # Set seed based on alert_id
    set.seed(digest::digest2int(ll_miss$alert_id[i]))
    
    # Sample report hours
    rep_hours[i] <- runif(1, 0, 24)
    
    # Sample delays in hours
    del_hours[i] <- rgengamma(1,
                              sigma = sigma,
                              mu = mu,
                              Q = Q)
  }
  
  symp_times <- rep_hours - del_hours
  symp_offset <- floor(symp_times/24)
  ll_miss$symptom_date_imp <- as_date(ll_miss$report_date + symp_offset)
  
  ll <- ll %>%
    left_join(ll_miss %>% 
                dplyr::select(alert_id,
                              symptom_date_imp)) %>%
    mutate(imputed = is.na(symptom_date),
           symptom_date = as_date(ifelse(is.na(symptom_date), symptom_date_imp, symptom_date))) %>%
    dplyr::select(-symptom_date_imp)
  
  return(ll)
  
}

```