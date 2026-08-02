#!/usr/bin/env bash

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

apps=(
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

passed=()
failed=()

for app in "${apps[@]}"; do
  echo
  echo "=================================================="
  echo "Building: $app"
  echo "=================================================="

  if "$ROOT/scripts/build_app.sh" "$app"; then
    echo "BUILD PASSED: $app"
    passed+=("$app")
  else
    echo "BUILD FAILED: $app"
    failed+=("$app")
  fi
done

echo
echo "================ BUILD SUMMARY ================"

for app in "${passed[@]}"; do
  echo "BUILD PASSED: $app"
done

for app in "${failed[@]}"; do
  echo "BUILD FAILED: $app"
done

echo
echo "Passed: ${#passed[@]}"
echo "Failed: ${#failed[@]}"

if ((${#failed[@]} > 0)); then
  exit 1
fi
