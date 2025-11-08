#!/bin/bash
# Stop WebDriverAgent

SIMULATOR_NAME="iPhone 17 Pro"

echo "Stopping WebDriverAgent for $SIMULATOR_NAME..."
pkill -f "WebDriverAgentRunner.*$SIMULATOR_NAME"

if [ $? -eq 0 ]; then
    echo "✓ WebDriverAgent stopped"
else
    echo "WebDriverAgent was not running"
fi
