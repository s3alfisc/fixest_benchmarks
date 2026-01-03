#!/usr/bin/env python3
"""
Python benchmark runner for fixed-effect estimation.
Runs in a single persistent process so numba JIT compilation persists across iterations.
"""

import argparse
import csv
import signal
import sys
import time
from collections import defaultdict
from pathlib import Path

import pandas as pd


class TimeoutError(Exception):
    pass


def timeout_handler(signum, frame):
    raise TimeoutError("Estimation timed out")


def run_pyfixest_feols(data: pd.DataFrame, formula: str, backend: str) -> float:
    """Run pyfixest feols and return timing."""
    import pyfixest as pf

    start = time.perf_counter()
    _ = pf.feols(formula, data, demeaner_backend=backend)
    return time.perf_counter() - start


def run_pyfixest_fepois(data: pd.DataFrame, formula: str, backend: str) -> float:
    """Run pyfixest fepois and return timing."""
    import pyfixest as pf

    start = time.perf_counter()
    _ = pf.fepois(formula, data, demeaner_backend=backend)
    return time.perf_counter() - start


def run_pyfixest_feglm_logit(data: pd.DataFrame, formula: str, backend: str) -> float:
    """Run pyfixest feglm (logit) and return timing."""
    import pyfixest as pf

    start = time.perf_counter()
    _ = pf.feglm(formula, data, family="logit", demeaner_backend=backend)
    return time.perf_counter() - start


def parse_fe_formula(formula: str) -> tuple[str, list[str]]:
    """Parse formula like 'y ~ x1 | fe1 + fe2' into main formula and FE list."""
    if "|" in formula:
        main_part, fe_part = formula.split("|", 1)
        main_formula = main_part.strip()
        fe_names = [fe.strip() for fe in fe_part.split("+")]
        return main_formula, fe_names
    return formula, []


def run_absorbingls(data: pd.DataFrame, formula: str) -> float:
    """Run linearmodels AbsorbingLS and return timing."""
    from formulaic import model_matrix
    from linearmodels.iv.absorbing import AbsorbingLS

    main_formula, fe_names = parse_fe_formula(formula)

    start = time.perf_counter()
    y, X = model_matrix(main_formula, data)
    if fe_names:
        absorb = data[fe_names].astype("category")
    else:
        absorb = None
    mod = AbsorbingLS(y, X, absorb=absorb)
    _ = mod.fit()
    return time.perf_counter() - start


def run_statsmodels_ols(data: pd.DataFrame, formula: str) -> float:
    """Run statsmodels OLS (with categorical FEs as dummies)."""
    import statsmodels.formula.api as smf

    main_formula, fe_names = parse_fe_formula(formula)

    if fe_names:
        fe_terms = " + ".join(f"C({fe})" for fe in fe_names)
        full_formula = f"{main_formula} + {fe_terms}"
    else:
        full_formula = main_formula

    start = time.perf_counter()
    mod = smf.ols(full_formula, data=data)
    _ = mod.fit()
    return time.perf_counter() - start


def get_estimators(benchmark_type: str) -> list[tuple]:
    """Get estimators and formulas for benchmark type."""
    if benchmark_type == "ols":
        estimators = [
            ("pyfixest.feols (rust)", "rust", run_pyfixest_feols),
            ("pyfixest.feols (numba)", "numba", run_pyfixest_feols),
            ("linearmodels.AbsorbingLS", None, run_absorbingls),
            ("statsmodels.OLS", None, run_statsmodels_ols),
        ]
        formulas = {
            2: "y ~ x1 | indiv_id + year",
            3: "y ~ x1 | indiv_id + year + firm_id",
        }
    elif benchmark_type == "poisson":
        estimators = [
            ("pyfixest.fepois (rust)", "rust", run_pyfixest_fepois),
            ("pyfixest.fepois (numba)", "numba", run_pyfixest_fepois),
        ]
        formulas = {
            2: "negbin_y ~ x1 | indiv_id + year",
            3: "negbin_y ~ x1 | indiv_id + year + firm_id",
        }
    elif benchmark_type == "logit":
        estimators = [
            ("pyfixest.feglm_logit (rust)", "rust", run_pyfixest_feglm_logit),
            ("pyfixest.feglm_logit (numba)", "numba", run_pyfixest_feglm_logit),
        ]
        formulas = {
            2: "binary_y ~ x1 | indiv_id + year",
            3: "binary_y ~ x1 | indiv_id + year + firm_id",
        }
    else:
        raise ValueError(f"Unknown benchmark type: {benchmark_type}")

    return estimators, formulas


def parse_dataset_name(name: str) -> tuple[str, int]:
    """Parse dataset name like 'simple_1k' into (type, n_obs)."""
    size_map = {
        "1k": 1_000,
        "10k": 10_000,
        "100k": 100_000,
        "500k": 500_000,
        "1m": 1_000_000,
        "2m": 2_000_000,
    }
    parts = name.rsplit("_", 1)
    dgp_type = parts[0]
    n_str = parts[1] if len(parts) > 1 else "unknown"
    n_obs = size_map.get(n_str, 0)
    return dgp_type, n_obs


def run_benchmark(
    data_dir: Path,
    output_file: Path,
    benchmark_type: str,
    timeout: int = 60,
) -> None:
    """Run benchmarks on all datasets in data_dir."""
    estimators, formulas = get_estimators(benchmark_type)

    # Get all parquet files
    parquet_files = sorted(data_dir.glob("*.parquet"))
    if not parquet_files:
        print(f"No parquet files found in {data_dir}", file=sys.stderr)
        sys.exit(1)

    # Group files by dataset (excluding iteration suffix)
    datasets = defaultdict(list)
    for f in parquet_files:
        # Parse filename: simple_1k_burnin_1.parquet or simple_1k_iter_1.parquet
        parts = f.stem.rsplit("_", 2)
        if len(parts) >= 3:
            ds_name = parts[0]
            iter_type = parts[1]
            iter_num = int(parts[2])
            datasets[ds_name].append((iter_type, iter_num, f))

    results = []

    print("\n" + "=" * 80)
    print(f"PYTHON BENCHMARK: {benchmark_type.upper()}")
    print("=" * 80)
    print(f"Estimators: {len(estimators)} | FE configs: {len(formulas)} | Timeout: {timeout}s")

    # Set up timeout handler
    signal.signal(signal.SIGALRM, timeout_handler)

    for ds_name, files in sorted(datasets.items()):
        dgp_type, n_obs = parse_dataset_name(ds_name)

        print(f"\n{'-' * 80}")
        print(f"Dataset: {ds_name} (n={n_obs:,})")
        print(f"{'-' * 80}")

        # Sort files: burnin first, then iter
        files_sorted = sorted(files, key=lambda x: (0 if x[0] == "burnin" else 1, x[1]))

        for iter_type, iter_num, filepath in files_sorted:
            print(f"\n[{iter_type} {iter_num}] Loading {filepath.name}...")
            data = pd.read_parquet(filepath)

            for n_fe, formula in formulas.items():
                for est_name, backend, func in estimators:
                    print(f"  -> {est_name:<35} (FE={n_fe}) ... ", end="", flush=True)

                    # Set timeout alarm
                    signal.alarm(timeout)

                    try:
                        if backend:
                            elapsed = func(data, formula, backend)
                        else:
                            elapsed = func(data, formula)

                        signal.alarm(0)  # Cancel alarm
                        print(f"{elapsed:.3f}s")

                        # Only record non-burnin iterations
                        if iter_type != "burnin":
                            results.append({
                                "iter": iter_num,
                                "time": elapsed,
                                "est_name": est_name,
                                "n_fe": n_fe,
                                "dgp_name": dgp_type,
                                "n_obs": n_obs,
                            })

                    except TimeoutError:
                        signal.alarm(0)
                        print("TIMEOUT")
                        if iter_type != "burnin":
                            results.append({
                                "iter": iter_num,
                                "time": None,
                                "est_name": est_name,
                                "n_fe": n_fe,
                                "dgp_name": dgp_type,
                                "n_obs": n_obs,
                            })

                    except MemoryError:
                        signal.alarm(0)
                        print("OOM")
                        if iter_type != "burnin":
                            results.append({
                                "iter": iter_num,
                                "time": None,
                                "est_name": est_name,
                                "n_fe": n_fe,
                                "dgp_name": dgp_type,
                                "n_obs": n_obs,
                            })

                    except Exception as e:
                        signal.alarm(0)
                        error_msg = str(e).lower()
                        if any(x in error_msg for x in ["svd", "singular", "convergence"]):
                            print("NUMERICAL_ERROR")
                        else:
                            print(f"ERROR: {e}")
                        if iter_type != "burnin":
                            results.append({
                                "iter": iter_num,
                                "time": None,
                                "est_name": est_name,
                                "n_fe": n_fe,
                                "dgp_name": dgp_type,
                                "n_obs": n_obs,
                            })

    # Write results to CSV
    print("\n" + "=" * 80)
    print("BENCHMARK COMPLETE")
    print("=" * 80)

    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["iter", "time", "est_name", "n_fe", "dgp_name", "n_obs"]
        )
        writer.writeheader()
        writer.writerows(results)

    print(f"\nResults written to: {output_file}")


def main():
    parser = argparse.ArgumentParser(description="Run Python fixed-effect benchmarks")
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path("data/benchmark"),
        help="Directory containing parquet files",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("results/bench_python.csv"),
        help="Output CSV file",
    )
    parser.add_argument(
        "--type",
        choices=["ols", "poisson", "logit"],
        default="ols",
        help="Benchmark type",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=60,
        help="Timeout per estimation in seconds (default: 60)",
    )
    args = parser.parse_args()

    run_benchmark(args.data_dir, args.output, args.type, args.timeout)


if __name__ == "__main__":
    main()
