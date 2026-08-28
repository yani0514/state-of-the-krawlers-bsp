import csv
import json
import zipfile
from pathlib import Path


RESULTS = Path("results")


def find_scalar(obj, key):
    """
    Recursively find the first scalar value associated with `key`.
    Ignores dictionaries/lists stored under the same key.
    """
    if isinstance(obj, dict):
        if key in obj and not isinstance(obj[key], (dict, list)):
            return obj[key]

        for value in obj.values():
            result = find_scalar(value, key)
            if result is not None:
                return result

    elif isinstance(obj, list):
        for item in obj:
            result = find_scalar(item, key)
            if result is not None:
                return result

    return None


rows = []

for app_dir in sorted(RESULTS.iterdir()):
    if not app_dir.is_dir():
        continue

    for nav in ("bfs", "dfs"):
        zip_path = app_dir / f"{nav}_general_paths_1runs.zip"

        if not zip_path.exists():
            continue

        with zipfile.ZipFile(zip_path) as z:
            names = z.namelist()

            # -----------------------------------------
            # Read CSV summary
            # -----------------------------------------
            csv_files = [
                name for name in names
                if name.endswith(".csv")
            ]

            if not csv_files:
                print(f"WARNING: no CSV in {zip_path}")
                continue

            with z.open(csv_files[0]) as f:
                text = (
                    line.decode("utf-8")
                    for line in f
                )
                csv_rows = list(csv.DictReader(text))

            if not csv_rows:
                print(f"WARNING: empty CSV in {zip_path}")
                continue

            csv_row = csv_rows[-1]

            experiment = csv_row["experiment"]
            coverage = int(csv_row["cumcov"])
            runtime = float(csv_row["runtime"])

            # -----------------------------------------
            # Read Crawljax result.json
            # -----------------------------------------
            result_files = [
                name for name in names
                if name.endswith("result.json")
            ]

            if not result_files:
                print(f"WARNING: no result.json in {zip_path}")
                continue

            with z.open(result_files[0]) as f:
                result = json.load(f)

            states = find_scalar(
                result,
                "totalNumberOfStates"
            )

            edges = find_scalar(
                result,
                "edges"
            )

            paths = find_scalar(
                result,
                "crawlPaths"
            )

            exit_status = find_scalar(
                result,
                "exitStatus"
            )

            rows.append({
                "app": app_dir.name,
                "nav": nav.upper(),
                "experiment": experiment,
                "coverage": coverage,
                "runtime": runtime,
                "states": states,
                "edges": edges,
                "paths": paths,
                "exit": exit_status,
            })


# -----------------------------------------
# Print results
# -----------------------------------------

print(
    f"{'Application':<14}"
    f"{'Nav':<6}"
    f"{'Coverage':>10}"
    f"{'States':>8}"
    f"{'Edges':>8}"
    f"{'Paths':>8}"
    f"{'Runtime':>11}"
    f"{'Exit':>14}"
)

print("-" * 79)

for row in rows:
    print(
        f"{row['app']:<14}"
        f"{row['nav']:<6}"
        f"{row['coverage']:>10}"
        f"{str(row['states']):>8}"
        f"{str(row['edges']):>8}"
        f"{str(row['paths']):>8}"
        f"{row['runtime']:>11.1f}"
        f"{str(row['exit']):>14}"
    )