#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
source_dir="${repo_root}/lengyan/屏東能淨協會讀誦"
checksum_file="${repo_root}/BackgroundAssets/audio-source-sha256.txt"
static_dir="${repo_root}/CloudflareAudioFallback/static"

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
while read -r expected_hash file_name; do
  [[ -n "${expected_hash}" && -n "${file_name}" ]] || continue
  source_path="${source_dir}/${file_name}"
  destination_dir="${output_dir}/audio/v1/${expected_hash}"
  destination_path="${destination_dir}/${file_name}"

  test -s "${source_path}"
  [[ "$(shasum -a 256 "${source_path}" | awk '{print $1}')" == "${expected_hash}" ]]
  afinfo "${source_path}" >/dev/null
  mkdir -p "${destination_dir}"
  if ! ln "${source_path}" "${destination_path}" 2>/dev/null; then
    cp "${source_path}" "${destination_path}"
  fi
  (( staged += 1 ))
done < "${checksum_file}"

[[ "${staged}" == "11" ]]
[[ "$(find "${output_dir}/audio/v1" -type f -name '*.m4a' | wc -l | tr -d ' ')" == "11" ]]
echo "Staged 11 immutable audio files for Workers Static Assets."
