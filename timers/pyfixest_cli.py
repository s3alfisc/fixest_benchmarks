#!/usr/bin/env python3
import argparse
import signal
import sys
import time

import pandas as pd


class TimeoutError(Exception):
    """Raised when estimation times out."""

    pass


def timeout_handler(signum, frame):
    raise TimeoutError("Estimation timed out")


def parse_fe_formula(formula: str) -> tuple[str, list[str]]:
    """Parse formula like 'y ~ x1 | fe1 + fe2' into main formula and FE list.

    Returns:
        tuple: (main_formula like 'y ~ x1', list of FE names like ['fe1', 'fe2'])
    """
    if "|" in formula:
        main_part, fe_part = formula.split("|", 1)
        main_formula = main_part.strip()
        fe_names = [fe.strip() for fe in fe_part.split("+")]
        return main_formula, fe_names
    return formula, []


def run_absorbingls(
    data: pd.DataFrame, formula: str, model_matrix, AbsorbingLS
) -> None:
    """Run linearmodels AbsorbingLS with formula parsing via formulaic."""
    main_formula, fe_names = parse_fe_formula(formula)

    # Use formulaic to create design matrices
    y, X = model_matrix(main_formula, data)

    # Convert FE columns to categorical for absorbing
    if fe_names:
        absorb = data[fe_names].astype("category")
    else:
        absorb = None

    mod = AbsorbingLS(y, X, absorb=absorb)
    _ = mod.fit()


def run_statsmodels_ols(data: pd.DataFrame, formula: str, smf) -> None:
    """Run statsmodels OLS with formula (FEs as categorical dummies)."""
    main_formula, fe_names = parse_fe_formula(formula)

    # Build formula with C() for categorical fixed effects
    if fe_names:
        fe_terms = " + ".join(f"C({fe})" for fe in fe_names)
        full_formula = f"{main_formula} + {fe_terms}"
    else:
        full_formula = main_formula

    mod = smf.ols(full_formula, data=data)
    _ = mod.fit()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", help="Path to input CSV")
    parser.add_argument("formula", help="Formula string")
    parser.add_argument(
        "--method",
        choices=["feols", "fepois", "feglm_logit", "absorbingls", "statsmodels_ols"],
        default="feols",
    )
    parser.add_argument(
        "--backend",
        choices=["rust", "rust-accelerated", "numba", "jax", "cupy32", "cupy64", "scipy"],
        default="rust",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Timeout in seconds (default: 300 = 5 minutes)",
    )
    args = parser.parse_args()

    # Set up timeout handler (Unix only)
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(args.timeout)

    try:
        # Import packages BEFORE timing starts
        pf = None
        model_matrix = None
        AbsorbingLS = None
        smf = None

        if args.method in ("feols", "fepois", "feglm_logit"):
            import pyfixest as pf
        elif args.method == "absorbingls":
            from formulaic import model_matrix
            from linearmodels.iv.absorbing import AbsorbingLS
        elif args.method == "statsmodels_ols":
            import statsmodels.formula.api as smf

        # Load data (also before timing)
        data = pd.read_csv(args.csv_path)

        # NOW start timing - only the estimation
        start_time = time.time()

        if args.method == "feols":
            _ = pf.feols(args.formula, data, demeaner_backend=args.backend)
        elif args.method == "fepois":
            _ = pf.fepois(args.formula, data, demeaner_backend=args.backend)
        elif args.method == "feglm_logit":
            _ = pf.feglm(args.formula, data, "logit", demeaner_backend=args.backend)
        elif args.method == "absorbingls":
            run_absorbingls(data, args.formula, model_matrix, AbsorbingLS)
        elif args.method == "statsmodels_ols":
            run_statsmodels_ols(data, args.formula, smf)

        elapsed_time = time.time() - start_time

        # Cancel the alarm
        signal.alarm(0)

        print(elapsed_time)

    except MemoryError:
        signal.alarm(0)
        print("OOM")
        sys.exit(0)
    except TimeoutError:
        print("TIMEOUT")
        sys.exit(0)
    except Exception as e:
        signal.alarm(0)
        # Catch numerical errors (e.g., SVD did not converge, singular matrix)
        error_msg = str(e).lower()
        if "svd" in error_msg or "singular" in error_msg or "convergence" in error_msg:
            print("NUMERICAL_ERROR")
        else:
            # Re-raise unexpected errors
            raise
        sys.exit(0)


if __name__ == "__main__":
    main()
