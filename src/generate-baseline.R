# CDC flatline fitting plus direct trajectory output for the BDBV hub.
source("src/hub-model-utils.R")

fit_cdc_baseline <- function(training, seed) {
  training$time_value <- as.Date(training$time_value)
  training <- training[order(training$geo_value, training$time_value), ]
  args <- epipredict::cdc_baseline_args_list(
    aheads = 1:4, nsims = 100L, quantile_levels = .5, n_training = Inf
  )
  epi <- epiprocess::as_epi_df(training)
  withr::with_rng_version("4.0.0", withr::with_seed(seed, {
    epipredict::cdc_baseline_forecaster(epi, "observation", args)
  }))
}

simulate_cdc_paths <- function(residuals, point, n_paths = 100L) {
  # Same residual-CDF interpolation, symmetrization, propagation and boundary
  # treatment as CDC's quantile routine, retaining rows instead of quantiles.
  increments <- as.numeric(stats::quantile(
    c(residuals, -residuals), probs = (0:(n_paths - 1L)) / (n_paths - 1L),
    na.rm = TRUE, names = FALSE
  ))
  paths <- matrix(NA_real_, nrow = n_paths, ncol = 4L)
  accumulated <- pmax(0, point + increments)
  paths[, 1L] <- accumulated
  for (week in 2:4) {
    increments <- sample(increments, length(increments), replace = FALSE)
    accumulated <- accumulated + increments
    paths[, week] <- pmax(0, accumulated - (stats::median(accumulated) - point))
  }
  # Relabel whole paths, without sorting each week's values into common ranks.
  paths[sample.int(n_paths), , drop = FALSE]
}

format_cdc_baseline <- function(fit, training, reference_date, target) {
  ref <- as.Date(reference_date)
  anchor <- ref - 7L
  samples <- list()
  residuals <- workflows::extract_fit_parsnip(fit$epi_workflow)$fit$residuals
  for (location in sort(unique(training$geo_value))) {
    observed <- training$observation[
      training$geo_value == location & as.Date(training$time_value) == anchor
    ]
    stopifnot(length(observed) == 1L)
    residual_values <- residuals$.resid[residuals$geo_value == location]
    paths <- simulate_cdc_paths(residual_values, observed)
    samples[[length(samples) + 1L]] <- data.frame(
      reference_date = reference_date, target = target,
      target_end_date = rep(format(ref + 7L * (0:3), "%Y-%m-%d"), each = 100L),
      location = location, output_type = "sample",
      output_type_id = rep(1:100, times = 4L), value = as.vector(paths)
    )
  }
  do.call(rbind, samples)
}

generate_hub_baseline <- function(hub_path = ".", reference_date = "latest",
                                  overwrite_existing = FALSE, today = hub_today()) {
  task <- hub_task(hub_path, reference_date, today)
  path <- hub_output_path(hub_path, task$reference_date, "BDBVHub-baseline", overwrite_existing)
  data <- read.csv(file.path(hub_path, "target-data", "time-series.csv"), colClasses = "character")
  cutoff <- as.character(min(today, task$reference_date))
  data <- data[data$target == task$target & data$as_of <= cutoff, ]
  if (!nrow(data)) stop("No target data available by the run/reference date")
  vintage <- max(data$as_of)
  anchor <- task$reference_date - 7L
  dates <- format(task$reference_date + 7L * (0:3), "%Y-%m-%d")
  if (!all(dates %in% task$dates)) stop("Configure all baseline target dates for horizons 0 through 3")
  data <- data[data$as_of == vintage & data$location %in% task$locations &
                 data$target_end_date <= as.character(anchor), ]
  eligible <- unique(data$location[data$target_end_date == as.character(anchor)])
  omitted <- setdiff(unique(data$location), eligible)
  if (length(omitted)) message("Omitting locations missing the preceding week's observation: ", paste(omitted, collapse = ", "))
  data <- data[data$location %in% eligible, ]
  if (!nrow(data)) stop("Target data must contain the preceding week's observation")
  if (anyDuplicated(data[c("location", "target_end_date")])) stop("Duplicate target observations")
  values <- suppressWarnings(as.numeric(data$observation))
  if (any(!is.finite(values)) || any(values < 0)) stop("Invalid target observations")
  training <- data.frame(geo_value = data$location, time_value = as.Date(data$target_end_date), observation = values)
  seed <- hub_seed(task$reference_date)
  fit <- fit_cdc_baseline(training, seed)
  latest <- training[training$time_value == anchor, ]
  stopifnot(all(fit$predictions$.pred == latest$observation[match(fit$predictions$geo_value, latest$geo_value)]))
  samples <- withr::with_rng_version("4.0.0", withr::with_seed(as.integer((seed + 1) %% 2e9), {
    format_cdc_baseline(fit, training, as.character(task$reference_date), task$target)
  }))
  stopifnot(all(is.finite(samples$value)), all(samples$value >= 0))
  message("Target vintage: ", vintage, "; last observed week: ", anchor)
  hub_write_output(samples, path, task$reference_date)
}

if (sys.nframe() == 0L) do.call(generate_hub_baseline, hub_cli())
