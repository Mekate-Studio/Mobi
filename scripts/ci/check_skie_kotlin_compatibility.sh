#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"
catalog_path="${project_root}/gradle/libs.versions.toml"
bridge_dir="${project_root}/gradle-bridge"

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${project_root}/.gradle-user-home}"

target_kotlin_version="${SKIE_COMPAT_KOTLIN_VERSION:-2.4.0}"
target_metro_version="${SKIE_COMPAT_METRO_VERSION:-1.2.1}"
target_skie_version="${SKIE_COMPAT_SKIE_VERSION:-}"
gradle_task="${SKIE_COMPAT_GRADLE_TASK:-:shared-kit:compileKotlinIosSimulatorArm64}"
alert_on_compatible="${SKIE_COMPAT_ALERT_ON_COMPATIBLE:-0}"
skie_metadata_url="${SKIE_COMPAT_MAVEN_METADATA_URL:-https://plugins.gradle.org/m2/co/touchlab/skie/co.touchlab.skie.gradle.plugin/maven-metadata.xml}"

if [[ -z "${target_skie_version}" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to look up the latest SKIE Gradle plugin version." >&2
    exit 127
  fi

  # Ruby owns the interpolation in this one-liner; keep the shell out of it.
  # shellcheck disable=SC2016
  target_skie_version="$(
    curl -fsSL "${skie_metadata_url}" |
      ruby -rrexml/document -e '
        doc = REXML::Document.new($stdin.read)
        release = doc.elements["metadata/versioning/release"]&.text
        latest = doc.elements["metadata/versioning/latest"]&.text
        versions = []
        doc.elements.each("metadata/versioning/versions/version") { |node| versions << node.text }
        puts(release || latest || versions.last)
      '
  )"
fi

if [[ -z "${target_skie_version}" ]]; then
  echo "Unable to determine a SKIE version to test." >&2
  exit 1
fi

backup_path="$(mktemp "${TMPDIR:-/tmp}/mobi-libs.versions.toml.XXXXXX")"
cp "${catalog_path}" "${backup_path}"

restore_catalog() {
  cp "${backup_path}" "${catalog_path}"
  rm -f "${backup_path}"
}
trap restore_catalog EXIT

ruby - "${catalog_path}" "${target_kotlin_version}" "${target_metro_version}" "${target_skie_version}" <<'RUBY'
path, kotlin, metro, skie = ARGV
content = File.read(path)
replacements = {
  /^kotlin = ".*"$/ => %(kotlin = "#{kotlin}"),
  /^metro = ".*"$/ => %(metro = "#{metro}"),
  /^skie = ".*"$/ => %(skie = "#{skie}")
}

replacements.each do |pattern, replacement|
  unless content.match?(pattern)
    warn "Missing expected version catalog line matching #{pattern.inspect}"
    exit 1
  end
  content = content.gsub(pattern, replacement)
end

File.write(path, content)
RUBY

cat <<EOF
Checking Gradle bridge compatibility with:
  Kotlin: ${target_kotlin_version}
  Metro:  ${target_metro_version}
  SKIE:   ${target_skie_version}
  Task:   ${gradle_task}
EOF

set +e
(
  cd "${bridge_dir}"
  ./gradlew --no-daemon "${gradle_task}"
)
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  cat <<EOF
SKIE compatibility check passed.

The bridge can compile with Kotlin ${target_kotlin_version}, Metro ${target_metro_version},
and SKIE ${target_skie_version}. Remove the Renovate ceilings that hold Kotlin
below 2.4 and Metro below 1.2, then let Renovate open the coordinated update.
EOF

  if [[ "${alert_on_compatible}" == "1" ]]; then
    exit 2
  fi
  exit 0
fi

cat <<EOF
SKIE compatibility check did not pass yet.

Keep the Renovate ceilings in place until this task compiles successfully with
the latest SKIE release.
EOF
