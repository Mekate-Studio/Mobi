#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

report_dir="${project_root}/build/reports/shared-feature-home/android"
amper_home="${AMPER_USER_HOME:-${project_root}/build/amper-user-home}"
default_gradle_user_home="${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
amper_tmp_dir="${project_root}/build/tmp/amper"
command_log_path="${project_root}/build/logs/android-test-command.log"

print_test_summary() {
  local report_dir_path="${1:?report directory required}"

  python3 - "${report_dir_path}" <<'PY'
import glob
import os
import sys
import xml.etree.ElementTree as ET

report_dir = sys.argv[1]
xml_paths = sorted(glob.glob(os.path.join(report_dir, "TEST-*.xml")))

if not xml_paths:
    print("No JUnit XML reports were produced.")
    sys.exit(0)

suite_count = 0
test_count = 0
failure_count = 0
error_count = 0
skipped_count = 0
passed_count = 0
failures = []
executed_tests = []

def cleaned_output(node):
    if node is None or node.text is None:
        return []
    lines = []
    for raw_line in node.text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("unique-id: "):
            continue
        if line.startswith("display-name: "):
            continue
        lines.append(line)
    return lines

for xml_path in xml_paths:
    root = ET.parse(xml_path).getroot()
    suite_count += 1
    test_count += int(root.attrib.get("tests", "0"))
    failure_count += int(root.attrib.get("failures", "0"))
    error_count += int(root.attrib.get("errors", "0"))
    skipped_count += int(root.attrib.get("skipped", "0"))

    for testcase in root.findall("testcase"):
        classname = testcase.attrib.get("classname", "<unknown>")
        name = testcase.attrib.get("name", "<unknown>")
        label = f"{classname}.{name}"

        failure = testcase.find("failure")
        error = testcase.find("error")
        skipped = testcase.find("skipped")

        if failure is not None or error is not None:
            node = failure if failure is not None else error
            message = (node.attrib.get("message") or "").strip()
            details = (node.text or "").strip()
            if not message:
                message = details.splitlines()[0].strip() if details else "No failure message provided."
            executed_tests.append(("FAIL", label, testcase.attrib.get("time", "0"), cleaned_output(testcase.find("system-out"))))
            failures.append((label, message, details, testcase.attrib.get("time", "0")))
        elif skipped is not None:
            executed_tests.append(("SKIP", label, testcase.attrib.get("time", "0"), cleaned_output(testcase.find("system-out"))))
            continue
        else:
            passed_count += 1
            executed_tests.append(("PASS", label, testcase.attrib.get("time", "0"), cleaned_output(testcase.find("system-out"))))

print()
print("Android test summary")
print(f"  Suites:  {suite_count}")
print(f"  Tests:   {test_count}")
print(f"  Passed:  {passed_count}")
print(f"  Failed:  {failure_count}")
print(f"  Errors:  {error_count}")
print(f"  Skipped: {skipped_count}")
print(f"  Reports: {report_dir}")

if executed_tests:
    print()
    print("Test results")
    for status, label, duration, output_lines in executed_tests:
        print(f"  {status:<4} {label} ({duration}s)")
        for line in output_lines[:8]:
            print(f"       {line}")

if failures:
    print()
    print("Failures")
    for label, message, details, duration in failures:
      print(f"  FAIL {label} ({duration}s)")
      print(f"    {message}")
      if details:
          for line in details.splitlines()[:12]:
              if line.strip():
                  print(f"    {line}")
else:
    print()
    print("All reported tests passed.")
PY
}

find_latest_amper_log_dir() {
  find "${project_root}/build/logs" -maxdepth 1 -type d -name 'amper_*_test' -print 2>/dev/null | sort | tail -n 1
}

run_amper_test() {
  local gradle_home="${1:?gradle home required}"
  shift
  local attempt_log_path="${1:?attempt log path required}"
  shift

  (
    export GRADLE_USER_HOME="${gradle_home}"
    export HOME="${amper_home}"
    export TMPDIR="${amper_tmp_dir}"
    export AMPER_JAVA_OPTIONS="${AMPER_JAVA_OPTIONS:+${AMPER_JAVA_OPTIONS} }-Duser.home=${amper_home} -Djava.io.tmpdir=${amper_tmp_dir}"

    mkdir -p "${HOME}/Library/Caches/JetBrains/Amper/telemetry"

    cd "${project_root}"
    ./amper test -m shared-feature-home -p android "$@"
  ) >"${attempt_log_path}" 2>&1
}

command_log_mentions_missing_gradle_metadata() {
  local log_path="${1:?log path required}"

  rg -q 'Could not read workspace metadata from .*/metadata\.bin|metadata\.bin \(No such file or directory\)' "${log_path}"
}

latest_amper_logs_mention_missing_gradle_metadata() {
  local latest_amper_log_dir=""

  latest_amper_log_dir="$(find_latest_amper_log_dir || true)"
  [[ -n "${latest_amper_log_dir}" ]] || return 1

  rg -q 'Could not read workspace metadata from .*/metadata\.bin|metadata\.bin \(No such file or directory\)' \
    "${latest_amper_log_dir}/info.log" \
    "${latest_amper_log_dir}/debug.log"
}

prepare_clean_gradle_user_home() {
  local clean_gradle_home="${project_root}/build/gradle-user-home-clean"
  local generated_gradle_state=""

  rm -rf "${clean_gradle_home}"
  mkdir -p "${clean_gradle_home}"

  if [[ -d "${default_gradle_user_home}/wrapper" ]]; then
    mkdir -p "${clean_gradle_home}"
    cp -R "${default_gradle_user_home}/wrapper" "${clean_gradle_home}/wrapper"
  fi

  while IFS= read -r generated_gradle_state; do
    [[ -n "${generated_gradle_state}" ]] || continue
    rm -rf "${generated_gradle_state}"
  done < <(find "${project_root}/build/tasks" -path '*/gradle-project/.gradle' -type d 2>/dev/null | sort)

  printf '%s\n' "${clean_gradle_home}"
}

mkdir -p "${AMPER_BOOTSTRAP_CACHE_DIR}" "${amper_home}" "${default_gradle_user_home}" "${report_dir}" "${amper_tmp_dir}" "${project_root}/build/logs"
rm -f "${report_dir}"/TEST-*.xml
rm -f "${command_log_path}"

ci_set_java_home
ci_resolve_android_sdk_root || true
ci_configure_path
ci_log_android_sdk_env

echo "Running Android tests through Amper"
echo "Project root: ${project_root}"
echo "Amper cache:  ${AMPER_BOOTSTRAP_CACHE_DIR}"
echo "Amper home:   ${amper_home}"
echo "Gradle home:  ${default_gradle_user_home}"
echo "Command log:  ${command_log_path}"
echo "Verbose log:  set ANDROID_TEST_VERBOSE=1 to stream Amper output"

set +e
attempt1_log_path="${project_root}/build/logs/android-test-command.attempt1.log"
run_amper_test "${default_gradle_user_home}" "${attempt1_log_path}" "$@"
command_status=$?

if [[ "${command_status}" -ne 0 ]] && {
  command_log_mentions_missing_gradle_metadata "${attempt1_log_path}" || latest_amper_logs_mention_missing_gradle_metadata
}; then
  clean_gradle_user_home="$(prepare_clean_gradle_user_home)"
  echo "Detected stale Gradle transform metadata. Retrying once with a clean Gradle home..."
  echo "Clean Gradle: ${clean_gradle_user_home}"
  retry_log_path="${project_root}/build/logs/android-test-command.attempt2.log"
  run_amper_test "${clean_gradle_user_home}" "${retry_log_path}" "$@"
  retry_status=$?

  {
    cat "${attempt1_log_path}"
    printf '\n%s\n' "=== Retry with clean Gradle user home ==="
    printf '%s\n\n' "GRADLE_USER_HOME=${clean_gradle_user_home}"
    cat "${retry_log_path}"
  } >"${command_log_path}"

  command_status="${retry_status}"
else
  cp "${attempt1_log_path}" "${command_log_path}"
fi
set -e

if [[ "${ANDROID_TEST_VERBOSE:-0}" == "1" ]]; then
  cat "${command_log_path}"
fi

print_test_summary "${report_dir}"

latest_amper_log_dir="$(find_latest_amper_log_dir || true)"
if [[ -n "${latest_amper_log_dir}" ]]; then
  echo
  echo "Amper logs"
  echo "  - ${latest_amper_log_dir}/info.log"
  echo "  - ${latest_amper_log_dir}/debug.log"
fi

if [[ "${command_status}" -ne 0 ]]; then
  echo
  echo "Recent command output"
  tail -n 80 "${command_log_path}" || true
fi

exit "${command_status}"
