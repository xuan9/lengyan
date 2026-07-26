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
  :apps:lengyan:compactPhoneApi35DebugAndroidTest

report="${android_root}/apps/lengyan/build/reports/androidTests/managedDevice/debug/compactPhoneApi35/index.html"
[[ -s "${report}" ]] || fail "managed-device report was not produced at ${report}"

printf '\nAndroid managed-device verification passed.\n'
printf 'Report: %s\n' "${report}"
