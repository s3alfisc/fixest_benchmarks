library(here)
library(data.table)
library(ggplot2)
library(tinytable)
library(pandoc)
library(svglite)

# load data
bench_ols = fread(here("results/bench_ols.csv"))
bench_poisson = fread(here("results/bench_poisson.csv"))
bench_logit = fread(here("results/bench_logit.csv"))
bench_ols_multiple_y = fread(here("results/bench_ols_multiple_y.csv"))
bench_ols_multiple_vcov = fread(here("results/bench_ols_multiple_vcov.csv"))
bench_real_data = fread(here("results/bench_ols_real_data.csv"))


# Custom theme ----
# Needed b/c ggplot2::element_* acts weird with `ife`lse`
grepl_ifelse <- function(pattern, x, yes, no) {
  if (grepl(pattern, x)) {
    return(yes)
  } else {
    return(no)
  }
}

custom_theme <- function(
  base_size = 12,
  axes = "bl",
  grid = "hv",
  grid_minor = "",
  legend = "right",
  map = FALSE,
  scale = 1.125,
  ...
) {
  # Fluid scale: https://utopia.fyi/type/
  SCALE <- scale

  grid_line_color <- "#e4e4e7"
  grid_line <- ggplot2::element_line(
    color = grid_line_color,
    linewidth = 0.35,
    linetype = "dashed"
  )

  grid_minor_line_color <- "#e4e4e7"
  grid_minor_line <- ggplot2::element_line(
    color = grid_minor_line_color,
    linewidth = 0.2,
    linetype = "dashed"
  )

  axis_line_color <- "#71717a"
  axis_line <- ggplot2::element_line(
    color = axis_line_color,
    linewidth = 0.3,
    linetype = "solid",
    inherit.blank = FALSE
  )

  custom_theme <-
    ggplot2::theme_bw(
      base_size = base_size
    ) %+replace%
    ggplot2::theme(
      ## Plot
      plot.background = ggplot2::element_rect(
        color = "white",
      ),
      plot.margin = ggplot2::margin(16, 16, 16, 16, unit = "pt"),

      ## Panel
      panel.background = ggplot2::element_rect(
        color = "white",
        fill = "white"
      ),
      panel.border = ggplot2::element_blank(),
      panel.spacing = grid::unit(1.5, "lines"),

      ## Title & subtitle
      plot.title = ggplot2::element_text(
        size = ggplot2::rel(SCALE^2),
        color = "#18181b",
        hjust = 0,
        margin = ggplot2::margin(b = 8, unit = "pt")
      ),
      plot.subtitle = ggplot2::element_text(
        size = ggplot2::rel(SCALE),
        color = "#71717a",
        hjust = 0,
        margin = ggplot2::margin(b = 16, unit = "pt")
      ),
      plot.title.position = "plot",

      ## Caption
      plot.caption = ggplot2::element_text(
        size = ggplot2::rel(1 / SCALE),
        color = "#71717a",
        hjust = 1,
        margin = ggplot2::margin(t = 20)
      ),
      plot.caption.position = "plot",

      ## Axes
      axis.title = ggplot2::element_text(
        size = ggplot2::rel(1),
        color = "#27272a"
      ),
      axis.title.y = ggplot2::element_text(
        hjust = 0.5,
        angle = 90,
        margin = ggplot2::margin(r = 10)
      ),
      axis.title.x = ggplot2::element_text(
        hjust = 0.5,
        margin = ggplot2::margin(t = 10)
      ),
      axis.text = ggplot2::element_text(
        size = ggplot2::rel(1 / SCALE),
        color = "#3f3f46"
      ),

      # Axes
      axis.ticks = axis_line,
      axis.line = axis_line,
      axis.line.x.top = grepl_ifelse(
        "t",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.ticks.x.top = grepl_ifelse(
        "t",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.line.y.right = grepl_ifelse(
        "r",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.ticks.y.right = grepl_ifelse(
        "r",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.line.x.bottom = grepl_ifelse(
        "b",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.ticks.x.bottom = grepl_ifelse(
        "b",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.line.y.left = grepl_ifelse(
        "l",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),
      axis.ticks.y.left = grepl_ifelse(
        "l",
        axes,
        axis_line,
        ggplot2::element_blank()
      ),

      ## Legend
      legend.background = ggplot2::element_rect(
        color = "white"
      ),
      legend.key = ggplot2::element_rect(
        color = "white",
        fill = "white"
      ),
      legend.title = ggplot2::element_text(
        size = ggplot2::rel(1),
        color = "#3f3f46"
      ),
      legend.text = ggplot2::element_text(
        size = ggplot2::rel(1 / SCALE),
        color = "#3f3f46"
      ),

      ## Facet Wrap
      strip.background = ggplot2::element_rect(
        color = "white",
        fill = "white"
      ),
      strip.text = ggplot2::element_text(
        size = ggplot2::rel(1 / SCALE),
        color = "#27272a",
        margin = ggplot2::margin(t = 0, b = 8)
      ),

      ## Gridlines
      # Default to none, edited below
      panel.grid.major = grid_line,
      panel.grid.minor = grid_line,
      panel.grid.major.y = grepl_ifelse(
        "h",
        grid,
        grid_line,
        ggplot2::element_blank()
      ),
      panel.grid.minor.y = grepl_ifelse(
        "h",
        grid_minor,
        grid_line,
        ggplot2::element_blank()
      ),
      panel.grid.major.x = grepl_ifelse(
        "v",
        grid,
        grid_line,
        ggplot2::element_blank()
      ),
      panel.grid.minor.x = grepl_ifelse(
        "v",
        grid_minor,
        grid_line,
        ggplot2::element_blank()
      ),

      # https://ggplot2-book.org/extensions#complete-themes
      complete = TRUE
    )

  if (legend == "top") {
    custom_theme <- custom_theme %+replace%
      ggplot2::theme(
        legend.position = "top",
        legend.margin = margin(0, 0, 5, 0),
        legend.justification = c(0, 1),
        legend.location = "plot",
        legend.key.spacing.x = unit(12, "pt"),
        complete = TRUE
      )
  } else if (legend == "bottom") {
    custom_theme <- custom_theme %+replace%
      ggplot2::theme(
        legend.position = "bottom",
        legend.title.position = "top",
        legend.margin = margin(5, 0, 0, 0),
        legend.justification = "center",
        legend.location = "plot",
        legend.key.spacing.x = unit(12, "pt"),
        complete = TRUE
      )
  }

  # Additional options
  custom_theme <- custom_theme %+replace% ggplot2::theme(...)

  return(custom_theme)
}


# Figures ----
color_switch <- c(
  "fixest::feols" = "#5C4CBF",
  "fixest::fepois" = "#5C4CBF",
  "fixest logit" = "#5C4CBF",
  "pyfixest.feols" = "#2DB25F",
  "pyfixest.fepois" = "#2DB25F",
  "FixedEffectModels.reg" = "#0188AC",
  "GLFixedEffectModels logit" = "#0188AC",
  "GLFixedEffectModels Poisson" = "#0188AC",
  "lfe::felm" = "#ffc517",
  "alpaca Poisson" = "#ffc517",
  "alpaca logit" = "#ffc517",
  "linearmodels.AbsorbingLS" = "#E57373",
  "statsmodels.OLS" = "#9C27B0"
)

dgp_labels <- c(
  "simple" = "Simple",
  "difficult" = "Difficult"
)
n_fe_labels <- c(
  "2" = "Unit + Time FEs",
  "3" = "Unit + Time + Firm FEs"
)

## OLS ----
summ_ols <- bench_ols |>
  _[n_fe %in% c(2L, 3L), ] |>
  _[,
    .(
      mean_time = mean(time, na.rm = TRUE),
      n_failures = sum(is.na(time))
    ),
    by = setdiff(names(bench_ols), c("iter", "time"))
  ] |>
  _[,
    dgp_label := factor(
      dgp_labels[match(dgp_name, names(dgp_labels))],
      dgp_labels
    )
  ] |>
  _[,
    n_fe_label := factor(
      n_fe_labels[match(n_fe, names(n_fe_labels))],
      n_fe_labels
    )
  ] |>
  _[order(dgp_label, n_fe_label), ]

(plot_ols <- summ_ols |>
  ggplot() +
  geom_point(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    size = 2,
    shape = 15
  ) +
  geom_line(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    linewidth = 1.15
  ) +
  facet_grid(
    dgp_label ~ n_fe_label,
  ) +
  scale_x_continuous(
    transform = "log10",
    labels = scales::label_number(
      scale_cut = scales::cut_long_scale()
    )
  ) +
  scale_y_continuous(
    breaks = c(0.01, 0.1, 1, 10, 60, 300),
    transform = "log10",
    labels = scales::label_timespan()
  ) +
  scale_color_manual(
    values = color_switch
  ) +
  labs(
    x = "Number of Observations",
    y = "Mean Estimation Time",
    color = NULL,
    caption = "Missing points indicate OOM errors or timeouts (>5 min)"
  ) +
  custom_theme(legend = "bottom"))

## Poisson ----
summ_poisson <- bench_poisson |>
  _[,
    .(
      mean_time = mean(time, na.rm = TRUE),
      n_failures = sum(is.na(time))
    ),
    by = setdiff(names(bench_poisson), c("iter", "time"))
  ] |>
  _[,
    dgp_label := factor(
      dgp_labels[match(dgp_name, names(dgp_labels))],
      dgp_labels
    )
  ] |>
  _[,
    n_fe_label := factor(
      n_fe_labels[match(n_fe, names(n_fe_labels))],
      n_fe_labels
    )
  ] |>
  sort_by(~ dgp_name + n_fe_label + n_obs + est_name)

(plot_poisson <- summ_poisson |>
  ggplot() +
  geom_point(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    size = 2,
    shape = 15
  ) +
  geom_line(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    linewidth = 1.15
  ) +
  facet_grid(
    dgp_label ~ n_fe_label,
  ) +
  scale_x_continuous(
    transform = "log10",
    labels = scales::label_number(
      scale_cut = scales::cut_long_scale()
    )
  ) +
  scale_y_continuous(
    breaks = c(0.01, 0.1, 1, 10, 60, 300),
    transform = "log10",
    labels = scales::label_timespan()
  ) +
  scale_color_manual(
    values = color_switch
  ) +
  labs(
    x = "Number of Observations",
    y = "Mean Estimation Time",
    color = NULL
  ) +
  custom_theme(legend = "bottom"))

## Logit ----
summ_logit <- bench_logit |>
  _[,
    .(
      mean_time = mean(time, na.rm = TRUE),
      n_failures = sum(is.na(time))
    ),
    by = setdiff(names(bench_logit), c("iter", "time"))
  ] |>
  _[,
    dgp_label := factor(
      dgp_labels[match(dgp_name, names(dgp_labels))],
      dgp_labels
    )
  ] |>
  _[,
    n_fe_label := factor(
      n_fe_labels[match(n_fe, names(n_fe_labels))],
      n_fe_labels
    )
  ]

(plot_logit <- summ_logit |>
  ggplot() +
  geom_point(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    size = 2,
    shape = 15
  ) +
  geom_line(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    linewidth = 1.15
  ) +
  facet_grid(
    dgp_label ~ n_fe_label,
  ) +
  scale_x_continuous(
    transform = "log10",
    labels = scales::label_number(
      scale_cut = scales::cut_long_scale()
    )
  ) +
  scale_y_continuous(
    breaks = c(0.01, 0.1, 1, 10, 60, 300),
    transform = "log10",
    labels = scales::label_timespan()
  ) +
  scale_color_manual(
    values = color_switch
  ) +
  labs(
    x = "Number of Observations",
    y = "Mean Estimation Time",
    color = NULL
  ) +
  custom_theme(legend = "bottom"))


## Real Data ----
summ_real_data <- bench_real_data |>
  _[,
    .(
      mean_time = mean(time, na.rm = TRUE),
      n_failures = sum(is.na(time))
    ),
    by = setdiff(names(bench_real_data), c("iter", "time"))
  ] |>
  _[order(n_obs), ]

tab_real_data <- summ_real_data |>
  _[, .(
    `Dataset` = dgp_name,
    `Num. obs.` = n_obs,
    `Estimator` = est_name,
    `Mean Estimation Time` = mean_time
  )] |>
  tt() |>
  format_tt(j = "Mean Estimation Time", digits = 2)

## README
tab_md_string <- tab_real_data |>
  tinytable:::build_tt("gfm") |>
  _@table_string |>
  strsplit("\n") |>
  unlist()

# Hacky way to change table text
readme <- xfun::read_utf8(here("README.md"))
insert_idx <- which(grepl("<!-- Real Data -->", readme))
if (insert_idx[2] > insert_idx[1] + 1) {
  rows_to_keep <- setdiff(
    seq_len(length(readme)),
    (insert_idx[1] + 1):(insert_idx[2] - 1)
  )
  readme <- readme[rows_to_keep]
}
readme <- append(readme, tab_md_string, after = insert_idx[1])
xfun::write_utf8(readme, here("README.md"))

## LATEX TABLE
tab_latex_string <- tab_real_data |>
  tinytable:::build_tt("latex") |>
  _@table_string |>
  strsplit("\n") |>
  unlist()

# # extract main body
# tab_latex_string <- tab_latex_string[
#   seq(
#     1 + grep("%% TinyTableHeader", tab_latex_string),
#     grep("\\\\bottomrule", tab_latex_string) - 1
#   )
# ]

cat(tab_latex_string, file = "results/table_real_data.tex", sep = "\n")


## Multiple y ----
(plot_ols_multiple_y <- bench_ols_multiple_y |>
  _[,
    .(
      mean_time = mean(time, na.rm = TRUE),
      n_failures = sum(is.na(time))
    ),
    by = setdiff(names(bench_ols_multiple_y), c("iter", "time"))
  ] |>
  ggplot() +
  geom_point(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    size = 2,
    shape = 15
  ) +
  geom_line(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    linewidth = 1.15
  ) +
  scale_x_continuous(
    transform = "log10",
    labels = scales::label_number(
      scale_cut = scales::cut_long_scale()
    )
  ) +
  scale_y_continuous(
    breaks = c(0.01, 0.1, 1, 10, 60, 300),
    transform = "log10",
    labels = scales::label_timespan()
  ) +
  scale_color_manual(
    values = color_switch
  ) +
  labs(
    x = "Number of Observations",
    y = "Mean Estimation Time",
    color = NULL
  ) +
  custom_theme(legend = "bottom"))

## Multiple vcov ----
(plot_ols_multiple_vcov <- bench_ols_multiple_vcov |>
  _[,
    .(
      mean_time = mean(time, na.rm = TRUE),
      n_failures = sum(is.na(time))
    ),
    by = setdiff(names(bench_ols_multiple_vcov), c("iter", "time"))
  ] |>
  ggplot() +
  geom_point(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    size = 2,
    shape = 15
  ) +
  geom_line(
    aes(
      x = n_obs,
      y = mean_time,
      color = est_name
    ),
    linewidth = 1.15
  ) +
  scale_x_continuous(
    transform = "log10",
    labels = scales::label_number(
      scale_cut = scales::cut_long_scale()
    )
  ) +
  scale_y_continuous(
    breaks = c(0.01, 0.1, 1, 10, 60, 300),
    transform = "log10",
    labels = scales::label_timespan()
  ) +
  scale_color_manual(
    values = color_switch
  ) +
  labs(
    x = "Number of Observations",
    y = "Mean Estimation Time",
    color = NULL
  ) +
  custom_theme(legend = "bottom"))

# Export ----
ggsave(
  filename = here("results/plot_ols.pdf"),
  plot = plot_ols,
  width = 9,
  height = 6
)
ggsave(
  filename = here("results/plot_poisson.pdf"),
  plot = plot_poisson,
  width = 9,
  height = 6
)
ggsave(
  filename = here("results/plot_logit.pdf"),
  plot = plot_logit,
  width = 9,
  height = 6
)

ggsave(
  filename = here("results/plot_ols.svg"),
  plot = plot_ols,
  width = 9,
  height = 6
)
ggsave(
  filename = here("results/plot_poisson.svg"),
  plot = plot_poisson,
  width = 9,
  height = 6
)
ggsave(
  filename = here("results/plot_logit.svg"),
  plot = plot_logit,
  width = 9,
  height = 6
)
# ggsave(
#   filename = here("results/plot_ols_multiple_y.pdf"),
#   plot = plot_ols_multiple_y,
#   width = 8,
#   height = 6
# )
# ggsave(
#   filename = here("results/plot_ols_multiple_y.svg"),
#   plot = plot_ols_multiple_y,
#   width = 8,
#   height = 6
# )
# ggsave(
#   filename = here("results/plot_ols_multiple_vcov.pdf"),
#   plot = plot_ols_multiple_vcov,
#   width = 8,
#   height = 6
# )
# ggsave(
#   filename = here("results/plot_ols_multiple_vcov.svg"),
#   plot = plot_ols_multiple_vcov,
#   width = 8,
#   height = 6
# )
