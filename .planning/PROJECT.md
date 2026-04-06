# 楞严 (LengYan) — 功能增强

## What This Is

为已上线的《楞严经》原生 iOS 阅读App补齐核心体验缺口——阅读进度记忆、全文搜索、经文复制分享。严格按 `FEATURE_DESIGN.md` 的合并行方案融入现有首页，不破坏任何已有视觉元素。

## Core Value

打开App → 看到续读提示 → 一键回到上次位置，或搜索找到想读的经文。零摩擦、零打断。

## Requirements

### Validated

<!-- 已上线的功能，从现有代码推断 -->

- ✓ 科判树形导航（`SutraFrontViewController`）— 现有
- ✓ 翻页阅读体验（`SutraPageViewController`）— 现有
- ✓ 音频播放+后台播放+远程控制（`ModernAudioPlayerView` + `AudioManager`）— 现有
- ✓ 收藏夹添加/移除/浏览（`ModernFavoritesView`）— 现有
- ✓ 设置页（字号/主题/提醒）（`ModernSettingsView`）— 现有
- ✓ 三套主题明/棕/暗（`SutraDesignTokens`）— 现有
- ✓ 设计系统竹绿色板+霞鹜文楷（`Design/` 目录）— 现有
- ✓ 简繁体中文切换（`data/` + `data/simplified/`）— 现有
- ✓ 每日提醒（`ReminderManager`）— 现有
- ✓ 音频归属标注 — 现有

### Active

<!-- 本次要做的功能 -->

- [ ] 阅读进度记忆：离开阅读页时静默保存路径+页码，首页显示"续读"提示
- [ ] 全文搜索：首页搜索图标 → modal 搜索页 → 输入关键词匹配科判标题+经文正文 → 点击跳转阅读
- [ ] 续读+搜索合并行：卷章按钮下方新增 24pt 行，左续读右搜索，无进度时只显示搜索图标
- [ ] 经文复制/分享：阅读页 UITextView 开启 `isSelectable = true`，使用系统原生文本选择+分享菜单

### Out of Scope

<!-- 明确排除 -->

- 音频加载状态反馈 — 本次不做，不在 FEATURE_DESIGN.md 范围内
- 笔记/标注 — 复杂度高，Phase 3 推迟
- 阅读统计 — 非核心需求
- Widget 桌面小组件 — 非核心需求
- 经文对照/多译本 — 超出当前范围
- 用户账号/云同步/社交 — 不做

## Context

### 项目背景
- Brownfield 项目：已有完整 App 在线运行
- 设计系统完善：`SutraDesignTokens` 管理颜色/字体/间距/圆角
- 单例架构：`Book.shared`（内容）、`AudioManager.shared`（音频）、`Prefers.shared`（偏好）
- 路径导航：层级路径如 `/A2/B1/C2`，`Book.itemOfPath()` 是核心方法
- JSON 数据：本地 JSON 文件存储经文内容，无服务端

### 关键设计约束（来自 REQUIREMENTS.md 铁律）
1. 信息元素不加 opacity — textSecondary 原色
2. 一个强调色贯穿 — 竹绿 #228B22
3. 用系统控件 — 不造轮子
4. View 只放 UI，逻辑去 Domain/Util
5. 留白比内容重要

### FEATURE_DESIGN.md 的融入策略
- 续读和搜索合并在一行（24pt），位于卷章按钮与科判树之间
- header 高度从 240pt → 264pt
- 搜索为 modal 覆盖首页（不 push）
- 复制分享只需一行代码 `isSelectable = true`
- Prefers 已有 `updateReadingProgress()` 方法（未接线）

## Constraints

- **Tech Stack**: Swift 4.0, UIKit + SwiftUI 混合, iOS 15.0+
- **无外部依赖**: 不引入新的第三方库
- **设计系统**: 所有新 UI 必须使用现有 `ColorToken` / `ShapeToken` / `SutraTypography`
- **数据层**: 本地 JSON，`Book.shared` 是唯一数据源
- **持久化**: UserDefaults（`Prefers.shared`）

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 严格按 FEATURE_DESIGN.md 合并行方案 | 用户已深思熟虑设计，改动量最小且不破坏现有体验 | — Pending |
| 搜索用 SwiftUI（SearchView.swift） | 新页面用 SwiftUI 符合现有模式 | — Pending |
| 搜索逻辑用 Domain 层（SearchService.swift） | 遵循 View 只放 UI 的铁律 | — Pending |
| 进度保存用 UserDefaults | 与现有 Prefers 架构一致 | — Pending |
| 音频加载反馈不做 | 不在 FEATURE_DESIGN.md 范围内 | ✓ 确认排除 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-06 after initialization*
