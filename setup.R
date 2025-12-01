# %%
library(data.table)
library(fixest)
library(JuliaCall)
library(here)

# %%
# setup R
source("timers/fixest.R")
source("timers/lfe.R")
source("timers/alpaca.R")
options(lfe.threads = 2)
setFixest_nthreads(2)

# setup python (via CSV + subprocess, no reticulate)
source("timers/pyfixest.R")

# setup julia
# This chaos is due to: https://github.com/JuliaInterop/JuliaCall/issues/238
Sys.setenv(JULIA_PROJECT = here())
Sys.setenv(JULIA_NUM_THREADS = 8)
julia_path <- Sys.which("julia")
if (julia_path != "") {
  julia_bin_cmd <- system("julia -e 'println(Sys.BINDIR)'", intern = TRUE)
  if (length(julia_bin_cmd) > 0 && julia_bin_cmd != "") {
    julia_bin_dir <- julia_bin_cmd[1]
    julia_lib_dir <- file.path(dirname(julia_bin_dir), "lib", "julia")
  } else {
    # Fallback: try to find julia executable
    julia_path <- Sys.which("julia")
    if (julia_path == "") {
      stop("Julia not found")
    }
    julia_bin_dir <- dirname(julia_path)
    julia_lib_dir <- file.path(dirname(julia_bin_dir), "lib", "julia")
  }

  cat("Looking for libunwind in:", julia_lib_dir, "\n")
  # Platform-specific patterns
  if (Sys.info()["sysname"] == "Darwin") {
    # macOS
    libunwind_patterns <- c("libunwind*.dylib", "*unwind*.dylib")
    preload_var <- "DYLD_INSERT_LIBRARIES"
  } else {
    # Linux
    libunwind_patterns <- c("libunwind.so*", "libunwind-*.so*", "*unwind*.so*")
    preload_var <- "LD_PRELOAD"
  }

  # Look for libunwind in Julia's lib directory
  libunwind_path <- NULL
  for (pattern in libunwind_patterns) {
    files <- Sys.glob(file.path(julia_lib_dir, pattern))
    if (length(files) > 0) {
      libunwind_path <- files[1]
      break
    }
  }
  if (!is.null(libunwind_path) && file.exists(libunwind_path)) {
    dyn.load(libunwind_path)
  } else {
    warning("libunwind not found, Julia may have issues")
  }
}

JuliaCall::julia_setup()
JuliaCall::julia_eval('import Pkg; Pkg.activate("."); Pkg.instantiate();')
JuliaCall::julia_source("timers/FixedEffectModels.jl")

# set seed for (somewhat) reproducibility
set.seed(20250725)

# %%

# %%
run_benchmark <- function(
  name = "",
  dgps,
  estimators,
  burn_in = 1L
) {
  res <- NULL
  cat("\n")
  for (dgp_k in seq_len(nrow(dgps))) {
    dgp <- dgps$dgp_function[[dgp_k]]
    n_iters <- dgps$n_iters[dgp_k]
    cat("---- Starting DGP ----\n")
    print(subset(dgps[dgp_k, ], select = -c(dgp_function)))
    cat("\n")

    i = 1L
    while (i <= n_iters + burn_in) {
      cat(".")
      df <- dgp()
      times <- unlist(lapply(seq_len(nrow(estimators)), function(estimator_k) {
        f <- estimators$func[[estimator_k]]
        tryCatch(
          f(df),
          error = function(error) NA_real_
        )
      }))

      if (i > burn_in) {
        res_i <- data.frame(
          iter = i,
          time = times
        )
        res_i <- cbind(res_i, subset(estimators, select = -c(func)))
        res_i <- cbind(res_i, subset(dgps[dgp_k, ], select = -c(dgp_function)))
        res <- rbind(res, res_i)
      }
      i = i + 1
    }
    cat("\n\n")
  }

  return(res)
}

# %%
write_and_print_csv <- function(data, file, ...) {
  # Write the CSV file
  write.csv(data, file, ...)

  # Print the file name
  cat("File written:", file, "\n")

  # Print the contents
  cat("Contents:\n")
  cat(readLines(file), sep = "\n")
  cat("\n")
}
