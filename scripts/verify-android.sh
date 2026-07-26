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

java_major="$(java -version 2>&1 | awk -F '[".]' '/version/ { print $2; exit }')"
[[ "${java_major}" == "17" ]] || fail "JDK 17 is required; found Java ${java_major:-unknown}"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "${sdk_root}" ]] || fail "ANDROID_SDK_ROOT or ANDROID_HOME must point to the Android SDK"
[[ -d "${sdk_root}/platforms/android-37.0" ]] || {
  fail "Android SDK platform 37.0 is missing; install platforms;android-37.0"
}
[[ -d "${sdk_root}/build-tools/37.0.0" ]] || {
  fail "Android Build Tools 37.0.0 are missing; install build-tools;37.0.0"
}

printf '\n==> Android toolchain\n'
java -version
"${android_root}/gradlew" --version

printf '\n==> Android unit, lint, screenshot, app, and benchmark-build Gate\n'
"${android_root}/gradlew" \
  --no-daemon \
  --project-dir "${android_root}" \
  test \
  lint \
  :libraries:ui:validateDebugScreenshotTest \
  assembleDebug \
  assembleRelease \
  :apps:lengyan:assembleDebugAndroidTest \
  :apps:lengyan:assembleBenchmark \
  :benchmark:lengyan:assembleBenchmark

debug_apk="${android_root}/apps/lengyan/build/outputs/apk/debug/lengyan-debug.apk"
release_apk="${android_root}/apps/lengyan/build/outputs/apk/release/lengyan-release-unsigned.apk"
test_apk="${android_root}/apps/lengyan/build/outputs/apk/androidTest/debug/lengyan-debug-androidTest.apk"
benchmark_target_apk="${android_root}/apps/lengyan/build/outputs/apk/benchmark/lengyan-benchmark.apk"
benchmark_test_apk="${android_root}/benchmark/lengyan/build/outputs/apk/benchmark/lengyan-benchmark.apk"
screenshot_report="${android_root}/libraries/ui/build/test-results/validateDebugScreenshotTest/TEST-preview-screenshot-test-engine.xml"
[[ -s "${debug_apk}" ]] || fail "debug APK was not produced at ${debug_apk}"
[[ -s "${release_apk}" ]] || fail "release APK was not produced at ${release_apk}"
[[ -s "${test_apk}" ]] || fail "instrumentation APK was not produced at ${test_apk}"
[[ -s "${benchmark_target_apk}" ]] || fail "benchmark target APK was not produced at ${benchmark_target_apk}"
[[ -s "${benchmark_test_apk}" ]] || fail "macrobenchmark APK was not produced at ${benchmark_test_apk}"
[[ -s "${screenshot_report}" ]] || fail "screenshot report was not produced at ${screenshot_report}"

printf '\nAndroid verification passed.\n'
printf 'Debug APK: %s\n' "${debug_apk}"
printf 'Release APK: %s\n' "${release_apk}"
printf 'Instrumentation APK: %s\n' "${test_apk}"
printf 'Benchmark target APK: %s\n' "${benchmark_target_apk}"
printf 'Macrobenchmark APK: %s\n' "${benchmark_test_apk}"
printf 'Screenshot report: %s\n' "${screenshot_report}"
