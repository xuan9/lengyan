#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_root="${repo_root}/android"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v java >/dev/null 2>&1 || fail "required command not found: java"

java_major="$(java -version 2>&1 | awk -F '[\".]' '/version/ { print $2; exit }')"
[[ "${java_major}" == "17" ]] || fail "JDK 17 is required; found Java ${java_major:-unknown}"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "${sdk_root}" ]] || fail "ANDROID_SDK_ROOT or ANDROID_HOME must point to the Android SDK"
[[ -x "${sdk_root}/emulator/emulator" ]] || fail "Android Emulator is missing from ${sdk_root}"

printf '\n==> Android managed-device UI smoke Gate\n'
"${android_root}/gradlew" \
  --no-daemon \
  --project-dir "${android_root}" \
  :libraries:data:compactPhoneApi35DebugAndroidTest \
  :libraries:ui:compactPhoneApi35DebugAndroidTest \
  :apps:lengyan:compactPhoneApi35DebugAndroidTest

printf '\n==> Android tablet split-detail Gate\n'
"${android_root}/gradlew" \
  --no-daemon \
  --project-dir "${android_root}" \
  :apps:lengyan:tabletApi35DebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=org.fuxuan.lengyan.LengyanTabletFavoritesTest

data_report="${android_root}/libraries/data/build/reports/androidTests/managedDevice/debug/compactPhoneApi35/index.html"
ui_report="${android_root}/libraries/ui/build/reports/androidTests/managedDevice/debug/compactPhoneApi35/index.html"
app_report="${android_root}/apps/lengyan/build/reports/androidTests/managedDevice/debug/compactPhoneApi35/index.html"
tablet_report="${android_root}/apps/lengyan/build/reports/androidTests/managedDevice/debug/tabletApi35/index.html"
[[ -s "${data_report}" ]] || fail "managed-device report was not produced at ${data_report}"
[[ -s "${ui_report}" ]] || fail "managed-device report was not produced at ${ui_report}"
[[ -s "${app_report}" ]] || fail "managed-device report was not produced at ${app_report}"
[[ -s "${tablet_report}" ]] || fail "managed-device report was not produced at ${tablet_report}"

printf '\nAndroid managed-device verification passed.\n'
printf 'Data report: %s\n' "${data_report}"
printf 'UI report: %s\n' "${ui_report}"
printf 'App report: %s\n' "${app_report}"
printf 'Tablet report: %s\n' "${tablet_report}"
