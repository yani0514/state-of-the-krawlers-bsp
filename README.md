# State of the Krawlers – BSP Experiment Framework

This repository contains the applications, crawler configurations, automation scripts and reporting utilities used for the BSP project based on the paper **"SoK: State of the Krawlers"**.

The goal is to execute reproducible crawler experiments, generate code coverage reports and archive all experiment artifacts for later analysis.

---

# Repository Structure

```
.
├── apps/                     # Benchmark web applications
├── crawlers/                 # Crawljax configuration
├── experiments/              # Temporary experiment outputs
├── invalid-experiments/      # Failed or interrupted executions
├── reports/                  # Temporary generated reports
├── results/                  # Archived experiment results
├── scripts/                  # Automation scripts
├── report.py
├── report_nohistory.py
└── README.md
```

---

# Automation Scripts

## build_app.sh

Builds a single application.

Example:

```bash
./scripts/build_app.sh hotcrp
```

---

## build_all.sh

Builds all supported applications and reports whether each build succeeds.

Example:

```bash
./scripts/build_all.sh
```

---

## smoke-test-apps.sh

Runs a smoke test for every application.

The script verifies that:

- the Docker image builds successfully;
- the application starts correctly;
- Arachnarium can launch the crawler.

Example:

```bash
./scripts/smoke-test-apps.sh
```

---

## archive_results.sh

Archives a completed experiment configuration.

The script automatically:

- creates a folder inside `results/`;
- moves the raw experiment directories;
- copies the generated reports;
- creates a README describing the experiment;
- records experiment IDs;
- records executed commands and runtimes;
- creates a ZIP archive;
- cleans the temporary `experiments/` and `reports/` directories.

Example:

```bash
./scripts/archive_results.sh \
    hotcrp \
    random_local \
    general_paths \
    3 \
    30
```

---

## run_experiments.sh

Executes the complete experiment pipeline.

For every configured application the script executes:

- BFS (1 execution)
- DFS (1 execution)
- Random State (3 executions)
- Random Local (3 executions)

using the configured page similarity algorithm.

For every completed configuration it automatically:

1. executes the crawler;
2. validates the generated experiment;
3. generates the coverage report;
4. archives all results;
5. creates a ZIP archive;
6. cleans the working directories;
7. continues with the next configuration.

The script can safely resume interrupted campaigns because already archived configurations are skipped automatically.

Example:

```bash
MINUTES=30 ./scripts/run_experiments.sh
```

For testing:

```bash
MINUTES=1 ./scripts/run_experiments.sh
```

---

# Experiment Workflow

The recommended workflow is

```
Build applications
        │
        ▼
Smoke test
        │
        ▼
Run experiments
        │
        ▼
Generate coverage reports
        │
        ▼
Archive experiment results
        │
        ▼
Continue with next configuration
```

---

# Archived Results

Completed experiment configurations are stored under `results/`.

Example:

```
results/
└── hotcrp/
    ├── bfs_general_paths_1runs/
    ├── bfs_general_paths_1runs.zip
    │
    ├── dfs_general_paths_1runs/
    ├── dfs_general_paths_1runs.zip
    │
    ├── random_state_general_paths_3runs/
    ├── random_state_general_paths_3runs.zip
    │
    ├── random_local_general_paths_3runs/
    └── random_local_general_paths_3runs.zip
```

Each archived configuration contains:

```
configuration/
├── experiments/
│   └── <application>/
│       └── crawljax/
│           ├── <experiment-id-1>/
│           ├── <experiment-id-2>/
│           └── ...
│
├── reports/
│   ├── *.csv
│   └── ...
│
├── README.txt
├── experiments.txt
└── run_details.txt
```

The archived experiment directories include:

- raw code coverage files;
- Crawljax reports;
- screenshots;
- DOM snapshots;
- execution logs;
- runtime information;
- executed command lines.

---

# Temporary Directories

The following directories are considered temporary working directories:

- `experiments/`
- `reports/`

They should only contain the currently running experiment.

After successful archival they are automatically cleaned by `archive_results.sh`.

---

# Generated Files

The following files and directories are generated automatically and are ignored by Git:

- `results/`
- `campaign-logs/`
- `experiments/`
- `invalid-experiments/`
- generated CSV reports
- coverage files

---

# Notes

The automation pipeline is designed for long-running experiment campaigns.

If execution is interrupted, completed configurations remain archived under `results/`.

When the execution is started again, configurations that have already been archived are detected automatically and skipped, allowing the remaining experiments to continue without repeating completed work.
