#!/usr/bin/env Rscript
# System information script for benchmark environment documentation

library(parallel)

cat("\n")
cat("================================================================================\n")
cat("BENCHMARK SYSTEM INFORMATION\n")
cat("================================================================================\n\n")

# Operating System
cat("## Operating System\n")
cat(sprintf("  Platform:      %s\n", R.version$platform))
cat(sprintf("  OS:            %s\n", Sys.info()["sysname"]))
cat(sprintf("  OS Version:    %s\n", Sys.info()["release"]))
cat(sprintf("  Machine:       %s\n", Sys.info()["machine"]))

# CPU Information
cat("\n## CPU\n")
cat(sprintf("  Cores:         %d\n", detectCores(logical = FALSE)))
cat(sprintf("  Threads:       %d\n", detectCores(logical = TRUE)))

# Try to get CPU model (platform-specific)
cpu_model <- tryCatch({
  if (Sys.info()["sysname"] == "Darwin") {
    system("sysctl -n machdep.cpu.brand_string", intern = TRUE)
  } else if (Sys.info()["sysname"] == "Linux") {
    cmd <- "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs"
    system(cmd, intern = TRUE)
  } else if (Sys.info()["sysname"] == "Windows") {
    system("wmic cpu get name", intern = TRUE)[2]
  } else {
    "Unknown"
  }
}, error = function(e) "Unknown")
cat(sprintf("  Model:         %s\n", trimws(cpu_model)))

# Memory Information
cat("\n## Memory\n")
mem_info <- tryCatch({
  if (Sys.info()["sysname"] == "Darwin") {
    mem_bytes <- as.numeric(system("sysctl -n hw.memsize", intern = TRUE))
    sprintf("%.1f GB", mem_bytes / 1024^3)
  } else if (Sys.info()["sysname"] == "Linux") {
    mem_kb <- as.numeric(system("grep MemTotal /proc/meminfo | awk '{print $2}'", intern = TRUE))
    sprintf("%.1f GB", mem_kb / 1024^2)
  } else if (Sys.info()["sysname"] == "Windows") {
    # Windows memory info is more complex
    "See system properties"
  } else {
    "Unknown"
  }
}, error = function(e) "Unknown")
cat(sprintf("  Total RAM:     %s\n", mem_info))

# Language Versions
cat("\n## Language Versions\n")

# R version
cat(sprintf("  R:             %s.%s\n", R.version$major, R.version$minor))

# Python version
python_version <- tryCatch({
  # Try uv first, then system python
  ver <- system("uv run python --version 2>/dev/null || python3 --version 2>/dev/null || python --version 2>/dev/null", intern = TRUE)
  gsub("Python ", "", ver[1])
}, error = function(e) "Not found")
cat(sprintf("  Python:        %s\n", python_version))

# Julia version
julia_version <- tryCatch({
  ver <- system("julia --version 2>/dev/null", intern = TRUE)
  gsub("julia version ", "", ver[1])
}, error = function(e) "Not found")
cat(sprintf("  Julia:         %s\n", julia_version))

# Key Package Versions
cat("\n## Key Package Versions\n")

# R packages
cat("  R packages:\n")
r_packages <- c("fixest", "lfe", "data.table", "arrow")
for (pkg in r_packages) {
  ver <- tryCatch(as.character(packageVersion(pkg)), error = function(e) "not installed")
  cat(sprintf("    - %s: %s\n", pkg, ver))
}

# Python packages
cat("  Python packages:\n")
py_packages <- c("pyfixest", "linearmodels", "statsmodels", "pandas", "pyarrow")
for (pkg in py_packages) {
  ver <- tryCatch({
    cmd <- sprintf("uv run python -c \"import %s; print(%s.__version__)\" 2>/dev/null", pkg, pkg)
    trimws(system(cmd, intern = TRUE))
  }, error = function(e) "not found", warning = function(w) "not found")
  if (length(ver) == 0 || ver == "") ver <- "not found"
  cat(sprintf("    - %s: %s\n", pkg, ver))
}

# Julia packages
cat("  Julia packages:\n")
julia_pkgs <- c("FixedEffectModels", "GLFixedEffectModels", "DataFrames")
for (pkg in julia_pkgs) {
  ver <- tryCatch({
    cmd <- sprintf('julia --project=. -e "using Pkg; deps = Pkg.dependencies(); for (uuid, dep) in deps; if dep.name == \\"%s\\"; println(dep.version); end; end" 2>/dev/null', pkg)
    trimws(system(cmd, intern = TRUE))
  }, error = function(e) "not found", warning = function(w) "not found")
  if (length(ver) == 0 || ver == "") ver <- "not found"
  cat(sprintf("    - %s: %s\n", pkg, ver))
}

# Benchmark Configuration
cat("\n## Benchmark Configuration\n")
cat(sprintf("  Threads used:  %d\n", 8L))
cat(sprintf("  Timeout:       %d seconds\n", 60L))

cat("\n================================================================================\n")
cat("Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("================================================================================\n\n")
