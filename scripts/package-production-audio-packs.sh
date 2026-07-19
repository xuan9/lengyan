#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
manifest_dir="${repo_root}/BackgroundAssets/Manifests"
artifact_dir="${repo_root}/BackgroundAssets/Artifacts"
source_dir="${repo_root}/lengyan/屏東能淨協會讀誦"
checksum_file="${repo_root}/BackgroundAssets/audio-source-sha256.txt"
all_ids=(ly01 ly02 ly03 ly04 ly05 ly06 ly07 ly08 ly09 ly10 lyz1)
if (( $# == 0 )); then
  ids=("${all_ids[@]}")
else
  ids=("$@")
fi

mkdir -p "${artifact_dir}"

for asset_id in "${ids[@]}"; do
  if (( ${all_ids[(Ie)${asset_id}]} == 0 )); then
    echo "unknown audio asset id: ${asset_id}" >&2
    exit 64
  fi

  pack_id="org.fuxuan.lengyan.audio.${asset_id}"
  relative_path="Audio/${asset_id}.m4a"
  manifest_path="${manifest_dir}/${pack_id}.json"
  source_path="${source_dir}/${asset_id}.m4a"
  artifact_path="${artifact_dir}/${pack_id}.aar"
  expected_hash="$(awk -v file="${asset_id}.m4a" '$2 == file { print $1 }' "${checksum_file}")"

  test -n "${expected_hash}"
  test -s "${source_path}"
  [[ "$(shasum -a 256 "${source_path}" | awk '{ print $1 }')" == "${expected_hash}" ]]
  afinfo "${source_path}" >/dev/null

  jq -e \
    --arg id "${pack_id}" \
    --arg file "${relative_path}" '
      .assetPackID == $id and
      .downloadPolicy == {"onDemand": {}} and
      .fileSelectors == [{"file": $file}] and
      .platforms == ["iOS"] and
      (keys | sort) == ["assetPackID", "downloadPolicy", "fileSelectors", "platforms"]
    ' "${manifest_path}" >/dev/null

  staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/lengyan-audio-pack.${asset_id}.XXXXXX")"
  mkdir -p "${staging_dir}/Audio"
  cp "${source_path}" "${staging_dir}/${relative_path}"
  temporary_artifact="${staging_dir}/${pack_id}.aar"

  (
    cd "${staging_dir}"
    xcrun ba-package package "${manifest_path}" --output-path "${temporary_artifact}"
  )

  mv -f "${temporary_artifact}" "${artifact_path}"
  rm -f "${staging_dir}/${relative_path}"
  rmdir "${staging_dir}/Audio" "${staging_dir}"
  echo "packaged ${pack_id}: $(du -h "${artifact_path}" | awk '{ print $1 }')"
done

echo "Production audio packs ready in ${artifact_dir}"
