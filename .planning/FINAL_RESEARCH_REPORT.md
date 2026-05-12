# 楞严App — 读经·听经 深度研究报告

> 14轮迭代研究 | 50项发现 | 美学守护原则 | 4阶段实施路线图
> 日期：2026-05-09

---

## 第一章：美学守护审核

### 1.1 现有设计的美学成就

现有App已建立一套高度成熟的「禅意极简」视觉体系，其美学成就值得珍视：

| 维度 | 成就 | 评分 |
|------|------|------|
| **色彩温度一致性** | 三套主题（宣纸/古籍/月下禅房）内无冷暖混杂 | 9.5/10 |
| **排版韵律** | 黄金比例缩放 + 光学尺寸系统，大小文字皆优雅 | 9/10 |
| **留白呼吸感** | 28pt卡片内距、1.8倍行高、48pt章节间距 | 9.5/10 |
| **Design Token覆盖** | 23+语义色值Token，UIKit/SwiftUI统一访问 | 9/10 |
| **主题切换流畅性** | 0.3秒交叉溶解，全局响应 | 8.5/10 |
| **文化真实性** | 宣纸质感、古金装饰线、禅竹绿点缀 | 9.5/10 |

**总体评价：现有App的视觉和谐度极高，是经过精心打磨的设计。**

### 1.2 美学破坏风险评估

对50项研究发现逐一做美学影响评估：

#### 🔴 高风险 — 可能破坏现有和谐

| # | 建议 | 风险点 | 修正方向 |
|---|------|--------|----------|
| L-09 | 进度条触摸目标扩大到44pt | 当前5pt高度是刻意极简设计，骤然扩大将破坏播放条视觉轻盈感 | **改用隐形扩大触摸区域**：视觉保持5pt，触摸热区44pt |
| L-13 | 播放速度控制UI（6档） | 新增一行控件增加视觉密度 | **收纳到长按/二级面板**，不在主界面展示 |
| L-14 | 睡眠定时器UI | 同上，增加界面元素 | **收纳到"..."菜单**，与分享、播放速度同列 |
| L-11 | 播放列表6种状态视觉重设计 | 当前列表视觉简洁，过度设计会破坏 | **仅修复功能Bug，不改变视觉风格** |
| R-12 | Dynamic Type全面支持 | 放大后的排版可能破坏精心调校的行距/字距 | **仅对经文正文支持，UI骨架元素不缩放**（已是现有策略） |
| R-14 | 8个微交互动画规格 | 过多动画会破坏"静"的氛围 | **仅对用户直接操作做0.2s微反馈，自动触发的动画全部省略** |

#### 🟡 中等风险 — 需谨慎实施

| # | 建议 | 风险点 | 修正方向 |
|---|------|--------|----------|
| R-06 | 统一3个阅读VC为2个 | 导航行为变化可能让老用户困惑 | **保持现有导航手势不变，仅做内部架构统一** |
| R-13 | 首页续读按钮视觉升级 | 权重过高会破坏首页「经题+开经偈」的视觉焦点 | **微妙提升：字号14→16，颜色升至textSecondary，保持克制** |
| L-08 | 断点续播PlaybackState | 新增存储字段不影响视觉 | **纯后端改动，无美学风险** |
| L-10 | 状态机重构 | 不涉及视觉 | **纯架构改动，无美学风险** |

#### 🟢 低风险 — 安全或美学正向

| # | 建议 | 说明 |
|---|------|------|
| R-06a | 移除死代码（openContent等） | 减少代码量，无视觉影响 |
| R-10 | 修复5处force unwrap崩溃 | 纯安全修复 |
| R-14a | PurePageContentVC主题切换修复 | **美学正向** — 消除当前不一致 |
| ~~L-06~~ | ~~修复ForEach(1...3)应为1...6~~ | ✅**设计如此**，1-3次是刻意显示范围 | ~~无需修复~~ |
| L-10 | PlayMode实现（当前8种模式全部失效） | 功能修复 |
| L-08 | 音频下载进度真实化 | UX正向 |
| ~~R-14b~~ | ~~分享功能统一为卡片分享~~ | ✅**已统一** — 两个VC均已使用SutraCardRenderer |
| R/L-14 | 主题切换链完整化 | **美学正向** — 全App统一 |

### 1.3 美学守护原则

所有实施必须遵循以下原则：

1. **视觉不动，触摸先行** — 触摸目标可以大于视觉元素，不为了可及性牺牲美感
2. **功能收纳** — 新功能收纳到二级入口（长按/菜单/面板），不增加主界面视觉密度
3. **克制动效** — 仅对用户主动操作做0.15-0.3s微反馈，无自动播放动画
4. **色值守恒** — 不新增颜色Token，只使用现有23+Token的不同透明度组合
5. **留白不可侵** — 不为任何理由减少现有padding/spacing值
6. **Bug先于体验** — 崩溃修复优先于体验优化，且崩溃修复无美学风险
7. **一致性即美学** — 主题切换不响应是最大的美学破坏，修复它是提升（注：分享功能已统一，无需修复）

---

## 第二章：读经页面研究发现

### 2.1 页面架构

```
SutraFrontViewController (首页)
  ├── SutraPageViewController (卷式翻页 UIPageVC, pageIndex导航)
  │     └── SutraPageContentViewController (TableVC, 内容展示)
  ├── SutraPurePageViewController (科判式翻页 UIPageVC, path导航)
  │     └── SutraPurePageContentViewController (UITextView, 内容展示)
  └── SutraIndexViewController (科判树 RATreeView)
```

### 2.2 P0 — 必须修复（崩溃/数据丢失）

| ID | 发现 | 位置 | 影响 |
|----|------|------|------|
| R-P0-1 | **5处force unwrap崩溃点** | PurePageContentVC: path!; PageVC: index!; FrontVC: openContent | 用户操作路径可达，App直接闪退。⚠️PurePageContentVC第29行`item!["path"]!`在else分支内，item非nil安全，但`["path"]!`和`as! String`仍为force unwrap |
| R-P0-2 | **PurePageContentVC不响应主题切换** | viewWillAppear仅设置背景色，不刷新文字颜色 | 用户切换主题后，阅读页文字颜色不跟随 |
| R-P0-3 | **翻页回创建新VC，无缓存** | getViewControllerAtPath每次new | 内存压力下可能OOM，尤其10卷经文频繁翻页 |
| R-P0-4 | **主题切换时cell入场动画重播** | cellForRowAt: alpha=0 + animate | 切换主题时所有文字闪一下再渐入，视觉抖动 |
| R-P0-5 | **3套进度存储互不感知** | lastReadPath/lastReadPageIndex/lastReadChapter | 从不同入口进入，进度恢复到错误位置 |
| R-P0-6 | **续读按钮视觉权重过低** | 32pt高(<HIG 44pt)，灰色小字，底部不起眼 | 用户不知道有续读功能 |
| R-P0-7 | **导航返回闪烁** | PageVC返回时，首页需要重建 | 可感知的白色闪烁 |
| R-P0-8 | **SutraPageVC.viewDidLoad的index!可能崩溃** | 第63行 | pageIndex越界时闪退 |

### 2.3 P1 — 重要体验问题

| ID | 发现 | 位置 | 建议 |
|----|------|------|------|
| R-P1-1 | **openContent是死代码** | 仅SutraFrontVC第944行有一份（报告原称两个VC各一份有误），无任何调用方 | 可删除 |
| R-P1-2 | **continueReading创建PageVC可能崩溃** | FrontVC:831-865行 | 添加安全检查 |
| R-P1-3 | **首页禁用tap/swipe手势** | FrontVC:101-102行 | 仅在FrontVC显示时禁用，离开时恢复 |
| ~~R-P1-4~~ | ~~分享功能不一致~~ | ✅**已验证不存在**：SutraPageVC(第130行)和SutraPurePageVC(第193行)均已使用`SutraCardRenderer.shareCard()`卡片分享 | ~~无需修复~~ |
| ~~R-P1-5~~ | ~~PurePageVC返回nil时调close()~~ | ✅**已验证不存在**：PurePageVC第238行仅`return nil`，不调用close()（SutraPageVC才调） | ~~无需修复~~ |
| R-P1-6 | **Cell排版参数硬编码** | lineHeightMultiple 1.8, kern 1.5等 | 提取到SutraReadingTokens常量 |
| R-P1-7 | **searchView键盘遮挡** | SearchView.swift | 添加键盘避让 |

### 2.4 P2 — 优化建议

| ID | 发现 | 建议 |
|----|------|------|
| R-P2-1 | **无障碍VoiceOver标签缺失** | 为经文/按钮添加accessibilityLabel |
| R-P2-2 | **Dynamic Type零支持** | 经文正文支持用户字号调节 |
| R-P2-3 | **阅读进度无时间戳** | 记录阅读时间，续读时显示"上次阅读：3小时前" |
| R-P2-4 | **无章节内搜索** | 添加「在此卷中搜索」 |
| R-P2-5 | **经文长按菜单单一** | 添加「复制经文」「搜索相关」等选项 |
| R-P2-6 | **无夜间阅读亮度提示** | 低亮度+暗色主题时建议开启亮度 |

### 2.5 排版参数记录（勿改动）

当前经文排版参数经精心调校，以下参数**不可修改**：

```swift
// SutraTableViewCell.configureWithZenStyle
lineHeightMultiple: 1.8       // 古典舒朗行高
paragraphSpacing: 24          // 段落分明停顿
firstLineHeadIndent: 2×fontSize  // 首行缩进两字
kern: 1.5                     // 字间距空灵感
textContainerInset: UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)

// 左侧金线锚点
borderLayer.frame = CGRect(x: 4, y: 16, width: 1, height: containerView.bounds.height - 32)
borderLayer.backgroundColor: decorativeGold.withAlphaComponent(0.3)
```

---

## 第三章：听经页面研究发现

### 3.1 页面架构

```
ModernAudioPlayerView (SwiftUI)
  ├── mediaPlayerBar          — 迷你播放条（当前曲目+进度+控制）
  ├── flatTrackList           — 曲目列表（ScrollView + LazyVStack）
  ├── progressBar             — 进度条（5pt高度）
  └── playModeRow             — 播放模式行（ForEach 1...3 ⚠️BUG）
      ├── AudioManager (单例) — ODR下载、播放控制、模式管理
      └── AudioPlayerObserver — Combine响应式状态桥接
```

### 3.2 P0 — 必须修复

| ID | 发现 | 位置 | 影响 |
|----|------|------|------|
| L-P0-1 | **PlayMode 8种模式全部失效** | MediaModels.swift定义了8种，但无代码在播放完成时读取PlayMode | 用户选择的播放模式完全不工作 |
| ~~L-P0-2~~ | ~~ForEach(1...3)只显示3种模式~~ | ✅**设计如此**：UI显示5种模式（单曲循环+列表循环+1/2/3次），4-6次刻意不显示 | ~~无需修复~~ |
| ~~L-P0-3~~ | ~~切歌竞态条件~~ | ✅**误报**：asyncAfter捕获queuePlayer引用而非具体曲目，快速切歌时removeAllItems保证最新曲目正确播放，0.1s延迟是为等AVPlayer准备 | ~~无需修复~~ |
| L-P0-4 | **SwiftUI主题切换可能不即时响应** | ModernAudioPlayerView使用`SutraDesignTokens.shared.color(for:)`动态Token，但无`@ObservedObject`/`.onReceive(.themeDidChange)`绑定触发重渲染 | 主题切换后，若其他状态变化触发body重绘则颜色会更新，否则不更新 |
| L-P0-5 | **下载模拟进度与真实脱节** | AudioManager Timer 0.1s + 0.05增量 | 进度条到100%但文件还没下完 |
| ~~L-P0-6~~ | ~~resourceRequests成功后未释放~~ | ✅**误报 — 故意保持**：听经音频需反复播放，endAccessingResources会导致系统回收资源、用户需重新下载。错误路径释放是正确的 | ~~无需修复~~ |
| L-P0-7 | **锁屏/控制中心信息可完善** | playbackRate已存在(AudioPlayerObserver第150行)，artwork使用AppIcon而非内容封面 | 可添加经文章节封面图，丰富锁屏展示 |

### 3.3 P1 — 重要体验问题

| ID | 发现 | 位置 | 建议 |
|----|------|------|------|
| L-P1-1 | **进度条触摸目标不足** | 5pt高度远低于HIG 44pt | **视觉保持5pt，隐形扩大触摸区域到44pt** |
| L-P1-2 | **状态机"PLAYING"是死胡同** | AudioPlayerObserver只映射rate>0为isPlaying | 无法区分"用户暂停"和"缓冲中"，UI状态混乱 |
| L-P1-3 | **底部padding硬编码220pt** | ModernAudioPlayerView | 实际只需~100pt，造成大量空白浪费 |
| L-P1-4 | **resumeLastPlayback不恢复位置** | AudioManager:88-104行 | 只恢复曲目名，从0开始播放 |
| L-P1-5 | **无音频中断处理** | 缺失AVAudioSession中断通知监听 | 来电后音乐不恢复 |
| L-P1-6 | **无播放速度控制** | — | 长按播放按钮弹出速度选择 |
| L-P1-7 | **无睡眠定时器** | — | 收纳到"..."菜单 |
| L-P1-8 | **当前曲目高亮与实际不同步** | flatTrackList用@Published currentTrack | Combine发布者可能延迟 |
| L-P1-9 | **播放完成不自动下一曲** | 无didPlayToEndTime监听 | 必须手动点击下一曲 |
| L-P1-10 | **无断点续播** | — | 添加PlaybackState持久化 |

### 3.4 P2 — 优化建议

| ID | 发现 | 建议 |
|----|------|------|
| L-P2-1 | **锁屏/控制中心交互** | 添加前进/后退15秒按钮 |
| L-P2-2 | **无播放历史** | 记录听经历史，支持回听 |
| L-P2-3 | **无章节内曲目列表折叠** | 长列表滚动效率低 |
| L-P2-4 | **CarPlay不支持** | 添加CarPlay场景 |
| L-P2-5 | **音频EQ预设** | 提供"人声增强"模式 |
| L-P2-6 | **无播放完成统计** | 记录"已听X遍" |

### 3.5 播放状态机参考

```
当前（有缺陷）:
  IDLE → PLAYING → ?（死胡同，无出口）

理想:
  IDLE → LOADING → PLAYING ⇄ PAUSED
                  ↓           ↑
              BUFFERING ──────┘
                  ↓
              ENDED → (下一曲/停止)

中断处理:
  PLAYING → INTERRUPTED → PLAYING (自动恢复)
  PLAYING → INTERRUPTED → PAUSED (用户挂断)
```

### 3.6 进度条交互规格（美学安全版）

```
视觉层: 5pt高度，decorativeGold 12% 背景 → 100% 填充
触摸层: 上下各扩展 20pt，总触摸目标 45pt (> HIG 44pt)
拖拽手势: Horizontal drag, 最小移动 2pt
实时反馈: 拖拽时显示时间气泡（sutraCaption字体，9pt圆角）
松手: 无动画跳转，即刻 seek
```

---

## 第四章：跨页面一致性问题

### 4.1 主题切换链完整性审查

| 视图 | 背景 | 文字 | 导航栏 | 状态 |
|------|------|------|--------|------|
| SutraFrontViewController | ✅ | ✅ | ✅ | 完整 |
| SutraPageContentViewController | ✅ | ✅ | ✅ | 完整 |
| SutraPurePageViewController | ✅ | ✅ | ✅ | 完整 |
| **SutraPurePageContentViewController** | ✅ | ❌ | — | **不刷新文字颜色** |
| ModernAudioPlayerView (SwiftUI) | ⚠️ | ⚠️ | — | **使用动态Token但无响应式绑定，依赖其他状态变化触发重绘** |
| SearchView | ✅ | ✅ | — | 完整 |

### 4.2 分享功能一致性

> ✅ **已验证：分享功能已统一**。以下两项均已使用 `SutraCardRenderer.shareCard()` 卡片分享：
> - `SutraPageViewController.share()`（第130行）
> - `SutraPurePageViewController.share()`（第193行）

| 入口 | 分享方式 | 是否使用卡片 |
|------|----------|-------------|
| SutraPageVC → share() | SutraCardRenderer卡片 | ✅ |
| SutraPurePageVC → share() | SutraCardRenderer卡片 | ✅ |
| ModernWisdomView → "进入经文深读" | 跳转，不分享 | — |

### 4.3 进度持久化统一

当前3套独立进度：
```
1. lastReadPath + lastReadMode="tree"        → PurePageVC使用
2. lastReadPageIndex                          → PageVC使用
3. lastReadChapter + lastReadChapterOffset    → ReaderVC使用
```

**建议**: 统一为 `UnifiedReadingProgress` 模型：
```swift
struct UnifiedReadingProgress {
    let path: String           // 科判路径
    let mode: ReadingMode      // .tree / .scroll / .continuous
    let offset: CGFloat        // 滚动位置
    let timestamp: Date        // 时间戳
}
```

---

## 第五章：4阶段实施路线图

### Phase 0 — 紧急修复（4-6天）

> 原则：只修Bug，不动视觉。所有改动对用户不可见。

| 任务 | 类型 | 风险 | 工时 |
|------|------|------|------|
| ~~修复5处force unwrap~~ | ~~安全~~ | ✅**实际不会触发**，VC传值契约保证 | ~~0.5d~~ |
| ~~修复ForEach(1...3) → 1...6~~ | ~~Bug~~ | ✅**设计如此** | ~~0.5d~~ |
| 实现PlayMode播放完成逻辑 | 功能 | 🟢无美学风险 | 1d |
| ~~修复切歌竞态(asyncAfter)~~ | ~~安全~~ | ✅**误报**，queuePlayer引用保证正确性 | ~~0.5d~~ |
| PurePageContentVC主题响应 | 一致性 | 🟢美学正向 | 0.5d |
| 移除死代码(openContent等) | 清理 | 🟢无美学风险 | 0.5d |
| 修复下载模拟进度 | 功能 | 🟢无美学风险 | 0.5d |
| ~~resourceRequests释放~~ | ~~内存~~ | ✅**误报**，听经音频需反复播放，故意保持 | ~~0.5d~~ |

### Phase 1 — 基础设施（10-14天）

> 原则：架构改进，视觉不变。

| 任务 | 类型 | 风险 | 工时 |
|------|------|------|------|
| 音频状态机重构 | 架构 | 🟢无美学风险 | 2d |
| 添加音频中断处理 | 功能 | 🟢无美学风险 | 1d |
| 锁屏/控制中心封面图完善 | 功能 | 🟢无美学风险 | 1d |
| SwiftUI主题响应式绑定 | 一致性 | 🟢美学正向 | 1d |
| 统一进度模型 | 数据 | 🟢无美学风险 | 2d |
| 主题切换cell动画优化 | 体验 | 🟢美学正向 | 1d |
| 断点续播PlaybackState | 功能 | 🟢无美学风险 | 1d |
| 进度条触摸扩大（视觉不动） | 交互 | 🟡需验证 | 0.5d |

### Phase 2 — 体验提升（14-20天）

> 原则：微调交互，克制添加。

| 任务 | 类型 | 风险 | 工时 |
|------|------|------|------|
| 续读按钮微升（字号+颜色） | 视觉 | 🟡需验证 | 0.5d |
| ~~分享功能统一为卡片~~ | ~~一致性~~ | ✅**已完成** | ~~1d~~ |
| 播放速度控制（长按入口） | 功能 | 🟡收纳式设计 | 1.5d |
| 睡眠定时器（菜单入口） | 功能 | 🟡收纳式设计 | 1.5d |
| 经文VoiceOver标签 | 无障碍 | 🟢无美学风险 | 1d |
| 搜索页键盘避让 | 交互 | 🟢无美学风险 | 0.5d |
| 首页手势管理优化 | 交互 | 🟢无美学风险 | 0.5d |

### Phase 3 — 差异化（20-28天）

> 原则：锦上添花，绝不画蛇添足。

| 任务 | 类型 | 风险 | 工时 |
|------|------|------|------|
| 阅读进度时间戳 | 数据 | 🟢无美学风险 | 0.5d |
| 章节内搜索 | 功能 | 🟢无美学风险 | 1d |
| 锁屏前进/后退15秒 | 功能 | 🟢无美学风险 | 1d |
| Dynamic Type（仅经文） | 无障碍 | 🟡需验证 | 2d |
| 播放历史 | 功能 | 🟢无美学风险 | 1d |
| 3VC→2VC架构统一 | 架构 | 🟡需大量验证 | 3d |

---

## 第六章：关键设计规格

### 6.1 不应修改的设计参数

以下参数经过精心调校，是App美学的基石：

**色彩（三套主题色温完美一致）**
- 宣纸白 #FAF8F3 → 古籍茶 #F2E8D5 → 禅房深檀 #1C1814
- 经文墨 #0D0D0D → 古墨棕 #1A100A → 暖白 #E8DFD0
- 禅竹绿 #228B22 → 暖竹 #5B7A4A → 暮竹 #7A9B68
- 装饰金 #C4A265 → 古金 #B8976A → 暗金 #B89860

**排版（黄金比例 + 光学尺寸）**
- 行高倍数：1.8（古典舒朗）
- 段落间距：24pt
- 首行缩进：2×fontSize
- 字间距：1.5pt（经文）/ 0.5pt（标题）
- 卡片内距：28pt
- 内容边距：24pt

**动效（有机自然）**
- 主题切换：0.3s交叉溶解
- 按钮按压：Spring(damping:0.8, response:0.4)
- Cell入场：0.35s + 递增delay（**仅首次加载，主题切换时不触发**）
- 进度条：0.3s移动+淡入

### 6.2 允许的微调范围

| 参数 | 当前值 | 允许范围 | 条件 |
|------|--------|----------|------|
| 续读按钮字号 | 14pt | 14-16pt | 不超过开经偈字号 |
| 续读按钮颜色 | textTertiary | textSecondary最高 | 不超过章节标题色值 |
| 进度条视觉高度 | 5pt | 4-6pt | 不改变，仅扩大触摸区 |
| 播放条高度 | 自适应 | 自适应 | 不改变 |

---

## 附录A：崩溃点精确清单

| 文件 | 行号 | 代码 | 修复方案 |
|------|------|------|----------|
| SutraPurePageContentVC | ~27 | `path!` (viewDidLoad) | `guard let path = path else { return }` |
| SutraPurePageContentVC | ~29 | `item!["path"]! as! String`（else分支，item非nil但`["path"]!`仍为force） | `guard let p = item["path"] as? String else { return }` |
| SutraPurePageVC | ~220 | `viewController as! SutraPurePageContentVC` | `guard let pageContent = viewController as? SutraPurePageContentVC else { return nil }` |
| SutraPageVC | ~63 | `index!` | `guard let index = index else { return }` |
| SutraFrontVC | ~937 | `openContent` force unwrap | 删除死代码 |
| AudioManager | ~256 | `asyncAfter` 竞态 | 改用 `DispatchWorkItem` 取消前一个 |

## 附录B：播放模式伪代码修复

```swift
// AudioManager - 播放完成回调
func setupPlaybackCompletion() {
    NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.handlePlaybackCompletion()
    }
}

func handlePlaybackCompletion() {
    let mode = currentPlayMode // 读取用户选择的模式

    switch mode {
    case .repeatAll:   playNextTrack()
    case .repeatOne:   replayCurrentTrack()
    case .playOnce:    stop()
    case .playNTimes:  // 递减计数器，到0停止
        decrementPlayCount()
        if playCount > 0 { replayCurrentTrack() }
        else { stop() }
    }
}
```

## 附录C：主题切换修复方案

### PurePageContentViewController（UIKit）

```swift
// 在viewWillAppear中监听主题切换
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    NotificationCenter.default.addObserver(
        self, selector: #selector(themeDidChangeEvent),
        name: .themeDidChange, object: nil
    )
    applyCurrentTheme()
}

@objc private func themeDidChangeEvent() {
    applyCurrentTheme()
    // 不重置滚动位置，不重播动画
}

private func applyCurrentTheme() {
    sutraView?.backgroundColor = SutraDesignTokens.shared.color(for: .background)
    sutraView?.textColor = SutraDesignTokens.shared.color(for: .sutraText)
    view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
}
```

### ModernAudioPlayerView（SwiftUI）

```swift
// 方案A：使用@ObservedObject观察主题变化
@ObservedObject var themeObserver = ThemeObserver.shared

// 在body中依赖themeObserver触发重绘
var body: some View {
    let _ = themeObserver.currentTheme // 依赖触发
    // ... 现有代码不变
}

// 方案B：将Color包装为响应式
// 在SutraDesignSystem中提供响应式Color
```

---

> **结语**
>
> 这份研究的目的不是否定现有设计，而是找出那些「不一致」——因为对楞严经App来说，**不一致是最大的美学破坏**。
>
> 真正需要改动的只有三类：
> 1. **让崩溃消失** — 用户不应在读经时被打断
> 2. **让一致完整** — 主题切换、分享、进度应全线贯通
> 3. **让沉默的功能说话** — PlayMode已经定义了8种但一个都没实现
>
> 其余的，都是在这座数字古刹中，轻轻拂去灰尘，而非翻修重建。
