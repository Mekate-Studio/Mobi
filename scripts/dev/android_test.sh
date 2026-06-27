#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/common.sh"

modules=(
  "shared-feature-home"
  "android-app"
)
kotlin_cli_user_home="${KOTLIN_CLI_USER_HOME:-${project_root}/build/kotlin-user-home}"
default_gradle_user_home="${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"
kotlin_cli_tmp_dir="${project_root}/build/tmp/kotlin"
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

find_latest_kotlin_log_dir() {
  find "${project_root}/build/logs" -maxdepth 1 -type d -name 'kotlin_*_test' -print 2>/dev/null | sort | tail -n 1
}

run_kotlin_test() {
  local gradle_home="${1:?gradle home required}"
  shift
  local module_name="${1:?module name required}"
  shift
  local attempt_log_path="${1:?attempt log path required}"
  shift

  (
    export GRADLE_USER_HOME="${gradle_home}"
    export HOME="${kotlin_cli_user_home}"
    export TMPDIR="${kotlin_cli_tmp_dir}"
    export KOTLIN_CLI_USER_HOME="${kotlin_cli_user_home}"
    export KOTLIN_CLI_TMP_DIR="${kotlin_cli_tmp_dir}"
    export KOTLIN_CLI_JAVA_OPTIONS="${KOTLIN_CLI_JAVA_OPTIONS:+${KOTLIN_CLI_JAVA_OPTIONS} }-Duser.home=${kotlin_cli_user_home} -Djava.io.tmpdir=${kotlin_cli_tmp_dir}"
    export KOTLIN_CLI_NO_WELCOME_BANNER="${KOTLIN_CLI_NO_WELCOME_BANNER:-1}"

    mkdir -p "${HOME}/Library/Caches/JetBrains/Kotlin/telemetry"

    cd "${project_root}"
    ./kotlin test -m "${module_name}" -p android "$@"
  ) >"${attempt_log_path}" 2>&1
}

command_log_mentions_missing_gradle_metadata() {
  local log_path="${1:?log path required}"

  rg -q 'Could not read workspace metadata from .*/metadata\.bin|metadata\.bin \(No such file or directory\)' "${log_path}"
}

latest_kotlin_logs_mention_missing_gradle_metadata() {
  local latest_kotlin_log_dir=""

  latest_kotlin_log_dir="$(find_latest_kotlin_log_dir || true)"
  [[ -n "${latest_kotlin_log_dir}" ]] || return 1

  rg -q 'Could not read workspace metadata from .*/metadata\.bin|metadata\.bin \(No such file or directory\)' \
    "${latest_kotlin_log_dir}/info.log" \
    "${latest_kotlin_log_dir}/debug.log"
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

mkdir -p "${KOTLIN_CLI_BOOTSTRAP_CACHE_DIR}" "${kotlin_cli_user_home}" "${default_gradle_user_home}" "${kotlin_cli_tmp_dir}" "${project_root}/build/logs"
for module_name in "${modules[@]}"; do
  report_dir="${project_root}/build/reports/${module_name}/android"
  mkdir -p "${report_dir}"
  rm -f "${report_dir}"/TEST-*.xml
done
rm -f "${command_log_path}"

ci_set_java_home
ci_resolve_android_sdk_root || true
ci_configure_path
ci_log_android_sdk_env

echo "Running Android tests through Kotlin Toolchain"
echo "Project root: ${project_root}"
echo "Kotlin cache: ${KOTLIN_CLI_BOOTSTRAP_CACHE_DIR}"
echo "Kotlin home:  ${kotlin_cli_user_home}"
echo "Gradle home:  ${default_gradle_user_home}"
echo "Modules:      ${modules[*]}"
echo "Command log:  ${command_log_path}"
echo "Verbose log:  set ANDROID_TEST_VERBOSE=1 to stream Kotlin Toolchain output"

overall_status=0

for module_name in "${modules[@]}"; do
  module_log_path="${project_root}/build/logs/android-test-command-${module_name}.log"

  set +e
  attempt1_log_path="${project_root}/build/logs/android-test-command-${module_name}.attempt1.log"
  run_kotlin_test "${default_gradle_user_home}" "${module_name}" "${attempt1_log_path}" "$@"
  command_status=$?

  if [[ "${command_status}" -ne 0 ]] && {
    command_log_mentions_missing_gradle_metadata "${attempt1_log_path}" || latest_kotlin_logs_mention_missing_gradle_metadata
  }; then
    clean_gradle_user_home="$(prepare_clean_gradle_user_home)"
    echo "Detected stale Gradle transform metadata while testing ${module_name}. Retrying once with a clean Gradle home..."
    echo "Clean Gradle: ${clean_gradle_user_home}"
    retry_log_path="${project_root}/build/logs/android-test-command-${module_name}.attempt2.log"
    run_kotlin_test "${clean_gradle_user_home}" "${module_name}" "${retry_log_path}" "$@"
    retry_status=$?

    {
      cat "${attempt1_log_path}"
      printf '\n%s\n' "=== Retry with clean Gradle user home ==="
      printf '%s\n\n' "GRADLE_USER_HOME=${clean_gradle_user_home}"
      cat "${retry_log_path}"
    } >"${module_log_path}"

    command_status="${retry_status}"
  else
    cp "${attempt1_log_path}" "${module_log_path}"
  fi
  set -e

  {
    printf '\n%s\n' "=== Module: ${module_name} ==="
    cat "${module_log_path}"
  } >>"${command_log_path}"

  report_dir="${project_root}/build/reports/${module_name}/android"
  print_test_summary "${report_dir}"

  latest_kotlin_log_dir="$(find_latest_kotlin_log_dir || true)"
  if [[ -n "${latest_kotlin_log_dir}" ]]; then
    echo
    echo "Kotlin Toolchain logs for ${module_name}"
    echo "  - ${latest_kotlin_log_dir}/info.log"
    echo "  - ${latest_kotlin_log_dir}/debug.log"
  fi

  if [[ "${command_status}" -ne 0 ]]; then
    overall_status="${command_status}"
    echo
    echo "Recent command output for ${module_name}"
    tail -n 80 "${module_log_path}" || true
  fi
done

if [[ "${ANDROID_TEST_VERBOSE:-0}" == "1" ]]; then
  cat "${command_log_path}"
fi

exit "${overall_status}"
