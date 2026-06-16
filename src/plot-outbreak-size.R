library(hubUtils)
library(hubData)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggdist)

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

dplyr::bind_rows(
    quantile_wide |>
        dplyr::mutate(.lower = `0.25`, .upper = `0.75`, .width = 0.5),
    quantile_wide |>
        dplyr::mutate(.lower = `0.1`, .upper = `0.9`, .width = 0.8),
    quantile_wide |>
        dplyr::mutate(.lower = `0.025`, .upper = `0.975`, .width = 0.95)
) |>
    ggplot(aes(
        x = reference_date,
        y = `0.5`,
        ymin = .lower,
        ymax = .upper,
        color = model_id
    )) +
    ggdist::geom_pointinterval(
        aes(width = .width),
        position = position_dodge(width = 1)
    ) +
    scale_color_manual(values = model_colors) +
labs(
    title = "Cumulative Symptomatic Ebola Infections in DRC by Date",
    x = NULL,
    y = "Cumulative symptomatic cases",
    color = "Model"
)
