#!/bin/bash
#
# build_and_install_device.sh — 一键编译、安装、启动到真机
#
# 用法: ./scripts/build_and_install_device.sh [设备ID]
#   不传参数时自动选择第一个连接的真机设备
#

set -euo pipefail

# 绕过 Xcode 17.3/26.3 版本的 SWBBuildService/llbuild 符号加载 Bug
export DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/usr/lib/swift/pm/llbuild"

# ── 配置 ──
PROJECT="lengyan.xcodeproj"
SCHEME="lengyan"
BUNDLE_ID="org.fuxuan.lengyan"
DERIVED="/tmp/lengyan_device_build"
APP_PATH="$DERIVED/Build/Products/Debug-iphoneos/lengyan.app"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── 选择设备 ──
if [ -n "${1:-}" ]; then
    DEVICE="$1"
    DEVICE_NAME="$1"
else
    echo -e "${YELLOW}▸ 正在查找连接的真机设备...${NC}"
    DEVICE_INFO=$(xcrun xctrace list devices 2>/dev/null | python3 -c "
import sys, re
lines = sys.stdin.read().split('\n')
in_devices = False
devices = []
for line in lines:
    if '== Devices ==' in line:
        in_devices = True
        continue
    if '==' in line:
        in_devices = False
    if in_devices and line.strip():
        # Match UDID at the end: (UDID)
        match = re.search(r'\(([^)]+)\)$', line.strip())
        if match:
            udid = match.group(1)
            name = line.split('(')[0].strip()
            # Skip Mac hosts
            if not any(x in line for x in ['MacBook', 'Mac mini', 'Mac Studio', 'Mac Pro', 'iMac', 'MacBook Pro', 'MacBook Air']):
                devices.append((name, udid))
if devices:
    print(f'{devices[0][1]}|{devices[0][0]}')
else:
    sys.exit(1)
" || true)

    if [ -z "$DEVICE_INFO" ]; then
        echo -e "${RED}错误: 没有找到已连接的 iOS 真机设备${NC}"
        echo "请确保设备已连接 USB/Wi-Fi，且处于解锁状态并启用了开发者模式。"
        exit 1
    fi

    DEVICE=$(echo "$DEVICE_INFO" | cut -d'|' -f1)
    DEVICE_NAME=$(echo "$DEVICE_INFO" | cut -d'|' -f2)
fi

echo -e "${YELLOW}▸ 设备: ${DEVICE_NAME}${NC}  ($DEVICE)"
echo ""

# ── 清理旧构建缓存 ──
# 固定复用 /tmp 下的 DerivedData 时，Xcode 的 ExplicitPrecompiledModules
# 偶尔会留下失效 .pcm 引用，导致 Foundation-*.pcm not found。
if [[ -z "$DERIVED" || "$DERIVED" != /tmp/lengyan_device_build ]]; then
    echo -e "${RED}错误: 非预期的构建目录: $DERIVED${NC}"
    exit 1
fi
echo -e "${YELLOW}▸ 清理旧的真机构建缓存...${NC}"
rm -rf "$DERIVED"
mkdir -p "$DERIVED"
echo ""

# ── 1. 编译 ──
echo -e "${YELLOW}▸ [1/3] 编译中 (Target: 真机)...${NC}"
BUILD_LOG=$(mktemp)
if ! xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    2>&1 | tee "$BUILD_LOG" | grep -E "(error:|warning:|BUILD)" | tail -20; then

    echo ""
    echo -e "${RED}✗ 编译失败${NC}"
    echo ""
    echo "── 错误详情 ──"
    grep -E "error:" "$BUILD_LOG" | sed 's/^/  /' || true
    echo ""
    echo "完整日志: $BUILD_LOG"
    exit 1
fi

# 检查是否真的成功
if ! grep -q "BUILD SUCCEEDED" "$BUILD_LOG"; then
    echo -e "${RED}✗ 编译失败（未检测到 BUILD SUCCEEDED）${NC}"
    grep -E "error:" "$BUILD_LOG" | sed 's/^/  /' || true
    rm -f "$BUILD_LOG"
    exit 1
fi

ERROR_COUNT=$(grep -c "error:" "$BUILD_LOG" 2>/dev/null || echo "0")
WARNING_COUNT=$(grep -c "warning:" "$BUILD_LOG" 2>/dev/null || echo "0")
rm -f "$BUILD_LOG"

echo -e "${GREEN}✓ 编译成功${NC}  (${WARNING_COUNT} warnings)"

# ── 2. 安装 ──
echo -e "${YELLOW}▸ [2/3] 安装到真机...${NC}"
if ! xcrun devicectl device install app --device "$DEVICE" "$APP_PATH" 2>&1; then
    echo -e "${RED}✗ 安装失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 安装成功${NC}"

# ── 3. 启动 ──
echo -e "${YELLOW}▸ [3/3] 启动 App...${NC}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist")
echo -e "${YELLOW}▸ 启动 Bundle ID: ${BUNDLE_ID}${NC}"
if ! xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" 2>&1; then
    echo -e "${RED}✗ 启动失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 启动成功${NC}"
echo ""
echo -e "${GREEN}全部完成 ✓${NC}  →  $DEVICE_NAME"
