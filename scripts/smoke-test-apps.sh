#!/usr/bin/env bash

set -u

PASSED=0
FAILED=0

cleanup() {
    echo
    echo "======================================"
    echo "Smoke test interrupted."
    echo "Stopping..."
    echo "======================================"

    pkill -f arachnarium >/dev/null 2>&1 || true
    exit 130
}

trap cleanup SIGINT SIGTERM

run_test() {
    local app="$1"
    local url="$2"

    echo
    echo "=================================================="
    echo "Testing $app"
    echo "URL: $url"
    echo "=================================================="

    arachnarium run \
        crawlers/crawljax \
        "apps/$app" \
        -t 1 \
        -a general_paths \
        --nav bfs \
        --app "$app" \
        --url "$url"

    local status=$?

    if [ "$status" -eq 0 ]; then
        echo "PASS: $app"
        ((PASSED++))
    else
        echo "FAIL: $app (exit code $status)"
        ((FAILED++))
    fi
}

run_test addressbook "http://web/addressbook-mod/addressbook/index.php"
run_test drupal      "http://web/"
run_test joomla      "http://web/"
run_test owncloud    "http://web/"
run_test phpbb2      "http://web/index.php"
run_test prestashop  "http://web/"
run_test scarf       "http://web/"
run_test vanilla     "http://web/index.php"
run_test wackopicko  "http://web/"
run_test wordpress   "http://web/"

echo
echo "======================================"
echo "Smoke test finished"
echo "======================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
    echo "All applications started successfully."
else
    echo "Some applications failed."
fi