#!/bin/bash
# Start WebDriverAgent for Mobile MCP
# Only starts if not already running

SIMULATOR_NAME="iPhone 17 Pro"
WDA_PATH="$HOME/github/WebDriverAgent"

# Check if WebDriverAgent is already running
if pgrep -f "WebDriverAgentRunner.*$SIMULATOR_NAME" > /dev/null; then
    echo "✓ WebDriverAgent is already running for $SIMULATOR_NAME"
    exit 0
fi

echo "Starting WebDriverAgent for $SIMULATOR_NAME..."
cd "$WDA_PATH" && xcodebuild \
    -project WebDriverAgent.xcodeproj \
    -scheme WebDriverAgentRunner \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    test &

WDA_PID=$!
echo "WebDriverAgent started with PID: $WDA_PID"
echo "Keep this running in the background. Press Ctrl+C to stop."

# Wait for server to be ready
sleep 5
echo "✓ WebDriverAgent should be ready at http://localhost:8100"
