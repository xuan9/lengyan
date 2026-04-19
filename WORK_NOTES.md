# 工作经验总结

## 一、设计铁律

### 1. 信息元素不加透明度

文字、图标、按钮 = 承载信息 → **用原色，不加 opacity**。

| 元素 | opacity | 原因 |
|------|---------|------|
| 文字/图标/按钮 | 不用 | 承载信息，必须清晰 |
| 分隔线/装饰纹 | 可以 | 不承载信息 |
| 背景/遮罩 | 可以 | 氛围层 |

加了 opacity 就削弱对比度，削弱对比度就降低可读性。每一处 opacity 都在让用户更难看清楚。

### 2. 两个文字色就够，不需要三个

文字层级：`textPrimary`（正文）+ `textSecondary`（次要）。

不要 `textTertiary`。理由：
- 在暖色底上对比度不够
- 诱惑开发者叠加 opacity → 双重变淡
- 层级区分用字号、字重、位置，不需要第三个颜色

### 3. 一个强调色贯穿全 App

选定一个强调色（竹绿 #228B22），所有页面的标题、图标、选中态、开关、分隔线标题统一用这个色。

不要散落第二种强调色。多一个强调色 = 多一个不一致的可能。

例外：装饰性金色可保留于致谢页等极少数场景。

### 4. 用系统控件，不造轮子

- 时间选择：用 `DatePicker(.compact)`，不自己拼两个 Wheel
- compact DatePicker 收起只占一行，点击弹出原生拨盘
- 自定义 Wheel 占空间、位置突兀、触控敏感

### 5. 文字层级靠字号/字重/位置，不靠颜色深浅

| 层级手段 | 推荐 |
|---------|------|
| 字号差异 | 最有效 |
| 字重差异 | 辅助 |
| 位置/留白 | 强大 |
| 颜色深浅 | **尽量不用**，只用两级 |

### 6. Tab Bar 统一用 SF Symbols

- 图标：全部用 `UIImage(systemName:)` + `.withConfiguration`
- 不要混用自定义图片，风格不统一
- 字号 10pt，字重 `.thin`
- 未选中：`textTertiary` 色，选中：`primary` 色

### 7. Header 设计：纯文字 + 大字距 + 底部细线

- 去掉 icon（Tab Bar 已有，header 重复是冗余）
- tracking 20pt 拉开字距，如经卷章节标题
- 底部加一道 60pt 宽的极细线（`primary.opacity(0.15)`）
- 留白才是庄严感的来源

### 8. 收藏卡片设计要点

- 左侧竖线：实体纯色（不要渐变），用 primary 色
- 内容字号：同首页科判（uiBody = 18pt），不要用阅读页字号（sutraBody = 24pt）
- 出处经名：textSecondary（承载信息，不用最浅色）
- 背景：半透明白（Color.white.opacity(0.25)），营造通透感

### 9. 全局色板（Light 主题）

```
宣纸暖底   #FAF8F3   background
墨黑正文   #262626   textPrimary
古檀次要   #4A3728   textSecondary
竹绿强调   #228B22   primary
```

四个颜色覆盖所有场景。少即是多。

---

## 二、架构经验

### 1. View 只放 UI，逻辑提取到 Domain/Util

SwiftUI View 文件只包含：
- `body` 布局
- `private var xxx: some View` 视图组件
- UIKit 交互（如 UIAlertController）

提取规则：
| 逻辑类型 | 去向 | 示例 |
|---------|------|------|
| 数据模型 + 枚举 | `Domain/Models.swift` | MediaGroup, PlayMode |
| 播放/下载管理 | `Domain/Manager.swift` | AudioManager, AudioPlayerObserver |
| 通知调度 | `Domain/ReminderManager.swift` | UNUserNotificationCenter |
| 导航/外部链接 | `Util/NavigationHelper.swift` | pushSwiftUIView, openEmail |
| 时间格式化等工具 | Manager 的 static 方法 | AudioManager.formatTime() |

### 2. ObservableObject 替代 @State 管理复杂状态

当一个 View 有 5+ 个 `@State` 且有复杂业务逻辑时，提取为 `ObservableObject`：

```swift
// ❌ 胖 View：@State + 业务逻辑混在一起
struct XxxView: View {
    @State private var items: [Item] = []
    @State private var isLoading = true
    @State private var downloadStatus: [String: Status] = [:]
    // ... 400 行业务方法
}

// ✅ 瘦 View + Manager
struct XxxView: View {
    @ObservedObject var manager = XxxManager.shared
    // 只有 UI 布局
}

class XxxManager: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = true
    // 业务方法在这里
}
```

### 3. pbxproj 添加文件的可靠方法

用 Python `pbxproj` 库：

```bash
pip install pbxproj   # 需要 venv
```

```python
from pbxproj import XcodeProject

project = XcodeProject.load('lengyan.xcodeproj/project.pbxproj')
project.add_file('lengyan/Domain/NewFile.swift', target_name='lengyan')
project.save()
```

**注意**：`add_file` 会把文件放到根 group，需要手动移到正确 group：
- 从根 group 的 children 中移除文件引用
- 在目标 group 的 children 中添加文件引用
- 确保 PBXFileReference、PBXBuildFile、PBXGroup 三处都正确

### 4. Xcode build 命令

```bash
# 不签名编译（快速验证）
xcodebuild build -project lengyan.xcodeproj -scheme lengyan \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/lengyan_build \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 模拟器编译+安装
xcodebuild build -project lengyan.xcodeproj -scheme lengyan \
  -destination 'id=<DEVICE_ID>' \
  -derivedDataPath /tmp/lengyan_build
```

---

## 三、性能经验

### 1. 收藏页首次加载优化

**根因**：`extractContentEfficiently()` 调用 `getSutra(item)` 时 `maxLength` 默认 `Int.max`，递归拼接全部子节点经文，然后只取前 50 字符。

**修复**：一行改动，`getSutra(item)` → `getSutra(item, maxLength: 80)`

**教训**：如果只需要预览文本，务必在数据源层就截断，不要先取全量再截取。

### 2. FavoritesCache 缓存策略

- 5 分钟内存缓存，避免重复加载
- 收藏变更时自动 invalidate
- 首次加载的瓶颈不在缓存，而在 `getSutra()` 的全量调用

---

## 四、构建工具

### 一键编译安装脚本

```bash
./scripts/build_and_install.sh              # 自动选择已启动的模拟器
./scripts/build_and_install.sh <设备ID>     # 指定设备
```

脚本功能：编译 → 安装 → 启动，失败时显示错误详情。

---

## 五、Git 工作流

### Commit 风格

一行标题说明改动，不要啰嗦。用英文动词开头：

```
Extract non-UI logic from SwiftUI views into Domain/Util layers
Optimize favorites first-load: use getSuta(item, maxLength: 80)
Remove front page acknowledgments button and unify tab icons to SF Symbols
```

### 改动粒度

一次 commit 聚焦一个主题：
- 重构 → 一个 commit
- 性能优化 → 一个 commit
- UI 调整 → 一个 commit

不要把不相关的改动混在一个 commit 里。
