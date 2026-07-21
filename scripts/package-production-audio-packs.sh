#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
catalog_file="${repo_root}/AudioAssets/audio-manifest.json"
manifest_dir="${repo_root}/BackgroundAssets/Manifests"
artifact_dir="${repo_root}/BackgroundAssets/Artifacts"
source_dir="${repo_root}/$(jq -r '.sourceDirectory' "${catalog_file}")"
file_extension="$(jq -r '.fileExtension' "${catalog_file}")"
pack_id_prefix="$(jq -r '.apple.assetPackIDPrefix' "${catalog_file}")"
relative_directory="$(jq -r '.apple.relativeDirectory' "${catalog_file}")"
all_ids=("${(@f)$(jq -r '.tracks[].id' "${catalog_file}")}")
node "${script_dir}/generate-audio-manifest.mjs" --check

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

  pack_id="${pack_id_prefix}${asset_id}"
  relative_path="${relative_directory}/${asset_id}.${file_extension}"
  manifest_path="${manifest_dir}/${pack_id}.json"
  source_path="${source_dir}/${asset_id}.${file_extension}"
  artifact_path="${artifact_dir}/${pack_id}.aar"
  expected_hash="$(jq -r --arg id "${asset_id}" '.tracks[] | select(.id == $id) | .sha256' "${catalog_file}")"
  expected_bytes="$(jq -r --arg id "${asset_id}" '.tracks[] | select(.id == $id) | .bytes' "${catalog_file}")"

  test -n "${expected_hash}"
  test -s "${source_path}"
  [[ "$(stat -f '%z' "${source_path}")" == "${expected_bytes}" ]]
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
  mkdir -p "${staging_dir}/${relative_directory}"
  cp "${source_path}" "${staging_dir}/${relative_path}"
  temporary_artifact="${staging_dir}/${pack_id}.aar"

  (
    cd "${staging_dir}"
    xcrun ba-package package "${manifest_path}" --output-path "${temporary_artifact}"
  )

  mv -f "${temporary_artifact}" "${artifact_path}"
  rm -f "${staging_dir}/${relative_path}"
  rmdir "${staging_dir}/${relative_directory}" "${staging_dir}"
  echo "packaged ${pack_id}: $(du -h "${artifact_path}" | awk '{ print $1 }')"
done

echo "Production audio packs ready in ${artifact_dir}"
