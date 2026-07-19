#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
require_signed=false

if [[ "${1:-}" == "--require-signed" ]]; then
  require_signed=true
  shift
fi
if [[ $# -ne 1 ]]; then
  echo "usage: $0 [--require-signed] /path/to/lengyan.xcarchive" >&2
  exit 64
fi

archive_path="$1"
app_info="${archive_path}/Products/Applications/lengyan.app/Info.plist"
expected_ids=(ly01 ly02 ly03 ly04 ly05 ly06 ly07 ly08 ly09 ly10 lyz1)
expected_csv="${(j:,:)expected_ids}"

if [[ "${require_signed}" == "true" ]]; then
  "${script_dir}/verify-m0-archive.sh" --require-signed "${archive_path}"
else
  "${script_dir}/verify-m0-archive.sh" "${archive_path}"
fi

[[ "$(plutil -extract LengyanManagedAudioEnabled raw "${app_info}")" == "true" ]]
[[ "$(plutil -extract LengyanManagedAudioCatalogReady raw "${app_info}")" == "true" ]]
[[ "$(plutil -extract LengyanM0ManagedAssetsDiagnosticsEnabled raw "${app_info}")" == "false" ]]

fallback_enabled="$(plutil -extract LengyanCDNAudioFallbackEnabled raw "${app_info}")"
fallback_base_url="$(plutil -extract LengyanCDNAudioFallbackBaseURL raw "${app_info}")"
expected_fallback_base_url="https://lengyan-audio-fallback.dhyana9.workers.dev"
fallback_stall_timeout="$(
  plutil -extract LengyanCDNAudioFallbackStallTimeoutSeconds raw "${app_info}"
)"
[[ "${fallback_enabled}" == "true" ]]
[[ "${fallback_base_url}" == "${expected_fallback_base_url}" ]]
(( fallback_stall_timeout >= 5 && fallback_stall_timeout <= 60 ))

actual_known_tags="$(
  awk '
    /KnownAssetTags = \(/ { inside = 1; next }
    inside && /\);/ { exit }
    inside {
      gsub(/[[:space:],]/, "")
      if (length > 0) print
    }
  ' "${repo_root}/lengyan.xcodeproj/project.pbxproj" | paste -sd, -
)"
[[ "${actual_known_tags}" == "${expected_csv}" ]]

if rg -q 'ON_DEMAND_RESOURCES_INITIAL_INSTALL_TAGS|ON_DEMAND_RESOURCES_PREFETCHED_TAGS' \
  "${repo_root}/lengyan.xcodeproj/project.pbxproj"; then
  echo "legacy ODR must not contain initial-install or install-time prefetch tags" >&2
  exit 1
fi

artifact_dir="${repo_root}/BackgroundAssets/Artifacts"
manifest_dir="${repo_root}/BackgroundAssets/Manifests"
checksum_file="${repo_root}/BackgroundAssets/audio-source-sha256.txt"
source_dir="${repo_root}/lengyan/屏東能淨協會讀誦"
catalog_source="${repo_root}/lengyan/Domain/AudioAssets/AudioAssetCatalog.swift"

[[ "$(find "${artifact_dir}" -maxdepth 1 -type f -name '*.aar' | wc -l | tr -d ' ')" == "11" ]]
[[ "$(find "${manifest_dir}" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')" == "11" ]]

for asset_id in "${expected_ids[@]}"; do
  pack_id="org.fuxuan.lengyan.audio.${asset_id}"
  relative_path="Audio/${asset_id}.m4a"
  manifest_path="${manifest_dir}/${pack_id}.json"
  artifact_path="${artifact_dir}/${pack_id}.aar"
  source_path="${source_dir}/${asset_id}.m4a"
  expected_hash="$(awk -v file="${asset_id}.m4a" '$2 == file { print $1 }' "${checksum_file}")"
  expected_bytes="$(stat -f '%z' "${source_path}")"
  catalog_line="$(rg -m 1 "^[[:space:]]*\"${asset_id}\":" "${catalog_source}")"
  catalog_hash="$(echo "${catalog_line}" | awk -F'"' '{print $4}')"
  catalog_bytes="$(
    echo "${catalog_line}" |
      sed -E 's/.*,[[:space:]]*([0-9_]+)\).*/\1/' |
      tr -d '_'
  )"

  test -s "${artifact_path}"
  [[ "$(shasum -a 256 "${source_path}" | awk '{ print $1 }')" == "${expected_hash}" ]]
  [[ "${catalog_hash}" == "${expected_hash}" ]]
  [[ "${catalog_bytes}" == "${expected_bytes}" ]]
  afinfo "${source_path}" >/dev/null
  jq -e \
    --arg id "${pack_id}" \
    --arg file "${relative_path}" '
      .assetPackID == $id and
      .downloadPolicy == {"onDemand": {}} and
      .fileSelectors == [{"file": $file}] and
      .platforms == ["iOS"]
    ' "${manifest_path}" >/dev/null
done

for legacy_asset_pack in "${archive_path}"/Products/OnDemandResources/*.assetpack; do
  if plutil -extract Priority raw "${legacy_asset_pack}/Info.plist" >/dev/null 2>&1; then
    echo "legacy ODR asset pack unexpectedly has install-time priority: ${legacy_asset_pack:t}" >&2
    exit 1
  fi
done

echo "Dual-stack production archive verified:"
echo "  runtime router: iOS 15-25 ODR; iOS 26+ Managed"
echo "  production Managed catalog: 11 on-demand packs"
echo "  production pack artifacts: 11"
echo "  production source hashes: 11 exact matches"
echo "  legacy ODR initial-install/prefetch tags: none"
echo "  Cloudflare fallback enabled: ${fallback_enabled}"
echo "  M0 user-facing diagnostics: disabled"
