#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# Paths
###############################################################################

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXPERIMENTS_ROOT="$ROOT/experiments"
REPORTS_ROOT="$ROOT/reports"
RESULTS_ROOT="$ROOT/results"
LOGS_ROOT="$ROOT/single-run-logs"

###############################################################################
# Usage
###############################################################################

usage() {
    cat <<USAGE
Usage:
  $0 <application> <navigation> <page_similarity> <runs> [minutes]

Examples:
  $0 addressbook bfs general_paths 1 30
  $0 addressbook dfs general_paths 1 30
  $0 addressbook random_state general_paths 3 30
  $0 addressbook random_local general_paths 3 30

Arguments:
  application      Benchmark application name
  navigation       bfs | dfs | random_state | random_local
  page_similarity  e.g. general_paths, widgets, url_full
  runs             Number of executions
  minutes          Runtime per execution (default: 30)
USAGE
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

###############################################################################
# Arguments
###############################################################################

if [[ $# -lt 4 || $# -gt 5 ]]; then
    usage
    exit 2
fi

APP="$1"
NAV="$2"
PAGESIM="$3"
RUNS="$4"
MINUTES="${5:-30}"

if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]]; then
    fail "Runs must be a positive integer."
fi

if ! [[ "$MINUTES" =~ ^[1-9][0-9]*$ ]]; then
    fail "Minutes must be a positive integer."
fi

case "$NAV" in
    bfs|dfs|random_state|random_local)
        ;;
    *)
        fail "Unsupported navigation algorithm: $NAV"
        ;;
esac

###############################################################################
# Application URLs
###############################################################################

declare -A APP_URLS=(
    [addressbook]="http://web/addressbook-mod/addressbook/index.php"
    [drupal]="http://web/"
    [hotcrp]="http://web/index.php"
    [joomla]="http://web/"
    [owncloud]="http://web/"
    [phpbb2]="http://web/index.php"
    [prestashop]="http://web/"
    [scarf]="http://web/"
    [vanilla]="http://web/index.php"
    [wackopicko]="http://web/"
    [wordpress]="http://web/"
)

if [[ -z "${APP_URLS[$APP]+x}" ]]; then
    fail "Unknown application: $APP"
fi

URL="${APP_URLS[$APP]}"

###############################################################################
# Virtual environment
###############################################################################

VENV_DIR="$(cd "$ROOT/.." && pwd)/.venv"

if [[ -f "$VENV_DIR/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
else
    fail "Virtual environment not found: $VENV_DIR"
fi

###############################################################################
# Pre-flight checks
###############################################################################

command -v arachnarium >/dev/null 2>&1 || \
    fail "Arachnarium is not available."

command -v docker >/dev/null 2>&1 || \
    fail "Docker is not available."

docker info >/dev/null 2>&1 || \
    fail "Docker daemon is not accessible."

docker compose version >/dev/null 2>&1 || \
    fail "Docker Compose v2 is not available."

command -v zip >/dev/null 2>&1 || \
    fail "zip is not installed."

command -v unzip >/dev/null 2>&1 || \
    fail "unzip is not installed."

[[ -x "$ROOT/scripts/archive_results.sh" ]] || \
    fail "archive_results.sh is missing or not executable."

[[ -f "$ROOT/report_nohistory.py" ]] || \
    fail "report_nohistory.py was not found."

mkdir -p \
    "$EXPERIMENTS_ROOT" \
    "$REPORTS_ROOT" \
    "$RESULTS_ROOT" \
    "$LOGS_ROOT"

###############################################################################
# Destination / duplicate protection
###############################################################################

CONFIG_NAME="${NAV}_${PAGESIM}_${RUNS}runs"

DESTINATION="$RESULTS_ROOT/$APP/$CONFIG_NAME"
ZIP_FILE="$RESULTS_ROOT/$APP/${CONFIG_NAME}.zip"

if [[ -d "$DESTINATION" || -f "$ZIP_FILE" ]]; then
    fail "Results already exist for: $APP / $CONFIG_NAME"
fi

###############################################################################
# Working directory checks
###############################################################################

if [[ -d "$EXPERIMENTS_ROOT/$APP" ]]; then
    fail \
        "Existing working experiments found for $APP. " \
        "Archive or remove them before starting."
fi

if find "$REPORTS_ROOT" \
    -mindepth 1 \
    -maxdepth 1 \
    -print -quit 2>/dev/null | grep -q .; then

    fail "reports/ is not empty. Archive or clean it first."
fi

###############################################################################
# Logging
###############################################################################

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
RUN_LOG_DIR="$LOGS_ROOT/$APP/$CONFIG_NAME"
mkdir -p "$RUN_LOG_DIR"

echo
echo "============================================================"
echo "Starting experiment configuration"
echo "============================================================"
echo "Application:       $APP"
echo "Navigation:        $NAV"
echo "Page similarity:   $PAGESIM"
echo "Runs:              $RUNS"
echo "Runtime per run:   $MINUTES minutes"
echo "URL:               $URL"
echo "============================================================"

###############################################################################
# Interrupt handling
###############################################################################

CURRENT_CHILD=""

cleanup() {
    echo
    echo "Execution interrupted."

    if [[ -n "$CURRENT_CHILD" ]] && kill -0 "$CURRENT_CHILD" 2>/dev/null; then
        echo "Stopping Arachnarium process $CURRENT_CHILD..."

        kill -INT "$CURRENT_CHILD" 2>/dev/null || true
        wait "$CURRENT_CHILD" 2>/dev/null || true
    fi

    exit 130
}

trap cleanup INT TERM

###############################################################################
# Execute runs
###############################################################################

cd "$ROOT"

for ((RUN=1; RUN<=RUNS; RUN++)); do
    RUN_LOG="$RUN_LOG_DIR/run_${RUN}_${TIMESTAMP}.log"

    echo
    echo "------------------------------------------------------------"
    echo "Execution $RUN/$RUNS"
    echo "------------------------------------------------------------"

    echo "Command:"
    echo "arachnarium run crawlers/crawljax apps/$APP -t $MINUTES -a $PAGESIM --nav $NAV --app $APP --url $URL"
    echo

    arachnarium run \
        crawlers/crawljax \
        "apps/$APP" \
        -t "$MINUTES" \
        -a "$PAGESIM" \
        --nav "$NAV" \
        --app "$APP" \
        --url "$URL" \
        > >(tee "$RUN_LOG") \
        2> >(tee -a "$RUN_LOG" >&2) &

    CURRENT_CHILD=$!

    if wait "$CURRENT_CHILD"; then
        CURRENT_CHILD=""
        echo "Execution $RUN/$RUNS finished successfully."
    else
        STATUS=$?
        CURRENT_CHILD=""

        fail "Execution $RUN failed with exit code $STATUS."
    fi
done

###############################################################################
# Validate number of experiments
###############################################################################

EXPERIMENT_DIR="$EXPERIMENTS_ROOT/$APP/crawljax"

[[ -d "$EXPERIMENT_DIR" ]] || \
    fail "No experiment directory was created."

EXPERIMENT_COUNT="$(
    find "$EXPERIMENT_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        | wc -l
)"

if [[ "$EXPERIMENT_COUNT" -ne "$RUNS" ]]; then
    fail \
        "Expected $RUNS experiment directories, " \
        "but found $EXPERIMENT_COUNT."
fi

echo
echo "Verified $EXPERIMENT_COUNT experiment directories."

###############################################################################
# Validate raw output
###############################################################################

INVALID=0

while IFS= read -r EXP; do
    COVERAGE_COUNT=0

    if [[ -d "$EXP/coverage" ]]; then
        COVERAGE_COUNT="$(
            find "$EXP/coverage" -type f | wc -l
        )"
    fi

    if [[ "$COVERAGE_COUNT" -eq 0 ]]; then
        echo "INVALID: no coverage files in $EXP"
        ((INVALID+=1))
    fi

    if [[ ! -f "$EXP/report/web/crawl0/result.json" ]]; then
        echo "INVALID: missing result.json in $EXP"
        ((INVALID+=1))
    fi

    if [[ ! -f "$EXP/runtime.txt" ]]; then
        echo "INVALID: missing runtime.txt in $EXP"
        ((INVALID+=1))
    fi

    if [[ ! -f "$EXP/command.txt" ]]; then
        echo "INVALID: missing command.txt in $EXP"
        ((INVALID+=1))
    fi
done < <(
    find "$EXPERIMENT_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        | sort
)

if (( INVALID > 0 )); then
    fail "Experiment validation failed with $INVALID problem(s)."
fi

echo "Experiment output validation passed."

###############################################################################
# Generate report
###############################################################################

echo
echo "============================================================"
echo "Generating coverage report"
echo "============================================================"

rm -f "$ROOT/out_nohist.csv"

python "$ROOT/report_nohistory.py"

DESCRIPTIVE_REPORT="$REPORTS_ROOT/${APP}_${NAV}_${PAGESIM}_${RUNS}runs.csv"

if [[ -s "$ROOT/out_nohist.csv" ]]; then
    cp "$ROOT/out_nohist.csv" "$DESCRIPTIVE_REPORT"
elif [[ -s "$REPORTS_ROOT/out_nohist.csv" ]]; then
    cp \
        "$REPORTS_ROOT/out_nohist.csv" \
        "$DESCRIPTIVE_REPORT"
else
    fail "report_nohistory.py did not generate out_nohist.csv."
fi

echo "Report created:"
echo "  $DESCRIPTIVE_REPORT"

###############################################################################
# Archive
###############################################################################

echo
echo "============================================================"
echo "Archiving results"
echo "============================================================"

"$ROOT/scripts/archive_results.sh" \
    "$APP" \
    "$NAV" \
    "$PAGESIM" \
    "$RUNS" \
    "$MINUTES"

###############################################################################
# Final verification
###############################################################################

[[ -d "$DESTINATION" ]] || \
    fail "Archived result directory was not created."

[[ -s "$ZIP_FILE" ]] || \
    fail "ZIP archive was not created."

unzip -t "$ZIP_FILE" >/dev/null || \
    fail "ZIP archive integrity check failed."

echo
echo "============================================================"
echo "Experiment completed successfully"
echo "============================================================"
echo "Application:"
echo "  $APP"
echo
echo "Configuration:"
echo "  $NAV + $PAGESIM"
echo
echo "Executions:"
echo "  $RUNS"
echo
echo "Archived folder:"
echo "  $DESTINATION"
echo
echo "ZIP:"
echo "  $ZIP_FILE"
echo "============================================================"
