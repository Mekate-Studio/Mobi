#!/usr/bin/env sh

set -eu

lane="${1:?Usage: run_fastlane_with_amper_logs.sh <lane>}"
shift || true

if bundle exec fastlane "$lane" "$@"; then
  exit 0
fi

echo
echo "fastlane failed; printing recent Amper/Gradle logs if present..."

if [ -d build/logs ]; then
  find build/logs -type f \( -name "*.stderr" -o -name "*.stdout" -o -name "*.log" \) -print | sort | tail -n 10 | while IFS= read -r log_file; do
    echo
    echo "===== ${log_file} ====="
    if grep -E -n "Caused by:|^\\* What went wrong:|^FAILURE: Build failed|Exception|Error" "$log_file" >/tmp/amper-log-grep.txt 2>/dev/null; then
      echo "--- matching error lines ---"
      cat /tmp/amper-log-grep.txt
      echo "--- end matching error lines ---"
    fi
    tail -n 200 "$log_file" || true
  done
else
  echo "No build/logs directory found."
fi

exit 1
