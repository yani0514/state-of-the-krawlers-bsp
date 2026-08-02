#!/usr/bin/env bash

set -u

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

    status=$?

    if [ "$status" -eq 0 ]; then
        echo "COMMAND FINISHED: $app"
    else
        echo "COMMAND FAILED: $app, exit code $status"
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
