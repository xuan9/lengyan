#!/bin/bash
#
# build_and_install.sh — 一键编译、安装、启动
#
# 用法: ./scripts/build_and_install.sh [设备ID]
#   不传参数时自动选择第一个启动的模拟器
#

set -euo pipefail

# ── 配置 ──
PROJECT="lengyan.xcodeproj"
SCHEME="lengyan"
BUNDLE_ID="org.fuxuan.lengyan"
DERIVED="/tmp/lengyan_build"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/lengyan.app"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── 选择设备 ──
if [ -n "${1:-}" ]; then
    DEVICE="$1"
else
    DEVICE=$(xcrun simctl list devices booted -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid']); sys.exit(0)
print('', end=''); sys.exit(1)
" 2>/dev/null || true)

    if [ -z "$DEVICE" ]; then
        echo -e "${RED}错误: 没有找到已启动的模拟器${NC}"
        echo "用法: $0 <设备ID>"
        echo "查看可用设备: xcrun simctl list devices booted"
        exit 1
    fi
fi

DEVICE_NAME=$(xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['udid'] == '$DEVICE':
            print(d.get('name', '$DEVICE')); sys.exit(0)
print('$DEVICE')
" 2>/dev/null || echo "$DEVICE")

echo -e "${YELLOW}▸ 设备: ${DEVICE_NAME}${NC}  ($DEVICE)"
echo ""

# ── 1. 编译 ──
echo -e "${YELLOW}▸ [1/3] 编译中...${NC}"
BUILD_LOG=$(mktemp)
if ! xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE" \
    -derivedDataPath "$DERIVED" \
    2>&1 | tee "$BUILD_LOG" | grep -E "(error:|warning:|BUILD)" | tail -20; then

    echo ""
    echo -e "${RED}✗ 编译失败${NC}"
    echo ""
    echo "── 错误详情 ──"
    grep -E "error:" "$BUILD_LOG" | sed 's/^/  /'
    echo ""
    echo "完整日志: $BUILD_LOG"
    exit 1
fi

# 检查是否真的成功（grep 可能干扰退出码）
if ! grep -q "BUILD SUCCEEDED" "$BUILD_LOG"; then
    echo -e "${RED}✗ 编译失败（未检测到 BUILD SUCCEEDED）${NC}"
    grep -E "error:" "$BUILD_LOG" | sed 's/^/  /'
    rm -f "$BUILD_LOG"
    exit 1
fi

ERROR_COUNT=$(grep -c "error:" "$BUILD_LOG" 2>/dev/null || echo "0")
WARNING_COUNT=$(grep -c "warning:" "$BUILD_LOG" 2>/dev/null || echo "0")
rm -f "$BUILD_LOG"

echo -e "${GREEN}✓ 编译成功${NC}  (${WARNING_COUNT} warnings)"

# ── 2. 安装 ──
echo -e "${YELLOW}▸ [2/3] 安装到模拟器...${NC}"
if ! xcrun simctl install "$DEVICE" "$APP_PATH" 2>&1; then
    echo -e "${RED}✗ 安装失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 安装成功${NC}"

# ── 3. 启动 ──
echo -e "${YELLOW}▸ [3/3] 启动 App...${NC}"
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
sleep 0.5

PID=$(xcrun simctl launch "$DEVICE" "$BUNDLE_ID" 2>&1 | grep -oE '[0-9]+$' || true)
if [ -z "$PID" ]; then
    echo -e "${RED}✗ 启动失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 启动成功${NC}  (PID: $PID)"
echo ""
echo -e "${GREEN}全部完成 ✓${NC}  →  $DEVICE_NAME"
