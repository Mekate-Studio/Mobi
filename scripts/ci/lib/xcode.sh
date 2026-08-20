#!/usr/bin/env bash

ci_resolve_skip_macro_validation() {
  if [[ -n "${SKIP_MACRO_VALIDATION:-}" ]]; then
    printf '%s\n' "${SKIP_MACRO_VALIDATION}"
  elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf 'YES\n'
  else
    printf 'NO\n'
  fi
}

ci_resolve_ios_simulator_destination() {
  if [[ -n "${IOS_SIMULATOR_DESTINATION:-}" ]]; then
    printf '%s\n' "${IOS_SIMULATOR_DESTINATION}"
    return
  fi

  local simulator_id=""
  simulator_id="$(xcrun simctl list devices available --json | ruby -rjson -e '
    candidates = JSON.parse(STDIN.read).fetch("devices", {}).flat_map do |runtime, devices|
      devices.map { |device| [runtime, device] }
    end

    candidate = candidates
      .select { |runtime, device| runtime.include?(".iOS-") && device["isAvailable"] && device["name"].start_with?("iPhone") }
      .max_by { |runtime, device| [runtime.scan(/\d+/).map(&:to_i), device["name"]] }

    puts candidate.last.fetch("udid") if candidate
  ')"

  if [[ -z "${simulator_id}" ]]; then
    local runtime_id=""
    local device_type_id=""

    runtime_id="$(xcrun simctl list runtimes available --json | ruby -rjson -e '
      runtime = JSON.parse(STDIN.read).fetch("runtimes", [])
        .select { |entry| entry["isAvailable"] && entry.fetch("identifier", "").include?(".iOS-") }
        .max_by { |entry| entry.fetch("version", "0").scan(/\d+/).map(&:to_i) }

      puts runtime.fetch("identifier") if runtime
    ')"

    device_type_id="$(xcrun simctl list devicetypes --json | ruby -rjson -e '
      device_type = JSON.parse(STDIN.read).fetch("devicetypes", [])
        .find { |entry| entry.fetch("name", "").start_with?("iPhone") }

      puts device_type.fetch("identifier") if device_type
    ')"

    if [[ -z "${runtime_id}" || -z "${device_type_id}" ]]; then
      printf 'No available iOS runtime or iPhone simulator device type found.\n' >&2
      xcrun simctl list runtimes available >&2
      xcrun simctl list devicetypes >&2
      return 1
    fi

    printf 'Creating CI simulator with runtime=%s device_type=%s\n' "${runtime_id}" "${device_type_id}" >&2
    simulator_id="$(xcrun simctl create 'Mobi CI iPhone' "${device_type_id}" "${runtime_id}")"
  fi

  printf 'platform=iOS Simulator,id=%s\n' "${simulator_id}"
}
