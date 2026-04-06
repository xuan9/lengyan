# 新功能设计：不伤害现有体验的融入方案

> 设计原则：每个新功能都应该像它一直就在那里。

---

## 总览：三个缺口，三种融入方式

| 功能 | 破坏性最低的融入方式 | 改动量 |
|------|---------------------|--------|
| 阅读进度记忆 + 全文搜索 | 合并行：卷章按钮下方，左续读右搜索 | 小+中 |
| 复制/分享文本 | UITextView 开启 isSelectable | 极小 |

---

## 一、续读 + 搜索：合并功能行

### 1.1 设计理念

续读和搜索本质上都是**导航辅助**——帮用户"找到想读的地方"。
两个功能合为一行，位于卷章按钮与科判树之间的**过渡带**：
- 不侵入经题、开经偈等神圣区域
- 不增加新的视觉层级——只是一行极淡的注释
- 没进度且不用搜索时，这行几乎隐形

### 1.2 阅读进度：现状

`Prefers.swift:70` 已经有 `updateReadingProgress()` 方法——但整个App没有任何地方调用它。
基础设施就位，只是电线没接。

### 1.3 合并行位置与视觉

位于 `setupHeaderView` 中卷章按钮底部金线下方、科判树上方：

```
 y=12   │   大佛頂首楞嚴經       │  ← 经题（不变）
 y=46   │   ──── 金线 ────      │
 y=52   │   开经偈              │  ← 开经偈（不变）
y=106   │   ──── 金线 ────      │
y=108   │   卷一 卷二 ... 卷五   │  ← 卷章按钮（不变）
y=156   │   卷六 卷七 ... 卷十   │
y=200   │   ──── 金线 ────      │  ← 底部金线（不变）
        │                        │
        │  续读·卷三第七品 →  🔍  │  ← 合并行 ★ 新增
        │                        │     header 高度 +24pt (240→264)
        │  • 显见是心            │  ← 科判树（不变）
```

**有进度时：**
```
│  续读·卷三第七品  →         🔍  │  ← 左续读，右搜索
```

**无进度时：**
```
│                         🔍      │  ← 只右对齐搜索图标
```

**视觉规范**：
- 整行高度：24pt（上下各 6pt padding + 12pt 内容）
- 字体：`uiCaption`（12pt）
- 续读文字色：`textSecondary`（古檀褐 #4A3728），**不加 opacity**
- 续读箭头：SF Symbol `chevron.right`，textSecondary 色，10pt
- 搜索图标：SF Symbol `magnifyingglass`，`primary`（竹绿 #228B22），16pt
- 整行背景：透明（与 header 背景一致）
- 点击续读 → 跳转到上次阅读位置
- 点击🔍 → 打开搜索页

### 1.4 进度保存：静默无声

- 在 `SutraPageViewController.viewWillDisappear` 中保存：
  - `lastReadPath`：当前阅读路径
  - `lastReadPageIndex`：当前页码
- 时机：用户离开阅读页时，不需要用户操作
- 注意：仅在正常阅读页离开时保存，pop 回首页时不覆盖

### 1.5 进度恢复行为

- 打开App → 进入首页 → 看到"续读"提示 → 点击 → 跳转到上次那页
- 不是自动跳转（用户可能想读别的章节）
- 不弹窗、不询问、不打断

### 1.6 实现要点

```
Prefers 新增：
- lastReadPath: String?        // 保存到 UserDefaults
- lastReadPageIndex: Int?      // 保存到 UserDefaults

SutraPageViewController 改动：
- viewWillDisappear: 调用 Prefers.shared.saveReadingProgress(path, page)

SutraFrontViewController 改动：
- setupHeaderView: header 高度 240→264
  在底部金线下方新增合并行：
  - 读取 Prefers.shared.lastReadPath → 左侧渲染"续读"（有值时）
  - 右侧渲染 🔍 搜索图标（始终显示）
```

---

## 二、全文搜索

### 2.1 搜索界面

点击首页合并行的🔍图标后，**覆盖整个首页**（modal，不 push）：

```
┌──────────────────────────────┐
│  ←  ┌─────────────────── 🔍 │  ← 搜索栏：回到首页风格
│     │ 搜索经文...             │     背景 navigationBar 色
│     └────────────────────── │     圆角输入框，竹绿光标
│                              │
│  • "七处征心"匹配结果 1       │  ← 搜索结果：与科判行完全同风格
│    卷一·第一品                │     金点 + 文字
│                              │     匹配文字高亮为竹绿色
│  • "七处征心"匹配结果 2       │
│    卷一·第二品                │
│                              │
│  • "七处征心"匹配结果 3       │
│    卷二·第三品                │
│                              │
└──────────────────────────────┘
```

**视觉规范**：
- 搜索栏：`navigationBar` 背景色，与 App 底色一致
- 输入框：圆角 8pt，`card` 背景色，`textSecondary` 占位文字
- 取消按钮：不用"取消"文字，用 `←` SF Symbol，与阅读页返回按钮一致
- 结果行：与 `SutraFrontViewController` 的科判行完全同风格
  - 同样的 `uiBody` 字号
  - 同样的金点 `•` 前缀
  - 同样的 `textPrimary` 文字色
  - 匹配关键词用 `primary`（竹绿）高亮
- 底部署名、底部金线——搜索页不需要，保持纯净

**空状态**（未输入时）：
```
┌──────────────────────────────┐
│  ←  ┌─────────────────── 🔍 │
│     │ 搜索经文...             │
│     └────────────────────── │
│                              │
│                              │
│          ❀                   │  ← 一朵莲花，textSecondary，极淡
│    输入关键词搜索经文         │     uiCaption 字号
│                              │
│                              │
└──────────────────────────────┘
```

### 2.3 实现架构

```
新增文件：
- SwiftUI/SearchView.swift        — 搜索界面（SwiftUI）
- Domain/SearchService.swift      — 搜索逻辑

SearchService — 两个搜索域，同一服务：
- input: String
- output: [SearchResult]
- 搜索域 1: 科判标题 — 遍历 Book.shared tree 节点的 name
  例: 搜"显见是心" → 命中科判条目
- 搜索域 2: 经文正文 — 遍历 Book.shared.contents 所有 content 段落
  例: 搜"七处征心" → 命中经文段落
- 匹配方式: 简单 String.contains()，不支持分词
- 结果限制: 最多 50 条
- 结果排序: 科判命中优先，正文命中在后（先目录后内容，符合阅读习惯）

SearchResult：
- path: String
- chapterName: String        // 所属科判/章节名
- matchedText: String         // 匹配片段的前 50 字
- matchRange: Range<String.Index>  // 高亮范围
- type: SearchResultType      // .outline（科判）或 .content（正文）

触发方式：
- SutraFrontViewController 的搜索图标点击
- present 一个 UIHostingController(rootView: SearchView())
- 搜索页为 modal 覆盖（不 push），背景与首页一致
```

---

## 三、复制/分享文本

### 3.1 现状

`SutraTableViewCell` 的 `textView` 设置：
```swift
textView.isEditable = false   // ✅ 不可编辑
textView.isSelectable = ???    // ❌ 默认 false
```

iOS 原生行为：`isSelectable = true` 的 UITextView 自动支持：
- 长按弹出文本选择
- 系统菜单（复制、分享、查找）
- 手柄拖选文本范围

### 3.2 设计方案：一行代码

```swift
textView.isSelectable = true
```

**这就是全部改动。**

不需要自定义菜单，不需要分享按钮，不需要任何新UI。
iOS 原生的文本选择 + 系统菜单已经完美覆盖"复制"和"分享"需求。

### 3.3 视觉影响评估

| 方面 | 影响 |
|------|------|
| 正常阅读 | 零影响——不长按就看不到选择功能 |
| 长按选择 | 系统原生选择手柄 + 系统菜单，与 iOS 全局一致 |
| 主题适配 | UITextView 的选择高亮色自动适配主题（系统行为） |
| 翻页 | 不影响——翻页手势是水平滑动，文本选择是长按触发 |

### 3.4 唯一注意事项

`SutraTableViewCell` 使用 `attributedText` 设置了 `paragraphStyle`。
确认 `isSelectable = true` 不会与自定义排版冲突。
理论上不会——UITextView 的文本选择基于 `NSLayoutManager`，与 `paragraphStyle` 独立。

---

## 四、什么不改

以下内容**不动**：

| 项目 | 原因 |
|------|------|
| 首页经题区域 | 神圣空间，只加"续读"一行淡字 |
| 开经偈 | 纹丝不动 |
| 卷章按钮 | 纹丝不动 |
| 科判树 | 纹丝不动 |
| 底部"南无楞严会上佛菩萨" | 纹丝不动 |
| 阅读页排版 | 只开 isSelectable |
| Tab Bar | 纹丝不动 |
| ZenTabHeaderView | 纹丝不动 |
| 设计系统色板 | 纹丝不动 |
| 主题系统 | 纹丝不动 |
| 音频播放器 | 已有下载状态，不额外改动 |

---

## 五、实现顺序

```
Step 1: 复制文本 ← 一行代码，立刻见效
        改动: SutraPageContentViewControllera.swift 一行
        风险: 几乎为零
        验收: 阅读页长按能选择文字 → 复制到剪贴板

Step 2: 合并行（续读 + 搜索入口）← 改首页 header
        改动: SutraFrontViewController.swift (setupHeaderView 底部加合并行)
        风险: 极低（仅增加 24pt 高度的 header 区域）
        验收: 看到卷章按钮下方有 🔍 图标，有进度时左侧显示"续读"

Step 3: 阅读进度 ← 复活已有代码
        改动: Prefers.swift (加2个属性)
              SutraPageViewController.swift (viewWillDisappear 加2行)
        风险: 极低
        验收: 读一页 → 杀App → 重开 → 合并行左侧显示"续读·卷三第七品 →"
              → 点击跳转到上次那页

Step 4: 全文搜索 ← 唯一的新功能
        新增: SearchView.swift, SearchService.swift
        改动: SutraFrontViewController.swift (合并行 🔍 点击事件)
        风险: 中等（新文件 + 搜索逻辑）
        验收: 点合并行🔍 → 输入"七处征心" → 看到结果 → 点击跳转阅读
```

---

## 六、设计红线

> 任何违反以下红线的实现，宁可不做：

1. **不加 opacity 到信息文字** — "续读"文字用 textSecondary 原色，不淡化
2. **不混入第二种强调色** — 搜索高亮用竹绿，搜索图标用竹绿
3. **不弹窗不打断** — 进度恢复是静默的，搜索是主动的
4. **不改变现有页面的任何视觉元素** — 新功能只做加法，不做减法
5. **用系统控件** — 文本选择用系统行为，分享用系统 Share Sheet
6. **新 UI 遵循现有 Design Token** — 不引入任何不在 `ColorToken` 中的颜色

---

*"好的设计添加价值。伟大的设计添加价值，然后隐身。"*
*— 演宣*
