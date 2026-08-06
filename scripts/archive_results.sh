#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# Paths
###############################################################################

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXPERIMENTS_ROOT="$ROOT/experiments"
REPORTS_ROOT="$ROOT/reports"
RESULTS_ROOT="$ROOT/results"

###############################################################################
# Helpers
###############################################################################

usage() {
    cat <<USAGE
Usage:
  $0 <application> <navigation> <page_similarity> <runs> [runtime_minutes]

Examples:
  $0 hotcrp random_local widgets 3 30
  $0 drupal bfs general_paths 1 30
  $0 wordpress random_state general_paths 3 30

The script performs these steps:

  1. Creates:
       results/<application>/<navigation>_<page_similarity>_<runs>runs/

  2. Moves:
       experiments/<application>/

     into:
       results/<application>/<configuration>/experiments/<application>/

  3. Copies the current contents of reports/

  4. Creates README.txt

  5. Creates:
       results/<application>/<configuration>.zip

  6. Cleans the working reports/ directory
USAGE
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
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
RUNTIME_MINUTES="${5:-unknown}"

case "$NAV" in
    bfs|dfs|random_state|random_local)
        ;;
    *)
        fail "Unsupported navigation algorithm: $NAV"
        ;;
esac

if ! is_positive_integer "$RUNS"; then
    fail "Runs must be a positive integer."
fi

if [[ "$RUNTIME_MINUTES" != "unknown" ]] &&
   ! is_positive_integer "$RUNTIME_MINUTES"; then
    fail "Runtime must be a positive integer."
fi

###############################################################################
# Destination
###############################################################################

CONFIG_NAME="${NAV}_${PAGESIM}_${RUNS}runs"

DESTINATION="$RESULTS_ROOT/$APP/$CONFIG_NAME"
DEST_EXPERIMENTS="$DESTINATION/experiments"
DEST_REPORTS="$DESTINATION/reports"

ZIP_FILE="$RESULTS_ROOT/$APP/${CONFIG_NAME}.zip"

SOURCE_EXPERIMENT="$EXPERIMENTS_ROOT/$APP"

###############################################################################
# Validation
###############################################################################

[[ -d "$SOURCE_EXPERIMENT" ]] || {
    fail "Experiment directory does not exist: $SOURCE_EXPERIMENT"
}

[[ -d "$SOURCE_EXPERIMENT/crawljax" ]] || {
    fail "Crawljax directory does not exist: $SOURCE_EXPERIMENT/crawljax"
}

EXPERIMENT_COUNT="$(
    find "$SOURCE_EXPERIMENT/crawljax" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        | wc -l
)"

if [[ "$EXPERIMENT_COUNT" -ne "$RUNS" ]]; then
    cat >&2 <<MESSAGE
ERROR: Expected $RUNS experiment directories for $APP, but found $EXPERIMENT_COUNT.

Directory:
  $SOURCE_EXPERIMENT/crawljax

Check the directory before archiving:
  find "$SOURCE_EXPERIMENT/crawljax" \
    -mindepth 1 -maxdepth 1 -type d
MESSAGE
    exit 1
fi

if [[ -e "$DESTINATION" ]]; then
    fail "Destination already exists: $DESTINATION"
fi

if [[ -e "$ZIP_FILE" ]]; then
    fail "ZIP file already exists: $ZIP_FILE"
fi

command -v zip >/dev/null 2>&1 || {
    fail "The 'zip' command is not installed."
}

###############################################################################
# Summary before modifying anything
###############################################################################

echo
echo "============================================================"
echo "Archiving experiment results"
echo "============================================================"
echo "Application:       $APP"
echo "Navigation:        $NAV"
echo "Page similarity:   $PAGESIM"
echo "Runs:              $RUNS"
echo "Runtime:           $RUNTIME_MINUTES minutes"
echo "Experiments found: $EXPERIMENT_COUNT"
echo
echo "Source:"
echo "  $SOURCE_EXPERIMENT"
echo
echo "Destination:"
echo "  $DESTINATION"
echo
echo "ZIP:"
echo "  $ZIP_FILE"
echo "============================================================"
echo

###############################################################################
# Create archive structure
###############################################################################

mkdir -p \
    "$DEST_EXPERIMENTS" \
    "$DEST_REPORTS"

###############################################################################
# Move experiments
###############################################################################

echo "Moving experiment data..."

mv "$SOURCE_EXPERIMENT" "$DEST_EXPERIMENTS/"

###############################################################################
# Copy reports
###############################################################################

echo "Copying reports..."

if [[ -d "$REPORTS_ROOT" ]] &&
   find "$REPORTS_ROOT" -mindepth 1 -maxdepth 1 | grep -q .; then

    cp -a "$REPORTS_ROOT"/. "$DEST_REPORTS/"
else
    echo "WARNING: reports/ is empty or does not exist."
fi

###############################################################################
# Create experiment manifest
###############################################################################

MANIFEST="$DESTINATION/experiments.txt"

{
    echo "Experiment IDs"
    echo "=============="
    echo

    find "$DEST_EXPERIMENTS/$APP/crawljax" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' \
        | sort
} > "$MANIFEST"

###############################################################################
# Capture commands and runtimes
###############################################################################

DETAILS="$DESTINATION/run_details.txt"

{
    echo "Run details"
    echo "==========="
    echo

    while IFS= read -r experiment; do
        experiment_id="$(basename "$experiment")"

        echo "Experiment: $experiment_id"

        if [[ -f "$experiment/command.txt" ]]; then
            printf 'Command: '
            cat "$experiment/command.txt"
            echo
        else
            echo "Command: unavailable"
        fi

        if [[ -f "$experiment/runtime.txt" ]]; then
            printf 'Runtime seconds: '
            cat "$experiment/runtime.txt"
            echo
        else
            echo "Runtime seconds: unavailable"
        fi

        echo
    done < <(
        find "$DEST_EXPERIMENTS/$APP/crawljax" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            | sort
    )
} > "$DETAILS"

###############################################################################
# Create README
###############################################################################

ARCHIVE_DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOSTNAME_VALUE="$(hostname)"
GIT_BRANCH="unknown"
GIT_COMMIT="unknown"

if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_BRANCH="$(git -C "$ROOT" branch --show-current)"
    GIT_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
fi

cat > "$DESTINATION/README.txt" <<README
Arachnarium Experiment Results
==============================

Application
-----------
$APP

Configuration
-------------
Navigation algorithm: $NAV
Page similarity algorithm: $PAGESIM
Number of executions: $RUNS
Configured runtime per execution: $RUNTIME_MINUTES minutes

Archive information
-------------------
Archive created: $ARCHIVE_DATE
Created on host: $HOSTNAME_VALUE
Git branch: $GIT_BRANCH
Git commit: $GIT_COMMIT

Directory contents
------------------
experiments/
    Raw Arachnarium experiment directories.

    Each experiment may contain:
    - raw coverage files;
    - Crawljax reports;
    - screenshots;
    - DOM and state data;
    - command.txt;
    - runtime.txt;
    - stdout.txt;
    - stderr.txt.

reports/
    CSV reports and other generated report files copied from the working
    reports directory.

experiments.txt
    List of archived experiment IDs.

run_details.txt
    Recorded command and runtime information for each execution.

Important
---------
The raw coverage directories are included, not only the generated CSV report.
README

###############################################################################
# Create ZIP
###############################################################################

echo "Creating ZIP archive..."

mkdir -p "$(dirname "$ZIP_FILE")"

(
    cd "$(dirname "$DESTINATION")"
    zip -9 -r "$ZIP_FILE" "$(basename "$DESTINATION")"
)

###############################################################################
# Verify ZIP
###############################################################################

if [[ ! -s "$ZIP_FILE" ]]; then
    fail "The ZIP archive was not created correctly."
fi

if ! unzip -t "$ZIP_FILE" >/dev/null; then
    fail "ZIP integrity verification failed."
fi

###############################################################################
# Clean working directories
###############################################################################

echo "Cleaning working directories..."

# experiments/<app> was moved already. Remove empty parent directories only.
find "$EXPERIMENTS_ROOT" \
    -mindepth 1 \
    -type d \
    -empty \
    -delete 2>/dev/null || true

# Remove current report files while preserving reports/ itself.
if [[ -d "$REPORTS_ROOT" ]]; then
    find "$REPORTS_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf -- {} +
else
    mkdir -p "$REPORTS_ROOT"
fi

###############################################################################
# Final summary
###############################################################################

echo
echo "============================================================"
echo "Archive completed successfully"
echo "============================================================"
echo "Folder:"
echo "  $DESTINATION"
echo
echo "ZIP:"
echo "  $ZIP_FILE"
echo
echo "ZIP size:"
du -sh "$ZIP_FILE"
echo
echo "Working experiment directory:"
if [[ -d "$EXPERIMENTS_ROOT" ]]; then
    find "$EXPERIMENTS_ROOT" \
        -mindepth 1 \
        -maxdepth 3 \
        -type d \
        | sort
fi
echo
echo "Working reports directory:"
find "$REPORTS_ROOT" \
    -mindepth 1 \
    -maxdepth 1 \
    -print 2>/dev/null || true
echo "============================================================"
