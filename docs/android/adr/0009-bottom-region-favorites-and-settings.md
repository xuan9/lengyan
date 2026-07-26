# ADR 0009: Bottom Region, Favorites, And Settings

Status: accepted

Date: 2026-07-26

## Context

Android needs persistent product-level navigation without repeating the iOS
mini-player safe-area bug. Favorites must survive content upgrades through
stable IDs, and settings must expose only behavior that is actually available.
Audio, pagination, reminders, and the Widget pin flow are not implemented yet,
so presenting controls for them would create false product states.

## Decision

- Use one outer `Scaffold` bottom region. Its optional mini-player slot is
  composed immediately above `NavigationBar`, and the child content consumes
  the shell padding once.
- Ship three working destinations now: reading, favorites, and settings. Add
  listening as the fourth destination only with the real Media3 workflow.
- Keep independent reading and favorites navigation stacks. Switching tabs
  preserves each stack; selecting the active tab returns that stack to its
  root.
- Store paragraph favorites through the existing product/edition-isolated Room
  repository. Resolve paragraph and migrated section favorites through one
  stable-ID policy; unresolved legacy items remain visible and removable.
- Treat a favorite as a paragraph target, not a character offset. Room
  `position` remains list order and is never reused as a reading offset.
- Expose only theme, traditional/simplified content, and the five existing
  reader font levels in settings. Do not show a third Widget style or controls
  for pagination, reminders, or audio before their workflows exist.
- Keep the currently selected page while a locale package reloads instead of
  replacing the navigation shell with a loading screen.

## Consequences

The future mini-player has a fixed insertion point and cannot independently add
another navigation-bar inset. Current Android navigation has three tabs rather
than visually reserving a nonfunctional audio tab. A migrated section favorite
can open at its preferred paragraph or the first readable descendant, while a
missing legacy target is not silently discarded.

Settings remains intentionally smaller than the eventual P0 scope. Pagination,
reminders, Widget pinning, and audio settings require their production services
and tests before controls are added.

## Verification

- JVM tests cover paragraph favorites, section preferred anchors, subtree
  fallback, foreign editions, and unresolved legacy entries.
- API 35 device tests cover add, persistence, exact paragraph return, remove,
  empty state, theme change, locale reload, and absence of the unsupported
  `经文卡片`/`經文卡片` option.
- A 320dp Compose test at 200% font scale proves the mini-player slot directly
  touches navigation and the three destinations do not overlap.
- API 36 screenshots cover home, reader, favorites, settings, and settings at
  system font scale 200%.
