# Helper Scripts

## Repository Verification

Use the root `./verify.sh` command for local and CI verification. It is the
public entry point for audio catalogs, the feedback Worker, iOS unit tests, all
embedded iOS targets, focused UI smoke tests, and production archive checks.
Run `./verify.sh --help` for the command list. CI must call this script instead
of maintaining a second set of build commands.

## Cloudflare Audio Fallback

`AudioAssets/audio-manifest.json` is the only hand-edited audio catalog.
`generate-audio-manifest.mjs` validates the source M4A files and generates the
Swift, Apple, Cloudflare, checksum and localized media catalogs. Its `--check`
mode fails if a generated file drifts from the canonical manifest.

`deploy-cloudflare-audio-fallback.sh` verifies and publishes the canonical
immutable audio files as zero-overage Workers Static Assets. It does not create
or use R2. `verify-cloudflare-audio-fallback.sh` downloads the public production
set and verifies every byte count and SHA-256. See
`BackgroundAssets/CLOUDFLARE_FALLBACK.md` for the production URL and policy.

## WebDriverAgent Management

These scripts help manage WebDriverAgent for Mobile MCP testing without repeatedly reinstalling.

### start-wda.sh
Starts WebDriverAgent if not already running.

**Usage:**
```bash
./scripts/start-wda.sh
```

**What it does:**
- Checks if WebDriverAgent is already running for the target simulator
- If not running, starts it in the background
- Waits for server to be ready on http://localhost:8100

**When to use:**
- Before using Mobile MCP tools
- After simulator restart
- After WebDriverAgent crash

### stop-wda.sh
Stops the running WebDriverAgent instance.

**Usage:**
```bash
./scripts/stop-wda.sh
```

**What it does:**
- Finds and kills the WebDriverAgent process for the target simulator
- Safe to run even if WebDriverAgent is not running

**When to use:**
- When done with Mobile MCP testing
- Before switching simulators
- To force restart WebDriverAgent

## Configuration

To use a different simulator, edit both scripts and change:
```bash
SIMULATOR_NAME="iPhone 17 Pro"
```

## Troubleshooting

**WebDriverAgent won't start:**
```bash
# Check if simulator is booted
xcrun simctl list devices | grep Booted

# Boot simulator if needed
open -a Simulator
# Wait for simulator to fully boot, then run start-wda.sh
```

**Port 8100 already in use:**
```bash
# Stop all WebDriverAgent processes
./scripts/stop-wda.sh

# Or find and kill manually
lsof -ti:8100 | xargs kill -9
```

**Need to rebuild WebDriverAgent:**
```bash
cd ~/github/WebDriverAgent
xcodebuild clean -project WebDriverAgent.xcodeproj -scheme WebDriverAgentRunner
./scripts/start-wda.sh
```
