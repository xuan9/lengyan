#!/bin/zsh

set -euo pipefail

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
app_path="${archive_path}/Products/Applications/lengyan.app"
extension_path="${app_path}/Extensions/LengyanAssetDownloaderExtension.appex"
main_info="${app_path}/Info.plist"
extension_info="${extension_path}/Info.plist"
odr_root="${archive_path}/Products/OnDemandResources"
odr_manifest="${app_path}/OnDemandResources.plist"
host_executable="${app_path}/$(plutil -extract CFBundleExecutable raw "${main_info}")"
extension_executable="${extension_path}/$(plutil -extract CFBundleExecutable raw "${extension_info}")"
expected_tags="ly01,ly02,ly03,ly04,ly05,ly06,ly07,ly08,ly09,ly10,lyz1"

test -d "${archive_path}"
test -d "${app_path}"
test -f "${main_info}"
test -d "${extension_path}"
test -f "${extension_info}"
test -f "${host_executable}"
test -f "${extension_executable}"

[[ "$(plutil -extract MinimumOSVersion raw "${main_info}")" == "15.0" ]]
[[ "$(plutil -extract BAAppGroupID raw "${main_info}")" == "group.org.fuxuan.books" ]]
[[ "$(plutil -extract BAHasManagedAssetPacks raw "${main_info}")" == "true" ]]
[[ "$(plutil -extract BAUsesAppleHosting raw "${main_info}")" == "true" ]]
[[ "$(plutil -extract MinimumOSVersion raw "${extension_info}")" == "26.0" ]]
[[ "$(plutil -extract EXAppExtensionAttributes.EXExtensionPointIdentifier raw "${extension_info}")" == "com.apple.background-asset-downloader-extension" ]]

test -f "${odr_manifest}"
test -d "${odr_root}"
[[ "$(find "${odr_root}" -maxdepth 1 -type d -name '*.assetpack' | wc -l | tr -d ' ')" == "11" ]]
[[ "$(find "${odr_root}" -type f -name '*.m4a' | wc -l | tr -d ' ')" == "11" ]]
[[ "$(find "${app_path}" -type f -name '*.m4a' | wc -l | tr -d ' ')" == "0" ]]

actual_tags="$(
  plutil -convert json -o - "${odr_manifest}" |
    jq -r '.NSBundleResourceRequestTags | keys | join(",")'
)"
[[ "${actual_tags}" == "${expected_tags}" ]]

for asset_pack in "${odr_root}"/*.assetpack; do
  [[ "$(find "${asset_pack}" -type f -name '*.m4a' | wc -l | tr -d ' ')" == "1" ]]
done

xcrun vtool -show-build "${host_executable}" | grep -Eq 'minos[[:space:]]+15\.0'
xcrun vtool -show-build "${extension_executable}" | grep -Eq 'minos[[:space:]]+26\.0'

# The iOS 15 host may reference BackgroundAssets only as a weak dylib. A strong
# load command would make the binary fail before the availability guard runs.
otool -l "${host_executable}" | awk '
  /cmd LC_LOAD_WEAK_DYLIB/ { load_kind = "weak"; next }
  /cmd LC_LOAD_DYLIB/ { load_kind = "strong"; next }
  /BackgroundAssets\.framework\/BackgroundAssets/ {
    found = 1
    if (load_kind != "weak") exit 2
  }
  END { if (!found) exit 1 }
'

if [[ "${require_signed}" == "true" ]]; then
  codesign --verify --deep --strict "${app_path}"
  codesign --verify --strict "${extension_path}"
fi

echo "M0 archive structure verified:"
echo "  host minimum OS: 15.0"
echo "  downloader minimum OS: 26.0"
echo "  BackgroundAssets host linkage: weak"
echo "  managed Background Assets keys: present"
echo "  legacy ODR asset packs/tags: 11 exact matches"
echo "  M4A files embedded in app: 0"
if [[ "${require_signed}" == "true" ]]; then
  echo "  code signatures: verified"
else
  echo "  code signatures: not required by this structural check"
fi
