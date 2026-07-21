#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
worker_config="${repo_root}/CloudflareAudioFallback/wrangler.jsonc"
repo_wrangler="${repo_root}/server/node_modules/.bin/wrangler"
catalog_version="$(jq -r '.catalogVersion' "${repo_root}/AudioAssets/audio-manifest.json")"

if [[ -n "${WRANGLER_BIN:-}" ]]; then
  wrangler_bin="${WRANGLER_BIN}"
elif [[ -x "${repo_wrangler}" ]]; then
  wrangler_bin="${repo_wrangler}"
else
  wrangler_bin="wrangler"
fi

if ! command -v "${wrangler_bin}" >/dev/null 2>&1; then
  echo "Wrangler was not found. Install it or set WRANGLER_BIN." >&2
  exit 69
fi

asset_dir="$(mktemp -d /tmp/lengyan-cloudflare-assets.XXXXXX)"
trap 'rm -rf -- "${asset_dir}"' EXIT

node "${script_dir}/verify-audio-fallback-catalogs.mjs"
"${script_dir}/stage-cloudflare-audio-fallback.sh" "${asset_dir}"
node --test "${repo_root}"/CloudflareAudioFallback/tests/*.test.mjs
"${wrangler_bin}" deploy \
  --config "${worker_config}" \
  --assets "${asset_dir}" \
  --strict \
  --message "Release zero-overage immutable audio fallback ${catalog_version}"
