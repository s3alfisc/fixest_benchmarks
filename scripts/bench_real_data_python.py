#!/usr/bin/env python3
"""
Python real-data benchmark runner (pyfixest).
"""

import argparse
import csv
import json
import time
from pathlib import Path

import pandas as pd


def load_config() -> dict:
    cfg_path = Path("config/bench.json")
    if not cfg_path.exists():
        return {}
    return json.loads(cfg_path.read_text(encoding="utf-8"))


def run_pyfixest_feols(data: pd.DataFrame, formula: str) -> float:
    import pyfixest as pf

    start = time.perf_counter()
    _ = pf.feols(formula, data)
    return time.perf_counter() - start


def run_pyfixest_fepois(data: pd.DataFrame, formula: str) -> float:
    import pyfixest as pf

    start = time.perf_counter()
    _ = pf.fepois(formula, data)
    return time.perf_counter() - start


def run_pyfixest_feglm_logit(data: pd.DataFrame, formula: str) -> float:
    import pyfixest as pf

    start = time.perf_counter()
    _ = pf.feglm(formula, data, family="logit")
    return time.perf_counter() - start


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Python real-data benchmarks")
    parser.add_argument(
        "--type",
        choices=["ols", "poisson", "logit"],
        default="ols",
        help="Benchmark type",
    )
    args = parser.parse_args()

    config = load_config()
    real_cfg = config.get("real_data", [])
    if not real_cfg:
        raise SystemExit("No real_data config found in config/bench.json")

    results = []

    print("\n" + "=" * 80)
    print(f"PYTHON REAL-DATA BENCHMARK ({args.type.upper()})")
    print("=" * 80)

    for ds in real_cfg:
        formula = ds.get("formulas", {}).get(args.type, {}).get("python")
        if not formula:
            continue

        parquet_path = Path(ds["parquet"])
        if not parquet_path.exists():
            raise SystemExit(f"Missing parquet file: {parquet_path}")

        data = pd.read_parquet(parquet_path)
        n_obs = len(data)
        n_iters = int(ds["n_iters"])
        n_fe = int(ds["n_fe"])
        ds_name = ds["name"]

        print(f"\nDataset: {ds_name} (n={n_obs:,}, iters={n_iters})")
        for i in range(1, n_iters + 1):
            if args.type == "poisson":
                est_name = "pyfixest.fepois"
                runner = run_pyfixest_fepois
            elif args.type == "logit":
                est_name = "pyfixest.feglm_logit"
                runner = run_pyfixest_feglm_logit
            else:
                est_name = "pyfixest.feols"
                runner = run_pyfixest_feols

            print(f"  -> {est_name} (iter {i}/{n_iters}) ... ", end="", flush=True)
            try:
                elapsed = runner(data, formula)
                print(f"{elapsed:.3f}s")
            except Exception as e:
                print(f"ERROR: {e}")
                elapsed = None

            results.append(
                {
                    "iter": i,
                    "time": elapsed,
                    "est_name": est_name,
                    "n_fe": n_fe,
                    "dgp_name": ds_name,
                    "n_obs": n_obs,
                }
            )

    output = Path(f"results/bench_real_data_{args.type}_python.csv")
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["iter", "time", "est_name", "n_fe", "dgp_name", "n_obs"]
        )
        writer.writeheader()
        writer.writerows(results)

    print(f"\nResults written to: {output}")


if __name__ == "__main__":
    main()
