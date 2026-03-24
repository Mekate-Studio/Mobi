#!/usr/bin/env sh

set -eu

if [ "$#" -eq 0 ]; then
  echo "Usage: run_amper_with_logs.sh <amper args...>" >&2
  exit 1
fi

if ./amper "$@"; then
  exit 0
fi

echo
echo "amper failed; printing recent Amper/Xcode logs if present..."

if [ -d build/logs ]; then
  find build/logs -type f \( -name "*.stderr" -o -name "*.stdout" -o -name "*.log" \) -print | sort | tail -n 10 | while IFS= read -r log_file; do
    echo
    echo "===== ${log_file} ====="
    tail -n 200 "$log_file" || true
  done
fi

find build/tasks -type f \( -name "xcodebuild.log" -o -name "*.log" \) -print | sort | tail -n 10 | while IFS= read -r log_file; do
  echo
  echo "===== ${log_file} ====="
  tail -n 200 "$log_file" || true
done

exit 1
