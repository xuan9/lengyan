#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_root="${repo_root}/android"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_command java
require_command adb

java_major="$(java -version 2>&1 | awk -F '[\".]' '/version/ { print $2; exit }')"
[[ "${java_major}" == "17" ]] || fail "JDK 17 is required; found Java ${java_major:-unknown}"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "${sdk_root}" ]] || fail "ANDROID_SDK_ROOT or ANDROID_HOME must point to the Android SDK"

adb start-server >/dev/null

connected_serials=()
while IFS= read -r serial; do
  [[ -n "${serial}" ]] && connected_serials+=("${serial}")
done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')

requested_serial="${ANDROID_BENCHMARK_SERIAL:-}"
if [[ -n "${requested_serial}" ]]; then
  selected_serial=""
  for serial in "${connected_serials[@]-}"; do
    [[ -n "${serial}" ]] || continue
    if [[ "${serial}" == "${requested_serial}" ]]; then
      selected_serial="${serial}"
      break
    fi
  done
  [[ -n "${selected_serial}" ]] || fail "ANDROID_BENCHMARK_SERIAL=${requested_serial} is not an authorized connected device"
else
  physical_serials=()
  for serial in "${connected_serials[@]-}"; do
    [[ -n "${serial}" ]] || continue
    is_emulator="$(adb -s "${serial}" shell getprop ro.kernel.qemu | tr -d '\r')"
    [[ "${is_emulator}" == "1" ]] || physical_serials+=("${serial}")
  done
  [[ "${#physical_serials[@]}" -gt 0 ]] || fail "no physical Android device is connected; emulator measurements are not accepted"
  [[ "${#physical_serials[@]}" -eq 1 ]] || {
    fail "multiple physical devices are connected; set ANDROID_BENCHMARK_SERIAL to select one"
  }
  selected_serial="${physical_serials[0]}"
fi

is_emulator="$(adb -s "${selected_serial}" shell getprop ro.kernel.qemu | tr -d '\r')"
[[ "${is_emulator}" != "1" ]] || fail "${selected_serial} is an emulator; use an Android 12+ physical reference device"

api_level="$(adb -s "${selected_serial}" shell getprop ro.build.version.sdk | tr -d '\r')"
[[ "${api_level}" =~ ^[0-9]+$ ]] || fail "could not read Android API level from ${selected_serial}"
[[ "${api_level}" -ge 31 ]] || fail "Android 12 / API 31+ is required; ${selected_serial} is API ${api_level}"

device_name="$(adb -s "${selected_serial}" shell getprop ro.product.model | tr -d '\r')"
font_scale="$(adb -s "${selected_serial}" shell settings get system font_scale | tr -d '\r')"
case "${font_scale}" in
  ""|null|1|1.0|1.00) ;;
  *) fail "default system font scale is required; ${selected_serial} uses ${font_scale}" ;;
esac
printf '\n==> Lengyan long-reader Macrobenchmark\n'
printf 'Device: %s (%s), API %s, font scale %s\n' \
  "${device_name:-unknown}" "${selected_serial}" "${api_level}" "${font_scale:-default}"

ANDROID_SERIAL="${selected_serial}" "${android_root}/gradlew" \
  --no-daemon \
  --project-dir "${android_root}" \
  :benchmark:lengyan:connectedBenchmarkAndroidTest

report="${android_root}/benchmark/lengyan/build/reports/androidTests/connected/benchmark/index.html"
result_json="$(find "${android_root}/benchmark/lengyan/build/outputs" -type f -name '*benchmarkData.json' -print -quit 2>/dev/null || true)"
[[ -s "${report}" ]] || fail "benchmark report was not produced at ${report}"
[[ -n "${result_json}" && -s "${result_json}" ]] || fail "benchmark JSON was not produced"

printf '\nAndroid physical-device benchmark passed.\n'
printf 'HTML report: %s\n' "${report}"
printf 'Benchmark JSON: %s\n' "${result_json}"
