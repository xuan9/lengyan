# Android Daily-Verse Widget Baseline, 2026-07-27

This record separates repeatable automated checks from one-off launcher visual
evidence. It is not a Gate F completion claim.

## Automated Baseline

The pinned API 35 compact managed device covers:

- provider discovery, one-hour update metadata, and horizontal/vertical resize;
- real packaged featured/favorite selection and nonempty source labels;
- one stable selection per product/content-version/local-date after the selected
  paragraph becomes reading progress;
- versioned fallback snapshot round-trip;
- explicit stable-paragraph launch into the reader;
- host composition at 180x110, 196x240, and 320x320dp.

The shared JVM suite covers Unicode-safe semantic clipping, accessibility
punctuation, layout selection, and a 17sp minimum body size.

## Launcher Inspection

On an API 36 AOSP emulator with Launcher3, the production debug APK was
installed and the Widget was added through the launcher picker. The initial 3x2
host measured approximately 196x240dp. This inspection caught two issues that a
nominal size preview had missed: the compact layout left excessive empty space,
and reusing the expanded line count clipped the final glyph. A dedicated tall
layout and 180x220 responsive declaration corrected both.

The final light and dark states showed a left-aligned 19sp scripture passage,
seven bounded lines with semantic ellipsis, and an intact source label. Tapping
the Widget opened `楞嚴經 卷九` at the exact paragraph displayed by the Widget.

## Remaining Matrix

- API 26 and API 33 system behavior;
- Pixel Launcher, Samsung launcher, and at least one target mainland OEM;
- compact, medium, and large frames on physical devices;
- 200% system font, Traditional/Simplified Chinese, TalkBack, and Switch Access
  on physical devices;
- settings entry, supported `requestPinAppWidget`, and verified fallback steps;
- package upgrade, timezone/date rollover, process death, and OEM battery policy.

These items remain release gates and cannot be inferred from emulator evidence.
