library(here)
library(data.table)
library(ggplot2)
library(tinytable)
library(svglite)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
benchmark_type <- if (length(args) >= 1) args[1] else "all"

# Custom theme ----
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
      plot.background = ggplot2::element_rect(color = "white"),
      plot.margin = ggplot2::margin(16, 16, 16, 16, unit = "pt"),
      panel.background = ggplot2::element_rect(color = "white", fill = "white"),
      panel.border = ggplot2::element_blank(),
      panel.spacing = grid::unit(1.5, "lines"),
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
      plot.caption = ggplot2::element_text(
        size = ggplot2::rel(1 / SCALE),
        color = "#71717a",
        hjust = 1,
        margin = ggplot2::margin(t = 20)
      ),
      plot.caption.position = "plot",
      axis.title = ggplot2::element_text(size = ggplot2::rel(1), color = "#27272a"),
      axis.title.y = ggplot2::element_text(hjust = 0.5, angle = 90, margin = ggplot2::margin(r = 10)),
      axis.title.x = ggplot2::element_text(hjust = 0.5, margin = ggplot2::margin(t = 10)),
      axis.text = ggplot2::element_text(size = ggplot2::rel(1 / SCALE), color = "#3f3f46"),
      axis.ticks = axis_line,
      axis.line = axis_line,
      axis.line.x.top = grepl_ifelse("t", axes, axis_line, ggplot2::element_blank()),
      axis.ticks.x.top = grepl_ifelse("t", axes, axis_line, ggplot2::element_blank()),
      axis.line.y.right = grepl_ifelse("r", axes, axis_line, ggplot2::element_blank()),
      axis.ticks.y.right = grepl_ifelse("r", axes, axis_line, ggplot2::element_blank()),
      axis.line.x.bottom = grepl_ifelse("b", axes, axis_line, ggplot2::element_blank()),
      axis.ticks.x.bottom = grepl_ifelse("b", axes, axis_line, ggplot2::element_blank()),
      axis.line.y.left = grepl_ifelse("l", axes, axis_line, ggplot2::element_blank()),
      axis.ticks.y.left = grepl_ifelse("l", axes, axis_line, ggplot2::element_blank()),
      legend.background = ggplot2::element_rect(color = "white"),
      legend.key = ggplot2::element_rect(color = "white", fill = "white"),
      legend.title = ggplot2::element_text(size = ggplot2::rel(1), color = "#3f3f46"),
      legend.text = ggplot2::element_text(size = ggplot2::rel(1 / SCALE), color = "#3f3f46"),
      strip.background = ggplot2::element_rect(color = "white", fill = "white"),
      strip.text = ggplot2::element_text(
        size = ggplot2::rel(1 / SCALE),
        color = "#27272a",
        margin = ggplot2::margin(t = 0, b = 8)
      ),
      panel.grid.major = grid_line,
      panel.grid.minor = grid_line,
      panel.grid.major.y = grepl_ifelse("h", grid, grid_line, ggplot2::element_blank()),
      panel.grid.minor.y = grepl_ifelse("h", grid_minor, grid_line, ggplot2::element_blank()),
      panel.grid.major.x = grepl_ifelse("v", grid, grid_line, ggplot2::element_blank()),
      panel.grid.minor.x = grepl_ifelse("v", grid_minor, grid_line, ggplot2::element_blank()),
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

  custom_theme <- custom_theme %+replace% ggplot2::theme(...)
  return(custom_theme)
}

# Color scheme (grouped by language) ----
color_switch <- c(
  # R (blues)
  "fixest::feols" = "#1565C0",
  "fixest::fepois" = "#1565C0",
  "fixest::feglm_logit" = "#1565C0",
  "lfe::felm" = "#64B5F6",
  # pyfixest (greens)
  "pyfixest.feols (numba)" = "#43A047",
  "pyfixest.feols (rust)" = "#2E7D32",
  "pyfixest.feols (scipy)" = "#A5D6A7",
  "pyfixest.fepois (numba)" = "#43A047",
  "pyfixest.fepois (rust)" = "#2E7D32",
  "pyfixest.fepois (scipy)" = "#A5D6A7",
  "pyfixest.feglm_logit (numba)" = "#43A047",
  "pyfixest.feglm_logit (rust)" = "#2E7D32",
  "pyfixest.feglm_logit (scipy)" = "#A5D6A7",
  # Python other (reds/oranges)
  "linearmodels.AbsorbingLS" = "#E53935",
  "statsmodels.OLS" = "#FF7043",
  # Julia (yellows)
  "FixedEffectModels.reg" = "#FFB300",
  "GLFixedEffectModels Logit" = "#FFB300",
  "GLFixedEffectModels Poisson" = "#FFB300"
)

# Legend order (grouped by language)
legend_order <- c(
  # R
  "lfe::felm",
  # pyfixest
  "pyfixest.feols (numba)", "pyfixest.feols (rust)", "pyfixest.feols (scipy)",
  "pyfixest.fepois (numba)", "pyfixest.fepois (rust)", "pyfixest.fepois (scipy)",
  "pyfixest.feglm_logit (numba)", "pyfixest.feglm_logit (rust)", "pyfixest.feglm_logit (scipy)",
  # Python other
  "linearmodels.AbsorbingLS", "statsmodels.OLS",
  # Julia
  "FixedEffectModels.reg", "GLFixedEffectModels Logit", "GLFixedEffectModels Poisson"
)

dgp_labels <- c("simple" = "Simple", "difficult" = "Difficult")
n_fe_labels <- c("2" = "Unit + Time FEs", "3" = "Unit + Time + Firm FEs")

# Helper function to create slowdown ratio plot (relative to fixest)
create_benchmark_plot <- function(data, title_suffix = "") {
  # Aggregate mean times
  summ <- data |>
    _[n_fe %in% c(2L, 3L), ] |>
    _[,
      .(
        mean_time = mean(time, na.rm = TRUE),
        n_failures = sum(is.na(time))
      ),
      by = setdiff(names(data), c("iter", "time"))
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

  # Extract fixest baseline times
  baseline <- summ[grepl("^fixest::", est_name), .(dgp_name, n_fe, n_obs, baseline_time = mean_time)]

  # Join and compute slowdown ratio
  summ <- summ[baseline, on = .(dgp_name, n_fe, n_obs), nomatch = NULL]
  summ[, slowdown := mean_time / baseline_time]

  # Remove fixest itself (always 1.0)
  summ <- summ[!grepl("^fixest::", est_name)]

  # Order legend by language group
  present_levels <- intersect(legend_order, unique(summ$est_name))
  summ[, est_name := factor(est_name, levels = present_levels)]

  # Prepare baseline labels for annotation
  baseline_labels <- baseline[, .(dgp_name, n_fe, n_obs, baseline_time)]
  baseline_labels[, dgp_label := factor(
    dgp_labels[match(dgp_name, names(dgp_labels))], dgp_labels
  )]
  baseline_labels[, n_fe_label := factor(
    n_fe_labels[match(n_fe, names(n_fe_labels))], n_fe_labels
  )]
  baseline_labels[, time_label := fifelse(
    baseline_time >= 1,
    sprintf("%.1fs", baseline_time),
    sprintf("%.0fms", baseline_time * 1000)
  )]

  summ |>
    ggplot() +
    geom_hline(yintercept = 1, linetype = "dashed", color = "#1565C0", linewidth = 0.7) +
    geom_point(
      aes(x = n_obs, y = slowdown, color = est_name),
      size = 2, shape = 15
    ) +
    geom_line(
      aes(x = n_obs, y = slowdown, color = est_name),
      linewidth = 1.15
    ) +
    geom_label(
      data = baseline_labels,
      aes(x = n_obs, y = 1, label = time_label),
      vjust = 1.3, size = 2.2, color = "#1565C0",
      fill = "white", label.size = 0, label.padding = unit(1, "pt")
    ) +
    facet_grid(dgp_label ~ n_fe_label) +
    scale_x_continuous(
      transform = "log10",
      labels = scales::label_number(scale_cut = scales::cut_long_scale())
    ) +
    scale_y_continuous(
      transform = "log2",
      breaks = c(0.5, 1, 2, 4, 8, 16, 32, 64),
      labels = function(x) paste0(x, "x")
    ) +
    scale_color_manual(values = color_switch) +
    labs(
      x = "Number of Observations",
      y = "Slowdown vs fixest",
      color = NULL,
      caption = "Dashed blue line = fixest (1x). Values >1x are slower. Missing points indicate failures."
    ) +
    custom_theme(legend = "bottom")
}

# Process benchmark type(s)
process_benchmark <- function(type) {
  csv_file <- here(sprintf("results/bench_%s.csv", type))

  if (!file.exists(csv_file)) {
    cat(sprintf("Skipping %s: %s not found\n", type, csv_file))
    return(invisible(NULL))
  }

  cat(sprintf("Processing %s benchmark...\n", type))
  data <- fread(csv_file)

  plot <- create_benchmark_plot(data)

  # Save PDF and SVG
  ggsave(
    filename = here(sprintf("results/plot_%s.pdf", type)),
    plot = plot,
    width = 9,
    height = 6
  )
  ggsave(
    filename = here(sprintf("results/plot_%s.svg", type)),
    plot = plot,
    width = 9,
    height = 6
  )

  cat(sprintf("  -> Saved results/plot_%s.pdf and results/plot_%s.svg\n", type, type))
}

# Process real data benchmark
process_real_data <- function() {
  csv_file <- here("results/bench_ols_real_data.csv")

  if (!file.exists(csv_file)) {
    cat("Skipping real_data: results/bench_ols_real_data.csv not found\n")
    return(invisible(NULL))
  }

  cat("Processing real_data benchmark...\n")
  bench_real_data <- fread(csv_file)

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

  # Update README
  tab_md_string <- tab_real_data |>
    tinytable:::build_tt("gfm") |>
    _@table_string |>
    strsplit("\n") |>
    unlist()

  readme <- xfun::read_utf8(here("README.md"))
  insert_idx <- which(grepl("<!-- Real Data -->", readme))
  if (length(insert_idx) >= 2 && insert_idx[2] > insert_idx[1] + 1) {
    rows_to_keep <- setdiff(
      seq_len(length(readme)),
      (insert_idx[1] + 1):(insert_idx[2] - 1)
    )
    readme <- readme[rows_to_keep]
  }
  if (length(insert_idx) >= 1) {
    readme <- append(readme, tab_md_string, after = insert_idx[1])
    xfun::write_utf8(readme, here("README.md"))
    cat("  -> Updated README.md with real data table\n")
  }

  # LaTeX table
  tab_latex_string <- tab_real_data |>
    tinytable:::build_tt("latex") |>
    _@table_string |>
    strsplit("\n") |>
    unlist()

  cat(tab_latex_string, file = here("results/table_real_data.tex"), sep = "\n")
  cat("  -> Saved results/table_real_data.tex\n")
}

# Main execution
cat("\n")
cat("================================================================================\n")
cat(sprintf("SUMMARIZE BENCHMARKS: %s\n", toupper(benchmark_type)))
cat("================================================================================\n\n")

if (benchmark_type == "all") {
  process_benchmark("ols")
  process_benchmark("poisson")
  process_benchmark("logit")
  process_real_data()
} else if (benchmark_type == "real_data") {
  process_real_data()
} else {
  process_benchmark(benchmark_type)
}

cat("\nDone!\n")
