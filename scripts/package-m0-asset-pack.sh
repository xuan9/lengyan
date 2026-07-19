#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
source_root="${repo_root}/BackgroundAssetsM0/PackSource"
manifest_path="${repo_root}/BackgroundAssetsM0/Manifests/org.fuxuan.lengyan.m0.smoke.json"
artifact_dir="${repo_root}/BackgroundAssetsM0/Artifacts"
artifact_path="${artifact_dir}/org.fuxuan.lengyan.m0.smoke.aar"
expected_pack_id="org.fuxuan.lengyan.m0.smoke"
expected_marker="M0/managed-assets-smoke.txt"
expected_audio="M0/managed-assets-smoke.m4a"

jq -e \
  --arg id "${expected_pack_id}" \
  --arg marker "${expected_marker}" \
  --arg audio "${expected_audio}" '
  .assetPackID == $id and
  .downloadPolicy == {"onDemand": {}} and
  .fileSelectors == [{"file": $marker}, {"file": $audio}] and
  .platforms == ["iOS"] and
  (has("userInfo") | not)
' "${manifest_path}" >/dev/null

test -f "${source_root}/${expected_marker}"
test -s "${source_root}/${expected_audio}"
mkdir -p "${artifact_dir}"

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/lengyan-m0-pack.XXXXXX")"
temporary_artifact="${temporary_dir}/${expected_pack_id}.aar"

(
  cd "${source_root}"
  xcrun ba-package package "${manifest_path}" --output-path "${temporary_artifact}"
)

mv -f "${temporary_artifact}" "${artifact_path}"

echo "M0 asset pack: ${artifact_path}"
shasum -a 256 "${artifact_path}"
du -h "${artifact_path}"
