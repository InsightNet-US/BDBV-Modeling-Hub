# Hub I/O for baseline generation; no separate settings files.
hub_today <- function() {
  as.Date(format(Sys.time(), tz = "Africa/Kinshasa", format = "%Y-%m-%d"))
}

hub_seed <- function(reference_date) {
  as.integer((20261027 + as.numeric(as.Date(reference_date))) %% 2e9)
}

hub_task <- function(hub_path, reference_date = "latest", today = hub_today()) {
  if (reference_date == "latest") {
    reference_date <- today + (6L - as.integer(format(today, "%w"))) %% 7L
  }
  ref <- as.Date(reference_date)
  if (is.na(ref) || format(ref, "%w") != "6") stop("reference_date must be a Saturday")
  cfg <- jsonlite::read_json(file.path(hub_path, "hub-config", "tasks.json"))
  if (length(cfg$rounds) < 2L) stop("Expected round two in tasks.json")
  tasks <- cfg$rounds[[2]]$model_tasks
  values <- function(field) unlist(c(field$required, field$optional), use.names = FALSE)
  tasks <- Filter(function(t) "sample" %in% names(t$output_type), tasks)
  if (length(tasks) != 1L) stop("Expected one sample task in round two")
  task <- tasks[[1]]
  target <- unique(values(task$task_ids$target))
  if (length(target) != 1L) stop("Baseline generation currently supports one target in round two")
  if (!as.character(ref) %in% values(task$task_ids$reference_date)) {
    stop("reference_date is not configured in tasks.json")
  }
  params <- task$output_type$sample$output_type_id_params
  if (params$min_samples_per_task != 100L || params$max_samples_per_task != 100L) {
    stop("Baseline generation requires exactly 100 samples")
  }
  list(reference_date = ref, target = target,
       dates = sort(values(task$task_ids$target_end_date)),
       locations = values(task$task_ids$location))
}

hub_output_path <- function(hub_path, reference_date, model_id, overwrite_existing) {
  path <- file.path(hub_path, "model-output", model_id,
                    paste0(reference_date, "-", model_id, ".csv"))
  if (file.exists(path) && !overwrite_existing) {
    stop("Output already exists; explicitly use --overwrite to replace it")
  }
  path
}

hub_write_output <- function(data, path, reference_date) {
  if (!nrow(data)) stop("No eligible forecast output")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(data, path, row.names = FALSE)
  if (file.info(path)$size > 100 * 1024^2) stop("Forecast exceeds GitHub's 100 MiB per-file limit")
  output <- Sys.getenv("GITHUB_OUTPUT")
  if (nzchar(output)) cat(paste0("reference_date=", reference_date, "\n"), file = output, append = TRUE)
  message("Generated ", path, " (", nrow(data), " rows)")
  invisible(path)
}

hub_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  dates <- args[args != "--overwrite"]
  if (length(dates) > 1L) stop("Usage: Rscript src/generate-baseline.R [latest|YYYY-MM-DD] [--overwrite]")
  list(reference_date = if (length(dates)) dates[[1]] else "latest",
       overwrite_existing = "--overwrite" %in% args)
}
