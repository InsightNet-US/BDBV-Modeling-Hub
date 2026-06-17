library(hubUtils)
library(hubData)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggdist)
library(mgcv)

hub_bucket <- s3_bucket("bdbv-modeling-hub")
hub_con <- hubData::connect_hub(hub_bucket, file_format = "parquet")
model_output <- hubData::collect_hub(hub_con)

# ColorBrewer Paired palette: 6 light/dark pairs, one pair per team.
# colorRampPalette interpolates within the pair for teams with >2 models.
paired_colors <- list(
    c("#a6cee3", "#1f78b4"),  # blue
    c("#fb9a99", "#e31a1c"),  # red
    c("#b2df8a", "#33a02c"),  # green
    c("#fdbf6f", "#ff7f00"),  # orange
    c("#cab2d6", "#6a3d9a"),  # purple
    c("#ffff99", "#b15928")   # yellow/brown
)

model_ids <- sort(unique(model_output$model_id))
model_teams <- sub("-.*", "", model_ids)
unique_teams <- unique(model_teams)

model_colors <- unlist(lapply(seq_along(unique_teams), function(i) {
    team <- unique_teams[i]
    team_models <- model_ids[model_teams == team]
    n <- length(team_models)
    pair <- paired_colors[[((i - 1) %% 6) + 1]]
    shades <- if (n == 1) pair[[2]] else colorRampPalette(pair)(n)
    setNames(shades, team_models)
}))

# geom_pointinterval (not stat_) takes pre-computed bounds directly, so no
# distribution object is needed. Pivot to wide so each quantile level becomes
# a column, then stack three copies of the data — one per interval width —
# with .lower/.upper/.width set explicitly.
quantile_wide <- model_output |>
    dplyr::filter(output_type == "quantile") |>
    tidyr::pivot_wider(names_from = output_type_id, values_from = value)

point_intervals <- dplyr::bind_rows(
    quantile_wide |>
        dplyr::mutate(.lower = `0.25`, .upper = `0.75`, .width = 0.5),
    quantile_wide |>
        dplyr::mutate(.lower = `0.1`, .upper = `0.9`, .width = 0.8),
    quantile_wide |>
        dplyr::mutate(.lower = `0.025`, .upper = `0.975`, .width = 0.95)
)

# Smoothed quantile-averaging ensemble. Rather than deriving a band from the
# scatter of the medians, fit the SAME spline separately to each quantile level
# (2.5%, 50%, 97.5%) and read the band straight off the fitted 2.5%/97.5%
# curves. At each date the fitted curve for a given level is essentially an
# average of the models' reported quantiles at that level, so the band carries
# the models' own stated uncertainty (a smoothed-over-time quantile average,
# i.e. Vincentization). Note this is an AVERAGE, not an envelope: an individual
# model's interval may extend beyond the band.
#
# Each fit is on the log10 scale because cumulative cases are positive and grow
# roughly multiplicatively, so the band is multiplicative once back-transformed
# (and cannot dip below zero); the averaging is therefore geometric. A penalized
# thin-plate spline (mgcv::gam, REML) is used with a small basis dimension: the
# data span only a handful of dates, and the penalty shrinks each curve toward a
# straight line (i.e. exponential growth) unless the estimates demand curvature.
origin_date <- min(quantile_wide$reference_date)
days <- as.numeric(quantile_wide$reference_date - origin_date)
k <- min(5, dplyr::n_distinct(days))
grid <- data.frame(day = seq(min(days), max(days), by = 1))

# Fit one log10 spline to a single quantile column and return the back-
# transformed curve over the daily grid.
fit_quantile_spline <- function(quantile_col) {
    fit_data <- data.frame(day = days, value = quantile_wide[[quantile_col]]) |>
        dplyr::filter(value > 0) |>
        dplyr::mutate(log_value = log10(value))
    fit <- mgcv::gam(log_value ~ s(day, k = k), data = fit_data, method = "REML")
    10^predict(fit, grid)
}

spline_band <- grid |>
    dplyr::mutate(
        reference_date = origin_date + day,
        .lower = fit_quantile_spline("0.025"),
        fit = fit_quantile_spline("0.5"),
        .upper = fit_quantile_spline("0.975")
    )

ggplot() +
    geom_ribbon(
        data = spline_band,
        aes(x = reference_date, ymin = .lower, ymax = .upper),
        fill = "grey50",
        alpha = 0.2
    ) +
    geom_line(
        data = spline_band,
        aes(x = reference_date, y = fit),
        color = "grey20",
        linewidth = 0.8
    ) +
    ggdist::geom_pointinterval(
        data = point_intervals,
        aes(
            x = reference_date,
            y = `0.5`,
            ymin = .lower,
            ymax = .upper,
            color = model_id,
            width = .width
        ),
        position = position_dodge(width = 1)
    ) +
    scale_color_manual(values = model_colors) +
labs(
    x = NULL,
    y = "Cumulative symptomatic cases",
    color = "Model"
)
