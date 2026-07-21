#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
catalog_file="${repo_root}/AudioAssets/audio-manifest.json"
source_dir="${repo_root}/$(jq -r '.sourceDirectory' "${catalog_file}")"
file_extension="$(jq -r '.fileExtension' "${catalog_file}")"
catalog_version="$(jq -r '.catalogVersion' "${catalog_file}")"
cdn_path_prefix="$(jq -r '.cdnPathPrefix' "${catalog_file}")"
expected_count="$(jq -r '.tracks | length' "${catalog_file}")"
static_dir="${repo_root}/CloudflareAudioFallback/static"

node "${script_dir}/generate-audio-manifest.mjs" --check

if [[ $# -ne 1 ]]; then
  echo "usage: $0 EMPTY_OUTPUT_DIRECTORY" >&2
  exit 64
fi

output_dir="${1:A}"
if [[ ! -d "${output_dir}" || -L "${output_dir}" ]]; then
  echo "output must be an existing non-symlink directory" >&2
  exit 64
fi
if [[ -n "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "output directory must be empty: ${output_dir}" >&2
  exit 65
fi

mkdir -p "${output_dir}/.well-known"
cp "${static_dir}/_headers" "${output_dir}/_headers"
cp "${static_dir}/lengyan-audio-fallback" \
  "${output_dir}/.well-known/lengyan-audio-fallback"

staged=0
while IFS=$'\t' read -r asset_id expected_hash expected_bytes; do
  [[ -n "${asset_id}" && -n "${expected_hash}" && -n "${expected_bytes}" ]] || continue
  file_name="${asset_id}.${file_extension}"
  source_path="${source_dir}/${file_name}"
  destination_dir="${output_dir}/${cdn_path_prefix}/${catalog_version}/${expected_hash}"
  destination_path="${destination_dir}/${file_name}"

  test -s "${source_path}"
  [[ "$(stat -f '%z' "${source_path}")" == "${expected_bytes}" ]]
  [[ "$(shasum -a 256 "${source_path}" | awk '{print $1}')" == "${expected_hash}" ]]
  afinfo "${source_path}" >/dev/null
  mkdir -p "${destination_dir}"
  if ! ln "${source_path}" "${destination_path}" 2>/dev/null; then
    cp "${source_path}" "${destination_path}"
  fi
  (( staged += 1 ))
done < <(jq -r '.tracks[] | [.id, .sha256, (.bytes | tostring)] | @tsv' "${catalog_file}")

[[ "${staged}" == "${expected_count}" ]]
[[ "$(find "${output_dir}/${cdn_path_prefix}/${catalog_version}" -type f -name "*.${file_extension}" | wc -l | tr -d ' ')" == "${expected_count}" ]]
echo "Staged ${expected_count} immutable audio files for Workers Static Assets."
