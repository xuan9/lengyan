#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="${VERIFY_BUILD_DIR:-${repo_root}/build/verify}"
derived_data="${IOS_DERIVED_DATA_PATH:-${build_root}/DerivedData}"
archive_path="${IOS_ARCHIVE_PATH:-${build_root}/lengyan.xcarchive}"

log() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_node() {
  require_command node
  require_command npm
  local node_major
  node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
  [[ "${node_major}" -ge 22 ]] || fail "Node 22+ is required; found $(node --version)"
  log "Node $(node --version)"
}

require_xcode() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "iOS verification requires macOS"
  require_command xcodebuild
  require_command xcrun
  require_command jq
  local xcode_major
  xcode_major="$(xcodebuild -version | awk '/^Xcode / { split($2, version, "."); print version[1] }')"
  [[ -n "${xcode_major}" && "${xcode_major}" -ge 26 ]] || {
    fail "Xcode 26+ is required for the iOS 26 downloader extension"
  }
  log "$(xcodebuild -version | tr '\n' ' ')"
}

ios_destination() {
  local device_family="$1"
  local configured_destination="$2"
  if [[ -n "${configured_destination}" ]]; then
    printf '%s\n' "${configured_destination}"
    return
  fi

  local device_id
  device_id="$({ xcrun simctl list devices available -j | jq -r \
    --arg family "${device_family}" '
    [
      .devices
      | to_entries[] as $runtime
      | select($runtime.key | test("iOS-[0-9]"))
      | $runtime.value[]
      | select(.isAvailable == true and (.name | startswith($family)))
      | {
          id: .udid,
          runtime: (
            $runtime.key
            | capture("iOS-(?<version>[0-9-]+)$").version
            | split("-")
            | map(tonumber)
          )
        }
    ]
    | sort_by(.runtime)
    | last
    | .id // empty
  '; } 2>/dev/null)"
  [[ -n "${device_id}" ]] || fail "no available ${device_family} simulator found"
  printf 'platform=iOS Simulator,id=%s\n' "${device_id}"
}

verify_audio_catalog() {
  require_node
  log "Verify canonical audio catalog and generated outputs"
  node "${repo_root}/scripts/generate-audio-manifest.mjs" --check
  node "${repo_root}/scripts/verify-audio-fallback-catalogs.mjs"
  node --test "${repo_root}"/CloudflareAudioFallback/tests/*.test.mjs
}

verify_contracts() {
  require_node
  log "Install and verify shared product/content contracts"
  npm ci --prefix "${repo_root}/tools/content-validator"
  npm --prefix "${repo_root}/tools/content-validator" audit --audit-level=high
  npm --prefix "${repo_root}/tools/content-validator" test
  npm --prefix "${repo_root}/tools/content-validator" run check
}

verify_server() {
  require_node
  log "Install and verify feedback Worker"
  npm ci --prefix "${repo_root}/server"
  npm --prefix "${repo_root}/server" audit --audit-level=high
  npm --prefix "${repo_root}/server" test
  npm --prefix "${repo_root}/server" run check
  npm --prefix "${repo_root}/server" run deploy:dry-run
}

verify_node() {
  verify_contracts
  verify_audio_catalog
  verify_server
}

verify_ios_unit() {
  require_xcode
  local destination
  destination="$(ios_destination iPhone "${IOS_DESTINATION:-}")"
  log "Run iOS unit tests on ${destination}"
  mkdir -p "${build_root}"
  xcodebuild test \
    -project "${repo_root}/lengyan.xcodeproj" \
    -scheme lengyan \
    -destination "${destination}" \
    -derivedDataPath "${derived_data}" \
    -only-testing:lengyanTests
}

verify_ios_build() {
  require_xcode
  log "Build host app, Widget, and asset downloader extension"
  mkdir -p "${build_root}"
  xcodebuild build \
    -project "${repo_root}/lengyan.xcodeproj" \
    -scheme lengyan \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "${derived_data}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO
}

verify_ios_ui_smoke() {
  require_xcode
  local destination
  destination="$(ios_destination iPad "${IOS_UI_DESTINATION:-}")"
  log "Run high-risk iPad/theme UI smoke tests on ${destination}"
  mkdir -p "${build_root}"
  xcodebuild test \
    -project "${repo_root}/lengyan.xcodeproj" \
    -scheme lengyan \
    -destination "${destination}" \
    -derivedDataPath "${derived_data}" \
    -only-testing:lengyanUITests/lengyanUITests/testIPadFavoriteToggleKeepsSplitDetailReaderStable \
    -only-testing:lengyanUITests/lengyanUITests/testIPadFavoritesTreeReaderDoesNotDuplicateBottomSafeArea \
    -only-testing:lengyanUITests/lengyanUITests/testRapidThemeSwitchingKeepsSettingsContentVisible
}

verify_ios_archive() {
  require_node
  require_xcode
  require_command zsh
  log "Build deterministic Managed Background Assets artifacts"
  "${repo_root}/scripts/package-production-audio-packs.sh"
  log "Archive the complete unsigned iOS product"
  rm -rf "${archive_path}"
  mkdir -p "$(dirname "${archive_path}")"
  xcodebuild archive \
    -project "${repo_root}/lengyan.xcodeproj" \
    -scheme lengyan \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "${archive_path}" \
    -derivedDataPath "${derived_data}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO
  "${repo_root}/scripts/verify-dual-stack-archive.sh" "${archive_path}"
}

usage() {
  cat <<'EOF'
Usage: ./verify.sh <command>

Commands:
  all             Clean-clone gate: Node checks plus iOS unit/build on macOS
  node            Shared contracts, audio catalog, and feedback Worker checks
  contracts       Product/content schemas, manifests, fixtures, and hashes
  audio-catalog   Canonical audio manifest and generated catalog checks
  server          Feedback Worker install, tests, syntax, and dry-run build
  ios-unit        All iOS unit tests on an available simulator
  ios-build       Release build of the app and embedded extensions
  ios-ui-smoke    Focused iPad favorites and rapid-theme UI tests
  ios-archive     Package audio artifacts, archive, and verify both audio stacks
EOF
}

cd "${repo_root}"
command_name="${1:-all}"

case "${command_name}" in
  all)
    verify_node
    if [[ "$(uname -s)" == "Darwin" ]]; then
      verify_ios_unit
      verify_ios_build
    fi
    ;;
  node) verify_node ;;
  contracts) verify_contracts ;;
  audio-catalog) verify_audio_catalog ;;
  server) verify_server ;;
  ios-unit) verify_ios_unit ;;
  ios-build) verify_ios_build ;;
  ios-ui-smoke) verify_ios_ui_smoke ;;
  ios-archive) verify_ios_archive ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    fail "unknown verification command: ${command_name}"
    ;;
esac
