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

node "${script_dir}/generate-audio-manifest.mjs" --check

if [[ $# -ne 1 ]]; then
  echo "usage: $0 https://audio.example.com" >&2
  exit 64
fi

base_url="${1%/}"
if [[ "${base_url}" != https://* ]]; then
  echo "fallback base URL must use HTTPS" >&2
  exit 64
fi

health_json="$(curl --fail --silent --show-error \
  --proto '=https' \
  --proto-redir '=https' \
  --retry 5 \
  --retry-delay 2 \
  --retry-all-errors \
  "${base_url}/.well-known/lengyan-audio-fallback")"
[[ "$(jq -r '.service' <<< "${health_json}")" == "lengyan-audio-fallback" ]]
[[ "$(jq -r '.status' <<< "${health_json}")" == "ok" ]]
[[ "$(jq -r '.catalogVersion' <<< "${health_json}")" == "${catalog_version}" ]]
[[ "$(jq -r '.assetCount' <<< "${health_json}")" == "${expected_count}" ]]
[[ "$(jq -r '.storage' <<< "${health_json}")" == "workers-static-assets" ]]

unknown_status="$(curl --silent --show-error --output /dev/null \
  --proto '=https' \
  --write-out '%{http_code}' \
  "${base_url}/${cdn_path_prefix}/${catalog_version}/not-public.${file_extension}")"
[[ "${unknown_status}" == "404" ]]

write_status="$(curl --silent --show-error --output /dev/null \
  --proto '=https' \
  --request POST \
  --write-out '%{http_code}' \
  "${base_url}/.well-known/lengyan-audio-fallback")"
[[ "${write_status}" != 2* ]]

verification_dir="$(mktemp -d /tmp/lengyan-cdn-verify.XXXXXX)"
trap 'rm -rf -- "${verification_dir}"' EXIT

verified=0
while IFS=$'\t' read -r asset_id expected_hash manifest_bytes; do
  [[ -n "${asset_id}" && -n "${expected_hash}" && -n "${manifest_bytes}" ]] || continue
  file_name="${asset_id}.${file_extension}"
  remote_url="${base_url}/${cdn_path_prefix}/${catalog_version}/${expected_hash}/${file_name}"
  local_path="${verification_dir}/${file_name}"
  header_path="${verification_dir}/${file_name}.headers"
  expected_bytes="$(stat -f '%z' "${source_dir}/${file_name}")"
  [[ "${expected_bytes}" == "${manifest_bytes}" ]]

  echo "Verifying ${remote_url}"
  curl --fail --silent --show-error --location \
    --proto '=https' \
    --proto-redir '=https' \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    --dump-header "${header_path}" \
    --output "${local_path}" \
    "${remote_url}"

  [[ "$(stat -f '%z' "${local_path}")" == "${expected_bytes}" ]]
  [[ "$(shasum -a 256 "${local_path}" | awk '{print $1}')" == "${expected_hash}" ]]
  afinfo "${local_path}" >/dev/null
  rg -qi '^content-type:[[:space:]]*audio/(mp4|x-m4a)' "${header_path}"
  rg -qi '^cache-control:[[:space:]]*public, max-age=31536000, immutable' "${header_path}"
  rg -qi '^etag:' "${header_path}"

  head_path="${verification_dir}/${file_name}.head"
  head_status="$(curl --silent --show-error --head \
    --proto '=https' \
    --proto-redir '=https' \
    --dump-header "${head_path}" \
    --output /dev/null \
    --write-out '%{http_code}' \
    "${remote_url}")"
  [[ "${head_status}" == "200" ]]
  rg -qi '^content-type:[[:space:]]*audio/(mp4|x-m4a)' "${head_path}"
  rg -qi '^etag:' "${head_path}"

  range_path="${verification_dir}/${file_name}.range"
  range_status="$(curl --silent --show-error --output /dev/null \
    --proto '=https' \
    --proto-redir '=https' \
    --dump-header "${range_path}" \
    --write-out '%{http_code}' \
    --header 'Range: bytes=0-0' \
    "${remote_url}")"
  [[ "${range_status}" == "200" || "${range_status}" == "206" ]]
  if [[ "${range_status}" == "206" ]]; then
    rg -qi "^content-range:[[:space:]]*bytes 0-0/${expected_bytes}" "${range_path}"
  fi
  (( verified += 1 ))
done < <(jq -r '.tracks[] | [.id, .sha256, (.bytes | tostring)] | @tsv' "${catalog_file}")

[[ "${verified}" == "${expected_count}" ]]
echo "Verified assets-only health/read-only boundary and ${expected_count} fallback files: HTTPS, bytes, SHA-256, M4A, immutable cache, HEAD and safe Range handling."
