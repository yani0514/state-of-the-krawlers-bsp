#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# Paths and defaults
###############################################################################

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXPERIMENTS_ROOT="$ROOT/experiments"
REPORTS_ROOT="$ROOT/reports"
RESULTS_ROOT="$ROOT/results"
LOGS_ROOT="$ROOT/campaign-logs"

MINUTES="${MINUTES:-30}"

CURRENT_CHILD=""
CAMPAIGN_STARTED="$(date '+%Y%m%d_%H%M%S')"
CAMPAIGN_LOG="$LOGS_ROOT/campaign_${CAMPAIGN_STARTED}.log"

###############################################################################
# Applications and starting URLs
###############################################################################

APPS=(
    addressbook
    drupal
    hotcrp
    joomla
    owncloud
    phpbb2
    prestashop
    scarf
    vanilla
    wackopicko
    wordpress
)

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

###############################################################################
# Confirmed experiment matrix
###############################################################################

CONFIGURATIONS=(
    "bfs general_paths 1"
    "dfs general_paths 1"
    "random_state general_paths 3"
    "random_local general_paths 3"
)

###############################################################################
# Helpers
###############################################################################

log() {
    local message="$*"

    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$message" \
        | tee -a "$CAMPAIGN_LOG"
}

section() {
    {
        echo
        echo "======================================================================"
        echo "$*"
        echo "======================================================================"
    } | tee -a "$CAMPAIGN_LOG"
}

fail() {
    log "ERROR: $*"
    exit 1
}

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1 || {
        fail "Required command is unavailable: $command_name"
    }
}

###############################################################################
# Signal handling
###############################################################################

stop_current_experiment() {
    if [[ -n "$CURRENT_CHILD" ]] &&
       kill -0 "$CURRENT_CHILD" 2>/dev/null; then

        log "Stopping current Arachnarium process: $CURRENT_CHILD"

        kill -INT "$CURRENT_CHILD" 2>/dev/null || true

        for _ in {1..30}; do
            if ! kill -0 "$CURRENT_CHILD" 2>/dev/null; then
                break
            fi

            sleep 1
        done

        if kill -0 "$CURRENT_CHILD" 2>/dev/null; then
            log "Process did not stop gracefully; sending SIGTERM."
            kill -TERM "$CURRENT_CHILD" 2>/dev/null || true
        fi

        wait "$CURRENT_CHILD" 2>/dev/null || true
    fi

    CURRENT_CHILD=""
}

handle_interrupt() {
    echo
    log "Campaign interrupted."
    stop_current_experiment
    exit 130
}

trap handle_interrupt INT TERM

###############################################################################
# Pre-flight checks
###############################################################################

preflight_checks() {
    section "Pre-flight checks"

    require_command arachnarium
    require_command python
    require_command zip
    require_command unzip
    require_command docker

    docker info >/dev/null 2>&1 || {
        fail "Docker exists, but the Docker daemon is not accessible."
    }

    docker compose version >/dev/null 2>&1 || {
        fail "Docker Compose v2 is unavailable."
    }

    [[ -f "$ROOT/report_nohistory.py" ]] || {
        fail "Missing report script: $ROOT/report_nohistory.py"
    }

    [[ -x "$ROOT/scripts/archive_results.sh" ]] || {
        fail "archive_results.sh is missing or not executable."
    }

    mkdir -p \
        "$EXPERIMENTS_ROOT" \
        "$REPORTS_ROOT" \
        "$RESULTS_ROOT" \
        "$LOGS_ROOT"

    log "Repository: $ROOT"
    log "Python:     $(python --version 2>&1)"
    log "Arachnarium: $(command -v arachnarium)"
    log "Docker:     $(docker --version)"
    log "Runtime:    $MINUTES minutes per execution"
}

###############################################################################
# Result state checks
###############################################################################

destination_folder() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetitions="$4"

    printf '%s/%s/%s_%s_%sruns' \
        "$RESULTS_ROOT" \
        "$app" \
        "$nav" \
        "$pagesim" \
        "$repetitions"
}

destination_zip() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetitions="$4"

    printf '%s/%s/%s_%s_%sruns.zip' \
        "$RESULTS_ROOT" \
        "$app" \
        "$nav" \
        "$pagesim" \
        "$repetitions"
}

configuration_is_archived() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetitions="$4"

    local folder
    local zip_file

    folder="$(
        destination_folder \
            "$app" "$nav" "$pagesim" "$repetitions"
    )"

    zip_file="$(
        destination_zip \
            "$app" "$nav" "$pagesim" "$repetitions"
    )"

    [[ -d "$folder" && -s "$zip_file" ]]
}

ensure_clean_working_area() {
    local app="$1"

    if [[ -d "$EXPERIMENTS_ROOT/$app" ]]; then
        fail \
            "Working experiments already exist for $app: " \
            "$EXPERIMENTS_ROOT/$app. Archive or remove them before continuing."
    fi

    if find "$REPORTS_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -print -quit 2>/dev/null \
        | grep -q .; then

        fail \
            "The reports directory is not empty. Archive or clean it before " \
            "starting another configuration."
    fi
}

###############################################################################
# Experiment execution
###############################################################################

run_single_experiment() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetition="$4"
    local total_repetitions="$5"

    local url="${APP_URLS[$app]}"
    local run_log_dir
    local run_log

    run_log_dir="$LOGS_ROOT/$app/${nav}_${pagesim}"
    run_log="$run_log_dir/run_${repetition}.log"

    mkdir -p "$run_log_dir"

    section \
        "$app | $nav + $pagesim | " \
        "execution $repetition/$total_repetitions"

    log "Application:      $app"
    log "Navigation:       $nav"
    log "Page similarity:  $pagesim"
    log "Runtime:          $MINUTES minutes"
    log "Starting URL:     $url"
    log "Execution:        $repetition/$total_repetitions"
    log "Execution log:    $run_log"

    cd "$ROOT"

    arachnarium run \
        crawlers/crawljax \
        "apps/$app" \
        -t "$MINUTES" \
        -a "$pagesim" \
        --nav "$nav" \
        --app "$app" \
        --url "$url" \
        > >(tee "$run_log") \
        2> >(tee -a "$run_log" >&2) &

    CURRENT_CHILD=$!

    if wait "$CURRENT_CHILD"; then
        CURRENT_CHILD=""

        log \
            "Execution completed: $app / $nav / $pagesim / " \
            "$repetition"
    else
        local status=$?
        CURRENT_CHILD=""

        log \
            "Execution failed: $app / $nav / $pagesim / " \
            "$repetition / exit code $status"

        return "$status"
    fi
}

###############################################################################
# Experiment verification
###############################################################################

verify_experiment_count() {
    local app="$1"
    local expected="$2"

    local experiment_root="$EXPERIMENTS_ROOT/$app/crawljax"
    local actual=0

    [[ -d "$experiment_root" ]] || {
        fail "No experiment directory was created for $app."
    }

    actual="$(
        find "$experiment_root" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            | wc -l
    )"

    if [[ "$actual" -ne "$expected" ]]; then
        fail \
            "Expected $expected experiment directories for $app, " \
            "but found $actual."
    fi

    log "Verified experiment count: $actual"
}

verify_experiment_files() {
    local app="$1"
    local experiment_root="$EXPERIMENTS_ROOT/$app/crawljax"

    local experiment=""
    local coverage_count=0
    local invalid=0

    while IFS= read -r experiment; do
        coverage_count=0

        if [[ -d "$experiment/coverage" ]]; then
            coverage_count="$(
                find "$experiment/coverage" \
                    -type f \
                    | wc -l
            )"
        fi

        if [[ "$coverage_count" -eq 0 ]]; then
            log "INVALID: no coverage files in $experiment"
            ((invalid += 1))
        fi

        if [[ ! -f "$experiment/report/web/crawl0/result.json" ]]; then
            log "INVALID: missing result.json in $experiment"
            ((invalid += 1))
        fi

        if [[ ! -f "$experiment/command.txt" ]]; then
            log "INVALID: missing command.txt in $experiment"
            ((invalid += 1))
        fi

        if [[ ! -f "$experiment/runtime.txt" ]]; then
            log "INVALID: missing runtime.txt in $experiment"
            ((invalid += 1))
        fi
    done < <(
        find "$experiment_root" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            | sort
    )

    if ((invalid > 0)); then
        fail \
            "Found $invalid validation problems for $app. " \
            "Results were not archived."
    fi

    log "Raw experiment files passed validation."
}

###############################################################################
# Report generation
###############################################################################

generate_configuration_report() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetitions="$4"

    local descriptive_report
    local general_report

    descriptive_report="$REPORTS_ROOT/${app}_${nav}_${pagesim}_${repetitions}runs.csv"
    general_report="$ROOT/out_nohist.csv"

    section "Generating report for $app / $nav + $pagesim"

    cd "$ROOT"

    rm -f "$general_report"

    python report_nohistory.py

    # Some versions write into the repository root.
    if [[ -s "$general_report" ]]; then
        cp "$general_report" "$descriptive_report"
    # Your current setup may write directly under reports/.
    elif [[ -s "$REPORTS_ROOT/out_nohist.csv" ]]; then
        cp \
            "$REPORTS_ROOT/out_nohist.csv" \
            "$descriptive_report"
    else
        fail \
            "report_nohistory.py did not generate out_nohist.csv."
    fi

    [[ -s "$descriptive_report" ]] || {
        fail "The descriptive CSV report was not created."
    }

    log "Report created: $descriptive_report"
}

###############################################################################
# Archive completed configuration
###############################################################################

archive_configuration() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetitions="$4"

    section "Archiving $app / $nav + $pagesim"

    "$ROOT/scripts/archive_results.sh" \
        "$app" \
        "$nav" \
        "$pagesim" \
        "$repetitions" \
        "$MINUTES"

    local zip_file

    zip_file="$(
        destination_zip \
            "$app" "$nav" "$pagesim" "$repetitions"
    )"

    [[ -s "$zip_file" ]] || {
        fail "Expected ZIP archive was not created: $zip_file"
    }

    unzip -t "$zip_file" >/dev/null || {
        fail "ZIP integrity check failed: $zip_file"
    }

    log "Archive verified: $zip_file"
}

###############################################################################
# One configuration for one application
###############################################################################

run_application_configuration() {
    local app="$1"
    local nav="$2"
    local pagesim="$3"
    local repetitions="$4"

    if configuration_is_archived \
        "$app" \
        "$nav" \
        "$pagesim" \
        "$repetitions"; then

        log \
            "SKIP: already archived: " \
            "$app / $nav + $pagesim / $repetitions runs"

        return 0
    fi

    ensure_clean_working_area "$app"

    local repetition

    for ((repetition = 1; repetition <= repetitions; repetition++)); do
        run_single_experiment \
            "$app" \
            "$nav" \
            "$pagesim" \
            "$repetition" \
            "$repetitions"
    done

    verify_experiment_count "$app" "$repetitions"
    verify_experiment_files "$app"

    generate_configuration_report \
        "$app" \
        "$nav" \
        "$pagesim" \
        "$repetitions"

    archive_configuration \
        "$app" \
        "$nav" \
        "$pagesim" \
        "$repetitions"
}

###############################################################################
# Campaign
###############################################################################

run_campaign() {
    section "Starting Arachnarium experiment campaign"

    log "Applications: ${#APPS[@]}"
    log "Configurations: ${#CONFIGURATIONS[@]}"
    log "Runtime per execution: $MINUTES minutes"

    local app=""
    local configuration=""
    local nav=""
    local pagesim=""
    local repetitions=""

    local completed=0
    local skipped=0

    for app in "${APPS[@]}"; do
        for configuration in "${CONFIGURATIONS[@]}"; do
            read -r nav pagesim repetitions <<< "$configuration"

            if configuration_is_archived \
                "$app" \
                "$nav" \
                "$pagesim" \
                "$repetitions"; then

                log \
                    "SKIP: $app / $nav + $pagesim / " \
                    "$repetitions runs"

                ((skipped += 1))
                continue
            fi

            run_application_configuration \
                "$app" \
                "$nav" \
                "$pagesim" \
                "$repetitions"

            ((completed += 1))
        done
    done

    section "Campaign summary"

    log "Completed configuration sets: $completed"
    log "Skipped existing sets:        $skipped"
    log "Results directory:            $RESULTS_ROOT"
    log "Campaign log:                 $CAMPAIGN_LOG"
}

###############################################################################
# Main
###############################################################################

main() {
    cd "$ROOT"

    mkdir -p "$LOGS_ROOT"
    touch "$CAMPAIGN_LOG"

    preflight_checks
    run_campaign

    section "Campaign finished successfully"
}

main "$@"
