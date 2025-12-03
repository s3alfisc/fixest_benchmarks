#!/usr/bin/env python3
import argparse
import time
import pandas as pd
import pyfixest as pf


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", help="Path to input CSV")
    parser.add_argument("formula", help="Formula string")
    parser.add_argument("--method", choices=["feols", "fepois", "feglm_logit"], default="feols")
    parser.add_argument("--backend", choices=["rust", "rust-accelerated", "jax", "cupy32", "cupy64", "scipy"], default="rust")
    args = parser.parse_args()

    data = pd.read_csv(args.csv_path)

    start_time = time.time()
    if args.method == "feols":
        _ = pf.feols(args.formula, data, demeaner_backend=args.backend)
    elif args.method == "fepois":
        _ = pf.fepois(args.formula, data, demeaner_backend=args.backend)
    elif args.method == "feglm_logit":
        _ = pf.feglm(args.formula, data, "logit", demeaner_backend=args.backend)
    elapsed_time = time.time() - start_time

    print(elapsed_time)


if __name__ == "__main__":
    main()
