# Android 多经典产品移植与长期开发计划

**日期：** 2026-07-26\
**版本：** v4（结合 iOS 音频清单、播放恢复、Widget 和 UI 稳定性基线复核后）\
**状态：** Android 实施前决策稿\
**适用产品：** 《楞严经》《金刚经》《圆觉经》《六祖坛经》及后续单经产品\
**开发模式：** Codex 主导代码、测试、文档和自动化；人工负责经文、权利、密钥与正式发布批准

### 文档职责

本文件只负责 Android 原生架构、移植行为、设备测试、Play/非 Play 分发和 Android 阶段计划。跨平台仓库、`Products/`、`Contracts/`、音频 artifact、统一命令、Codex/Git 治理和产品顺序由 `.planning/AI_MULTI_PRODUCT_ENGINEERING_PLAN.md` 负责；产品价值与完整周期由 `.planning/MAHAYANA_PRODUCT_PLANS.md` 负责。

若共享决策冲突，以跨平台主计划为准。进入实施后，已接受的 Android ADR、Gradle 配置、测试和脚本取代本文件相应段落。本文件不能成为第二套 schema、目录或命令配置。

## 1. 最终建议

Android 版本可以实施，也应从第一天按多经典产品建设。推荐方案是：

1. **继续使用同一个 Git monorepo。** 在现有仓库增加 `android/`，iOS、Android、产品内容、校验工具和发布文档处于同一提交历史中。
2. **每部经典是一个独立 App 模块。** 《楞严经》《金刚经》《圆觉经》《六祖坛经》分别拥有永久包名、商店页面、图标、组件、版本和发布节奏，不做一个包含多本书的大书架。
3. **Android 使用原生 Kotlin + Jetpack Compose。** 不把 Swift UI 逐像素翻译，也不在第一阶段采用 Flutter、React Native、Compose Multiplatform 或 Kotlin Multiplatform。
4. **Android 产品共用一组库模块。** 内容、数据、阅读、音频、分享、设计系统和组件能力只实现一次；稳定差异来自产品配置，真正独特页面保留在薄 App 模块。
5. **跨平台共享数据和行为契约，不强行共享 UI/runtime 代码。** iOS 与 Android 共用 `ProductManifest`、经文源数据、稳定 ID、来源清单、音频清单、深链格式和 golden test fixtures。
6. **正文始终随 App 离线可用；完整音频通过 HTTPS 交付配置按需准备。** Android 使用 Media3 后台下载/播放，复现“当前卷优先、下一卷受控预取、失败可恢复”的产品语义；不把 Google Play Asset Delivery 或现有楞严 `workers.dev` 应急源作为主方案。
7. **先完成《楞严经》Android 作为金标准，再接《金刚经》。** 第二款真实产品用于验证共享架构；不要同时复制四个半成品工程。
8. **AI 开发必须由机器可验证的合同约束。** 干净克隆构建、单元测试、内容校验、UI 测试、截图、真机音频测试和发布检查必须真实执行，禁止占位成功。

推荐顺序：

```text
楞严经 Android 基准版
  -> 金刚经（验证第二产品复用）
  -> 圆觉经（较快扩展）
  -> 六祖坛经（结构、注释和内容治理更复杂）
```

## 2. 目标和非目标

### 2.1 第一阶段目标

- 《楞严经》Android 达到当前 iOS 核心功能的生产级等价，而不是演示版。
- 建立可在几周内接入新经典的共享 Android 平台。
- 保留单经、安静、离线优先、无账户、无广告的产品定位。
- 从首版就支持后台听经、离线音频、系统媒体控制、桌面组件、提醒、分享、简繁体、无障碍和大字体。
- 让 Codex 能在新会话和干净工作区中，仅依赖仓库文档与脚本可靠继续开发。
- 同一经文修订和行为规则能同时被 iOS、Android 校验，避免平台内容漂移。

当前仓库没有 Android/Gradle/Kotlin 工程，因此这里是原生 Android 从零建设与行为移植计划，不是继续维护一个现存 Android prototype。旧 iOS 代码用于提取行为基线，不作为可复制的 Android 架构。

### 2.2 明确不做

- 不先做一个包含多部经典的“大藏经”App。
- 不为“代码共享率”牺牲 Android 原生体验。
- 不在首版引入账户、云同步、社交、广告或分析 SDK。
- 不把 Firebase、Google Play Services 或 Play Asset Delivery 作为核心功能依赖。
- 不请求精确闹钟权限来实现普通每日提醒。
- 不把大型音频二进制继续提交进 Git。
- 不允许 AI 自行改写经文、判断授权、创建或接触生产签名密钥、直接发布正式版本。
- 不把 iOS 已有布局问题和偶然实现细节当作需要移植的需求。

### 2.3 2026-07-26 iOS 新基线对 Android 的影响

7 月 19–26 日提交不改变原生 Android、多 App module 和共享 contract 的总方向，但前移了音频数据治理，并提供了更强的行为 oracle：

- iOS 已有 backend-neutral `AudioAssetProvider`、lease 和 coordinator；Android 不复制 Swift/ODR/Background Assets 代码，但应复用同一 audio ID、状态语义和故障 fixtures。
- 当前可观察语义是：A 播放期间请求 B 不提前中断 A；当前卷完整可用后原子切换；下一卷只维持一个预取；用户点中预取卷时提升同一任务；迟到结果不能抢占新选择。
- Apple primary 明确失败或 15 秒无进展时，只有用户主动播放才进入 Cloudflare fallback；取消、本机空间不足和静默预取失败不得触发公网回退。
- 当前 Cloudflare Static Assets 会忽略 Range 并返回完整文件，且没有中国大陆 SLA。其 content-addressed key 与 bytes/SHA-256 校验可以复用，host 和下载实现不能作为 Android 主链路。
- 当前 `AudioAssets/audio-manifest.json` 已单源生成 17 个楞严 Swift/Node/Apple 产物并接入 CI 检查；Android 不再参与“消除四份手工 catalog”这一步，但也不能直接消费仍含 Apple/CDN/source path 的现行交付 catalog。Gate F2 仍需把它演进为跨产品 artifact schema 与 Android delivery config。
- iOS 已取消技术性的音频存储设置页，改为按需准备和自动缓存/清理；其 fallback 当前无容量上限、按 28 天未访问淘汰，11 条全部缓存约 154MiB。这是现状而非 Android requirement，Phase 0 必须明确 Data Saver/Wi-Fi、单产品与全局 cache budget、清理和可选 pin。
- 冷启动续播现在会即时持久化并保护异步 seek；Android 必须把“同一卷在进程重建后恢复且不会被初始 0 覆盖”加入 Media3 fixture 和杀进程测试。
- 目录 disclosure state 现在还会跨重启持久化；Android 使用稳定 node ID 和产品命名空间保存，内容升级时过滤失效节点。
- iPad split-detail 底部布局、取消当前收藏后保留详情、快速主题切换不白屏/黑屏、Widget 语义截断和长段不裁字已有自动测试；Android parity matrix 应描述用户结果，不逐像素复制 UIKit/WidgetKit。

## 3. 为什么是一个仓库、多个 App 模块

### 3.1 一个 monorepo 的收益

- 经文、音频清单和内容修订只有一个权威来源。
- Android 共享播放器或阅读器修复一次覆盖该平台全部产品；共享 schema/fixture 变更才要求一次 PR 同时验证两个平台。
- Codex 能同时看到 schema、生成器、调用端和测试，不需要猜测另一个仓库的版本。
- CI 能根据依赖关系判断需要验证哪些 App，减少漏测。
- 架构决策、发布规则和内容治理不会在八个独立仓库中逐渐分叉。

### 3.2 每部经典使用独立 Android App 模块

建议使用：

```text
:apps:lengyan
:apps:jingang
:apps:yuanjue
:apps:tanjing
```

而不是把经典做成 Gradle product flavors。独立模块更适合永久包名、不同商店资料、独立发布节奏、差异化 Widget 和未来产品专有功能；共享 convention plugin 可以消除构建配置重复。

产品与分发渠道是两个维度：

- **产品差异：** 独立 App 模块。
- **渠道差异：** 默认不分 flavor；只有某个商店确实要求不同 SDK 或配置时，才增加受控的 `distribution` flavor。

同一产品在不同商店应尽量保持相同 `applicationId` 和同一 App signing key，保证升级路径连续。

### 3.3 现在不采用 KMP 的原因

首版真正可稳定共享的是内容与规则，不是平台运行时：iOS 使用 AVFoundation、WidgetKit 和 UIKit/SwiftUI，Android 使用 Media3、Glance 和 Compose。过早引入 KMP 会增加 Gradle/Xcode 互操作、并发、资源和调试复杂度，却不能消除最困难的平台工作。

只有同时满足以下条件才重新评估 KMP：

- 两个平台均已发布并稳定维护。
- 至少两款产品证明搜索、进度、清单解析等纯逻辑长期重复。
- 共享逻辑已有跨平台 fixtures，边界清晰且不依赖 UI、媒体或存储框架。
- 小型试验能证明构建、调试和发布成本确实下降。

即使采用 KMP，也只考虑纯模型和算法；UI、播放器、Widget 和系统集成继续原生。

## 4. 目标仓库结构

根目录结构以跨平台主计划为准，本文件只列 Android 直接拥有或消费的部分，避免两份完整树长期漂移：

```text
lengyan-app/
├── android/
│   ├── AGENTS.md
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   ├── gradlew
│   ├── gradle/
│   │   ├── libs.versions.toml
│   │   └── verification-metadata.xml
│   ├── build-logic/                   # convention plugins
│   ├── apps/
│   │   ├── lengyan/
│   │   ├── jingang/
│   │   ├── yuanjue/
│   │   └── tanjing/
│   ├── libraries/
│   │   ├── core/
│   │   ├── data/
│   │   ├── ui/
│   │   ├── media/
│   │   └── widget/
│   └── benchmark/
├── Products/
│   ├── lengyan/
│   │   ├── product.json
│   │   ├── book-manifest.json
│   │   ├── Content/
│   │   ├── Localizations/
│   │   ├── audio-manifest.json
│   │   ├── SOURCE_MANIFEST.yml
│   │   ├── StoreMetadata/
│   │   │   ├── ios/
│   │   │   └── android/
│   │   └── Platform/
│   │       ├── ios/
│   │       └── android/
│   ├── jingang/
│   ├── yuanjue/
│   └── tanjing/
├── Contracts/                         # 跨平台 fixtures 和 schema
│   ├── Schemas/
│   └── BehaviorFixtures/
├── tools/                             # 当前仓库已使用小写，禁止再建 Tools/
├── scripts/
│   ├── bootstrap.sh
│   ├── validate-content.sh
│   ├── verify.sh                      # 唯一公共入口
│   └── verify-android.sh              # verify.sh 的内部实现
└── docs/android/
```

Android 建设不先移动现有 iOS 文件。Gate F2 后只增加 `android/` 和 Android 所需生成 adapter；canonical schema、内容和 fixtures 继续由根目录共享，Gradle task 只把产物写入 build/generated 目录。

## 5. Android 技术基线

### 5.1 截至 2026-07-26 的约束

- Google Play 从 **2026-08-31** 起要求手机和平板的新 App 与更新以 Android 16 / API 36 或更高为 target，因此项目从建立时就使用 `targetSdk = 36`，不先建立一个即将过期的 API 35 基线。[Google Play target API 要求](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-be)
- `compileSdk` 同样使用 36；以后由一处版本目录集中升级。
- `minSdk = 26` 作为建议基线，可降低旧后台限制、通知、字体和媒体兼容成本。创建正式包名前，必须根据目标用户设备和大陆渠道数据做一次确认；若 API 23-25 仍有明确价值，再以真实测试决定是否降低。
- 使用最新稳定版 Android Gradle Plugin、Kotlin、Compose BOM、Navigation 和 Media3，但**实施时查询并固定精确版本**，不使用 `+` 或动态版本。
- 使用 Gradle Kotlin DSL、Version Catalog、Wrapper、dependency verification 和 dependency locking；提交 lockfiles，只有单独的依赖升级 PR 可以用 `--write-locks`/受控校验命令更新它们。

### 5.2 UI 和应用架构

采用 Android 官方当前建议的 Compose、单 Activity、分层数据访问、协程/Flow 和单向数据流。[Android architecture recommendations](https://developer.android.com/topic/architecture/recommendations)

建议组合：

- Kotlin。
- Jetpack Compose + Material 3，但以本项目设计 token 控制视觉，不直接接受默认主题作为成品。
- 单 `MainActivity`。
- Navigation 3；该库已进入稳定版，实施时固定当期稳定版本。路由必须是可序列化、可测试的类型，而不是散落字符串。[Navigation 3 releases](https://developer.android.com/jetpack/androidx/releases/navigation3)
- Screen-level `ViewModel` + immutable UI state + `StateFlow`。
- Repository 作为 UI 与数据源的唯一边界。
- Kotlin coroutines，磁盘、解析、图片和音频任务不得阻塞主线程。
- 首版使用小型 constructor injection / `AppContainer`，不为了模板完整立即加入 Hilt；当对象图和测试替换明显失控时再 ADR 评估。

### 5.3 模块职责

**`:libraries:core`**

- 产品、书、卷、章、段落、稳定 ID、深链和纯领域模型。
- Product/audio manifest 解析接口。
- 搜索规范化、每日经句选择、续读解析、分享文件名等纯逻辑。
- 不依赖 Compose、Media3、Room 或 Android `Context`，以便快速 JVM 测试。

**`:libraries:data`**

- 内容资源加载、schema/version 校验和 repository 实现。
- DataStore 设置、阅读进度和轻量状态。
- Room 首版收藏及其 migrations；笔记/历史仅在产品范围批准后增加。
- 内容更新兼容和 legacy ID 映射。

**`:libraries:ui`**

- 设计 token、导航壳、首页、目录、阅读、搜索、收藏、设置和分享预览。
- 自适应手机、平板和折叠屏布局。
- 产品专属页面通过稳定 slot/config 接入，不在共享页面判断产品名称。

**`:libraries:media`**

- Media3 Player、MediaSessionService、播放队列、续播、倍速、睡眠定时。
- 离线下载、缓存、资源校验、网络和存储策略。
- UI 仅观察稳定 playback state，不直接操作 ExoPlayer。

**`:libraries:widget`**

- Glance Widget 共享 UI、数据编码、尺寸策略和深链。
- 每款 App 模块注册自己的 receiver、文案和资源。

**`:apps:<product>`**

- `applicationId`、产品资源、入口、manifest、商店差异和少量产品专属功能。
- 不复制通用 Screen、repository、播放器或分享实现。

初期保持上述五个共享模块，不按每个页面拆 module。只有构建时间、依赖边界或多团队并行确实需要时才继续拆分。

## 6. 产品配置和稳定身份

### 6.1 三类身份必须分开

- **内容身份：** `productID`、`editionID`、`contentVersion`、stable paragraph ID。
- **Android 构建身份：** `applicationId`、签名 key alias、versionCode、deep-link host。
- **商店身份：** Play app、各大陆商店 app ID、展示名称、截图和隐私资料。

`product.json` 保存跨平台运行时配置，不保存证书、密码或签名设置。Android 构建身份位于产品平台配置中，密钥只存在于外部秘密管理和离线备份。

### 6.2 包名和签名必须在首个商店构建前锁定

Google Play 包名一旦使用就应视为永久，不能把占位包名上传后再改。建议格式仅作为讨论示例：

```text
org.<publisher>.lengyan
org.<publisher>.jingang
org.<publisher>.yuanjue
org.<publisher>.tanjing
```

最终 publisher namespace 需要人工一次性批准。每款产品建议使用独立 app-signing key，减少单个密钥泄露影响；同时使用独立、可轮换的 upload key。若计划在 Play 外分发，应由发布者生成并保管 app-signing key，再按 Play App Signing 流程使用，以便非 Play APK 保持相同签名。[Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-GB)

### 6.3 独立版本

- 每个 App 独立维护单调递增的 `versionCode`。
- `versionName` 面向用户，可使用 `major.minor.patch`。
- Git tag 使用 `android/<product>/vX.Y.Z`。
- 共享模块不单独发布到 Maven；monorepo 原子提交保证一致性。
- 内容版本与 App 版本分开，任何内容修订都在 manifest 和修订日志中可追踪。

## 7. 跨平台内容与契约

### 7.1 一个权威内容源

不能让 Android 复制一份 iOS JSON 后独立修改。正确流程是：

```text
Products/<product>/Content + product/audio/source manifests
        |
        v
跨平台内容校验器与生成器
        |
        +--> iOS bundle artifacts
        +--> Android generated assets/resources
        +--> shared behavior fixtures
```

生成任务把结果写入 build 目录，不把重复生成文件随意写回源码目录。每个构建均校验：

- schema 版本和必填字段。
- UTF-8/NFC、换行/空白和确定性序列化规则；独立 validator、iOS 与 Android 计算的内容 hash 必须一致。
- 目录、卷、章、段落引用完整性。
- stable ID 唯一且不能静默重用。
- 简繁文本和索引映射。
- 来源、版权/授权状态与修订记录。
- 音频卷、时长、字节数和 SHA-256。
- 产品功能开关与真实资源一致。

### 7.2 稳定段落 ID，而不是页码

页码依赖设备宽度、字体、字号和系统 font scale，不能作为跨平台持久化位置。阅读进度保存：

- `productID`
- `editionID`
- `paragraphID`
- 段内字符/语义 offset（仅在确有需要时）
- 阅读模式和时间戳

页面索引只在当前设备上计算和缓存。内容升级若拆分或合并段落，必须提供明确 migration map。

### 7.3 共享行为 fixtures

`Contracts/BehaviorFixtures/` 至少覆盖：

- 搜索规范化、简繁匹配、结果定位和片段截取。
- 每日经句在日期、时区和内容版本下的稳定选择。
- 收藏、续读和 legacy path 到 stable ID 的迁移。
- 目录节点展开/收起、跨分支返回和全部 leaf path 恰好可达一次；平台导航控件可以不同，目标 path 与状态恢复结果必须一致。
- 分享标题与文件名；禁止默认名 `text`，禁止自动加入日期时间。
- 深链编码、解码和非法输入处理。
- 音频按钮、selection generation、当前卷/下一卷、预取提升、迟到结果、取消、空间不足、校验失败和可回退错误语义。
- 主题、字号和产品默认值。

iOS XCTest 与 Android JVM tests 读取同一 fixtures。平台 UI 可以不同，用户行为结果必须一致。

## 8. 数据和离线策略

### 8.1 正文

- 每款单经正文、目录、精选和基础索引随 APK/AAB 安装，首次启动不依赖网络。
- 当前单经体量不需要先引入复杂全文数据库；使用 `kotlinx.serialization` 解析经过校验的只读数据，在 IO dispatcher 加载。
- 搜索规范化索引可在构建时生成，避免首启计算。
- Repository 缓存已解析的不可变 book model；大列表按段落惰性显示，不一次创建全部 Compose 节点。
- 若后续单个产品内容规模显著增加，再用基准测试决定是否迁入 SQLite/FTS，不凭想象提前设计大藏经数据库。

### 8.2 用户数据

根据官方建议，小型设置使用 DataStore，复杂并需要迁移/关联查询的数据使用 Room。[DataStore](https://developer.android.com/topic/libraries/architecture/datastore) [Room](https://developer.android.com/training/data-storage/room)

- **DataStore：** 主题、简繁、字号、阅读模式、提醒设置、音频偏好和最近进度。
- **Room：** 首版收藏及其 schema migrations；未来笔记、多个定位或可查询历史出现真实需求时再增加表，不预建空功能。
- 每款产品使用独立数据库和偏好命名空间。
- 数据访问只通过 repository，不让 composable 直接读取 DataStore/Room。
- migration tests 必须读取真实旧版本 fixture，不能只测空数据库。

### 8.3 备份

“数据仅保存在设备”与 Android 自动云备份可能冲突。首版建议明确关闭云备份，以保持隐私承诺简单且真实；以后若增加可选备份或导出，再更新隐私说明并测试迁移。卸载会删除数据，设置页需要如实说明。

## 9. 功能移植范围

### 9.1 P0：首发必须完成

| 功能 | Android 实现 | 验收重点 |
|---|---|---|
| 首页 | Compose，共享产品配置 | 继续读、继续听、搜索入口和当前状态清楚，不照搬 iOS 像素 |
| 目录/卷阅读 | 类型化导航、层级列表 | 稳定 ID、返回栈、深链、旋转/进程恢复 |
| 阅读器 | 滚动 + 分页模式 | 当前字号不缩小、大字体、自适应分页、无白底/底部空洞 |
| 续读 | DataStore + resolver | 回到同段落，内容版本迁移可靠 |
| 搜索 | 预生成索引 + repository | 简繁、定位、空态、长查询和性能 |
| 收藏 | Room | 排序、删除、深链、升级迁移；首版不顺带新增笔记 |
| 设置 | Compose controls | 主题、字号、简繁、阅读模式、提醒；不默认增加技术性音频存储页 |
| 听经 | Media3 | 后台、锁屏、耳机、蓝牙、倍速、睡眠、断点 |
| 按需/离线音频 | Media3 DownloadService/Manager | 当前卷优先、下一卷受控预取、bytes/SHA-256、暂停恢复、低空间/Data Saver；缓存策略由 Phase 0 冻结 |
| Mini-player | 导航壳 bottom region | 始终紧贴 bottom navigation，上下 inset 只计算一次 |
| 分享 | Android Sharesheet + FileProvider | 文字、`.txt`、单/多图片、语义文件名、无打开卡顿 |
| Widget | Glance | 小/中/大尺寸、深链、简繁、每日更新、添加/固定引导和 launcher 差异 |
| 每日提醒 | 通知 + 非精确调度 | 用户开启后才请求权限，重启后恢复 |
| 来源/隐私/反馈 | 产品配置 + 系统 Intent | 来源可追踪，反馈内容由用户确认 |

### 9.2 P1：首发后按证据加入

- 笔记、收藏/笔记导出与本地备份。
- Android App Links（有稳定 HTTPS 域名后）。
- 多设备云同步。
- 更复杂的平板双栏目录/正文布局。
- 手动 pin 多卷、下载全部、逐卷存储管理等高级离线控制；只有用户研究证明自动模式不足时进入 P0。
- Android Auto 或 Wear OS 控制入口。
- 远程内容增量更新。

这些能力不能阻塞首个高质量单经版本。

### 9.3 iOS 到 Android 的边界映射

| iOS 现状 | Android 目标 | 说明 |
|---|---|---|
| `Book.shared` | `BookRepository` | 去全局单例，产品和测试可注入 |
| `Prefers.shared` | DataStore repositories | 强类型、异步、可迁移 |
| `AudioManager.shared` + `AudioAssetCoordinator` | Media3 service + repository | 服务拥有播放，UI 观察状态；移植状态语义而非 Swift actor 实现 |
| UIKit/SwiftUI 阅读页面 | Compose ReaderScreen | 复刻行为，不复制布局 bug |
| WidgetKit | Glance App Widget | 单独 composables 和尺寸策略 |
| ODR/Managed BA/Cloudflare fallback | audio artifact + Android delivery config + Media3 download | 平台交付与 host 不同，audio ID/正文映射/checksum/故障语义共用 |
| `UIActivityViewController` | Android Sharesheet/FileProvider | 语义文件名和延迟生成一致 |
| UserNotifications | Notification + inexact AlarmManager | 遵循 Android 权限和省电规则；WorkManager 只做维护任务 |
| URL Scheme | typed route + deep-link Intent | route fixture 跨平台共用 |

## 10. 阅读器设计

### 10.1 滚动模式

- 正文按语义段落使用 `LazyColumn`，避免把数万字放进一个不可增量渲染的节点。
- 保留段落 stable ID，恢复位置使用 `LazyListState` 与精确 anchor 信息。
- 注释、科判或章标题是明确 item type，不通过字符串特征猜测样式。
- 选择、复制、分享和 TalkBack 语义必须在真实长文上测试。
- canonical contents 的每个 leaf path 必须恰好可达；宽度、窗口和 font scale 改变后，最后一行仍完整显示且字符覆盖与源文本一致。

### 10.2 分页模式

- 使用可测量视口和 `HorizontalPager`，页面由当前宽高、字体、字号、行距、语言和内容版本决定。
- 当前阅读字号是下限；文字过多时增加页面，**绝不通过缩小字体塞入固定页数**。
- 只同步计算当前页附近所需内容，其余分页可在后台预计算并缓存。
- 缓存 key 包含窗口尺寸、系统 font scale、App 字号、字体、语言、内容版本和 inset。
- 旋转、分屏、折叠状态或字号改变时使旧缓存失效，并通过段落 anchor 保持语义位置。
- 分页测试不只比较页数，还要拼接每页字符 range，证明从第一个到最后一个字符连续、无重复、无遗漏、无越界裁切。
- 以 2 万字单页源内容、API 26 低内存模拟器和大字号组合做压力测试，禁止主线程长时间停顿。

### 10.3 自适应和无障碍

- 支持 edge-to-edge；状态栏、导航栏和显示 cutout 由统一 window inset policy 处理。
- 手机使用 bottom navigation；宽屏可改为 navigation rail 或双栏，但信息架构保持一致。
- 触控目标至少 48dp。
- 支持系统 font scale 至少 200%，长标题可换行且不能遮挡控制。
- TalkBack 顺序、heading、selected、button 和播放状态均有语义。
- 颜色对比、深色模式和高对比文本通过自动检查与人工截图复核。

### 10.4 Mini-player 与底部导航

Android 首版就采用单一 bottom region：

```text
页面内容
Mini-player（存在播放会话时）
Bottom navigation
系统 navigation bar inset
```

`Scaffold` 或等价壳层只在最外层消费一次底部 system inset；Mini-player 不再自行添加相同 safe-area padding。每个 tab 使用同一壳层，避免不同设备和第二个 tab 出现播放器与 footer 间的大空隙。

需要覆盖三键导航、手势导航、横屏、带 cutout 设备、平板和键盘弹出状态。

## 11. 音频架构

### 11.1 播放

使用 Media3 `ExoPlayer` + `MediaSessionService`。Android 官方将后台播放会话放入 service，使系统媒体控件、耳机和通知可以在 Activity 不可见时继续工作。[Media3 background playback](https://developer.android.com/media/media3/session/background-playback)

服务负责：

- Player 和 MediaSession 生命周期。
- 当前产品、卷、队列、进度、播放速度和错误状态。
- audio focus、耳机拔出、蓝牙和远程控制。
- 锁屏/通知 metadata 与产品图标。
- 每隔有限时间和重要状态变化持久化播放位置。

Activity/composable 不持有 Player；它们绑定 repository 暴露的 immutable playback state 和 commands。

### 11.2 卷阅读页播放按钮的确定语义

此行为进入共享 fixture，并在 iOS、Android 保持一致：

1. 当前正在播放本卷：点击后暂停。
2. 当前暂停的是本卷，且未播完：点击后从保存位置 resume。
3. 当前会话是其他卷：点击本卷后从本卷 `0` 开始，不继承其他卷位置。
4. 本卷已完整播放结束：再次点击从 `0` 开始。
5. 下载中或网络不可用：显示明确状态，不把重复点击解释成从头播放。

### 11.3 音频交付

使用抽象 `AudioAssetProvider`：

```text
AudioAssetProvider
├── CdnMedia3AssetProvider       # 首选，Play 和非 Play 共用
├── BundledPreviewAssetProvider  # 可选短样音/首段
└── PlayAssetPackProvider        # 只有未来证明有收益才增加
```

首选 CDN/object storage + immutable versioned URLs：

- 跨平台 `audio-manifest.json` 提供 audio/track ID、卷 ID、renditions、codec、duration、bytes、SHA-256、artifact key 和权利引用，不放渠道 host。
- 现行楞严 `AudioAssets/audio-manifest.json` 已生成/校验 Swift、Node、checksum、媒体索引和 Apple manifests，Android 不读取或正则解析 Swift 源码。Gate F2 先把其中 Apple/CDN/source path 拆入平台配置，并补卷映射、renditions、codec、duration、权利和内容版本；Android 只消费演进后的跨平台 artifact 输出。
- `Products/<id>/Platform/android/audio-delivery.json` 选择 rendition 并把 artifact key 解析到当前渠道的 HTTPS host；生产 token/secret 不进入文件。
- Media3 `DownloadService` / `DownloadManager` 处理后台离线下载和恢复。[Media3 downloading media](https://developer.android.com/media/media3/exoplayer/downloading-media)
- 下载完成后校验长度和 SHA-256；损坏文件不可进入可播放状态。
- 默认产品语义建议与 iOS 对齐：用户点选的当前卷优先完整准备，播放开始后只预取下一卷；同一 asset 只有一个底层任务，预取可提升，旧 selection 的迟到结果不能抢占。
- Phase 0 通过用户需求和 Android Data Saver/计费网络约束冻结单产品与全局 cache budget、预取网络条件、过期策略和清理入口；不能照搬 iOS 当前“无容量上限 + 28 天”的应急缓存。首版不默认增加逐卷/下载全部/占用详情等技术页；若增加手动 pin，必须与自动清理语义明确区分。
- URL/host 可由渠道 adapter 替换，但同一 audio ID、正文映射和 artifact checksum 保持不变。

现有 `https://lengyan-audio-fallback.dhyana9.workers.dev` 只作为 iOS 楞严的应急实现证据：它实测对 Range 返回完整 200，网络中断会重下整卷，也没有大陆 SLA。Android prototype 必须使用支持 Range/恢复、容量、成本告警和目标地区可达性的独立主 host；不能因为路径和 checksum 已验证就沿用该 endpoint。

Play Asset Delivery 主要面向由 Google Play 托管的 app/game asset packs，会把资源交付绑定到 Play；本项目需要非 Play 和大陆渠道，因此不作为基础设施。[Play Asset Delivery](https://developer.android.com/guide/playcore/asset-delivery)

### 11.4 音频格式

- 母带保存在受控外部存储，发布格式通过固定脚本产生。
- 首轮对 AAC-LC/M4A 与 Opus 做 Android 目标设备兼容、体积和音质基准后写 ADR；不能只凭理论压缩率选择。
- manifest 记录 codec/profile，客户端不得从扩展名猜测。
- CDN 支持 Range requests、缓存头和 HTTPS。
- Git 只保存 manifest、授权和生成脚本，不保存完整发布音频。

## 12. 分享与长文本

### 12.1 打开分享页不能先生成图片

分享页面必须立即出现。流程是：

1. 只传递 stable content selection/ID，不在导航参数中复制 2 万字 attributed text。
2. 页面先显示轻量 skeleton 或文本预览。
3. repository 在后台准备分享 model。
4. 图片仅在用户选择“分享美图”后生成，预览先生成当前第一页。
5. 文件编码和磁盘写入均在后台 dispatcher；状态可取消，离开页面后停止无用任务。

以“点击分享到 sheet 可交互”为性能指标，不能把图片生成时间算作必要页面加载。

### 12.2 图片策略

- 正文左对齐；标题可按设计居中。
- 使用当前阅读字体和可读字号作为基线，只能允许用户调大，不能为塞入长图而缩小。
- 去掉开头和结尾无意义大块空白，边距由固定视觉 token 决定。
- 默认输出 1080px 宽 JPEG；质量和色彩配置经设备测试后固定。
- 使用受控最大高度/像素预算，超过预算自动分页，不创建 2 万字对应的单个超高 bitmap。
- 生成时逐页绘制、编码、释放，内存中最多保留当前页和必要缩略图。
- 预览使用缩略采样或当前页，不用 `ImageBitmap`/`Bitmap` 常驻保存全部原图。
- 多页通过 `ACTION_SEND_MULTIPLE` + `FileProvider` 分享；接收端不支持多图时提供文字或逐页分享回退。

具体最大高度不是主观常量。实现 PR 必须用 1,800、9,000、20,000 个中文字符，在 API 26/33/36 和低内存模拟器上记录：页数、总像素、JPEG 总大小、峰值内存、首预览时间和完整导出时间，再把阈值写入 ADR。

### 12.3 文字和文件名

- “分享文字”使用 `ACTION_SEND` 的 `text/plain`。
- “存为文件”生成 UTF-8 `.txt`，通过系统 document picker 或 Files 交付。
- 默认文件名由经名 + 卷/章节/段落标题构成，例如 `楞严经-卷二-见性发明.txt`。
- 图片使用相同语义主干，例如 `楞严经-卷二-见性发明-01.jpg`。
- 不使用 `text`、随机 UUID 或日期时间作为面向用户的默认名。
- 文件名 sanitizer 及重复命名规则由共享 fixture 测试。

## 13. Widget、提醒和通知

### 13.1 Glance Widget

使用 Glance，但它有自己的 composables 和 RemoteViews 约束，不能把 App 内 Compose 组件直接复用。[Jetpack Glance](https://developer.android.com/develop/ui/compose/glance)

支持响应式三档：

- **小号：** 经名/产品识别 + 一条短经句或“继续读”；文字空间不足时显示经过语义截断的短句，点击进入全文。
- **中号：** 经句、出处、继续读入口。
- **大号：** 更完整经句、出处、收藏/换一句等受系统能力允许的操作。

Widget 必须验证不同 launcher、系统字号、简繁和深色背景。Widget 数据使用独立、版本化 snapshot；App 内容、语言、收藏或日期变化时触发更新，失败时保留上一份有效数据。

设置页提供一个 Widget 入口，而不是“组件样式”三选项：小/中/大是 launcher 尺寸，不是三种产品样式。支持 `requestPinAppWidget` 的 launcher 优先调用系统固定流程；不支持时才显示经目标 launcher 校验的简短步骤。引导只展示当前 App 实际注册的 Widget、尺寸和预览，不能复制 iOS 锁屏步骤或宣传不存在的第三种“经文卡片”样式。

### 13.2 每日提醒

- 用户主动开启提醒时再请求 Android 13+ `POST_NOTIFICATIONS`，不在首次启动弹出。[Notification runtime permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- 每日提醒使用一次性的 inexact `AlarmManager` 计划下一次触发，触发后再安排下一天；WorkManager 只负责不面向具体时刻的维护/刷新任务。Android 官方建议大多数场景使用 inexact alarms，普通诵读提醒不申请受限 exact-alarm 权限。[Schedule alarms](https://developer.android.com/develop/background-work/services/alarms)
- 设置页应表达为“约在此时间提醒”，不要承诺分钟级精确。
- 开机、时区、系统时间、通知权限和 App 更新后重新核对调度。
- 通知 deep link 指向当天经句或最近阅读位置，必须经过 typed route parser。

媒体会话通知遵循 Media3 规则；普通提醒权限与媒体播放能力不能混成一个开关。

## 14. Android 原生 UX 原则

- 保留产品内容层级和视觉气质，不复制 iOS navigation bar、sheet、safe area 或手势实现。
- Android 系统返回和预测性返回必须自然工作；所有导航状态可恢复。
- 搜索入口放在符合 Android 信息架构的位置，可以是 top app bar action 或首页固定入口，不为“与 iOS 一致”破坏布局。
- 首页“继续读”和“继续听”是同级 48-56dp 高度的主要操作，可使用两项并排 action row；当宽度不足时换为纵向，不缩小文字。
- 设置使用 switch、segmented button、slider/stepper 和标准列表语义，不把每个选项做成装饰卡片。
- 页面 section 不套 section card；卡片只用于真正独立的重复内容或工具。
- 主题不能只靠一个颜色族；正文背景、文字、强调、播放状态和错误状态均有明确 token。
- 任何功能在 compact phone、large phone、tablet、foldable、横屏和 200% font scale 下不得重叠。

## 15. 隐私、安全与内容责任

### 15.1 首版隐私基线

- 无账户、广告、第三方分析和跨 App 跟踪。
- 只访问 HTTPS，使用 network security config 禁止 cleartext。
- 隐私政策与 Data safety 明确区分本地经文/进度、用户主动反馈和音频下载；音频 host 可能处理请求 IP 等网络元数据，不能把“无账户、无分析”表述为“完全不联网”。
- 不申请联系人、位置、相册全库、精确闹钟等非必要权限。
- 分享文件仅放在受控 cache/FileProvider 路径，定期清理，不公开整个内部目录。
- 日志不包含完整经文选择、笔记内容、文件路径、签名信息或用户反馈正文。
- 崩溃上报若以后加入，必须作为单独隐私 ADR，并更新 Data safety。
- 反馈由用户明确点击发送；共用服务只接收经批准的 `productID`、公开 App 版本和用户正文，不附带设备 ID、型号、Android 版本、build number 或阅读数据。

### 15.2 内容与权利

每款产品发布前必须有：

- `SOURCE_MANIFEST.yml`：底本、版本、来源 URL/馆藏、获取日期、处理方式。
- 经文校勘记录和人工复核人。
- 简繁转换策略及人工例外表。
- 音频朗读者、录音、编辑和分发授权。
- 图标、字体、插图和第三方依赖许可清单。
- 商店隐私政策、内容分级和版权联系渠道。

Codex 可以发现缺字段、生成差异和许可证清单，但不能替代经文校勘或法律判断。

### 15.3 密钥

- App signing keys、upload keys、Play service credentials 和 CDN secrets 不进入 Git、issue、聊天提示或截图。
- 每款 app-signing key 至少有两份离线加密备份，恢复步骤由人工演练。
- CI 使用最小权限、环境隔离和可撤销凭据；PR 构建不接触发布密钥。
- Codex 只调用封装好的签名/发布脚本，不读取或打印 secrets。

## 16. 测试策略

### 16.1 测试金字塔

**跨平台内容合同测试**

- manifest/schema、稳定 ID、目录引用、简繁、来源、音频映射。
- fixtures 同时被 iOS 和 Android 执行。
- 内容 diff 报告是产品审校的必交产物。

**Android JVM 单元测试**

- parser、repository mapping、搜索、每日经句、续读、分享文件名。
- 音频状态机和“同卷 resume、异卷从头”、冷启动 seek 不被初始 0 覆盖、A→B 原子切换、单预取提升、selection 竞态、取消/空间不足不误回退、bytes/SHA-256 拒绝坏文件、cache expiry/预算语义；fixture 由现有 iOS 行为提炼，不直接移植 Swift test double。
- DataStore/Room migration、下载状态、错误恢复。
- route/deep-link round trip 和恶意输入。

**Compose UI / instrumentation tests**

- 首次启动、主 tab、目录到阅读、搜索到定位、收藏、设置；目录展开状态跨 tab/进程恢复，内容升级后剔除失效 node ID，跨分支返回到正确层级。
- canonical leaf 全覆盖、长段最后一行和分页字符 range 连续；tablet 收藏 detail 可回到根阅读流，取消当前收藏不会清空已打开详情。
- Mini-player 跨 tab 始终贴近 bottom navigation。
- 分享页即时可见，长文后台生成可取消。
- 语言、字号、旋转和进程重建；主题快速切换时当前设置/阅读内容、navigation surface 和 system-bar inset 背景不消失或闪出错误颜色。
- 通知 deep link、Widget deep link/固定引导和播放 notification。

**截图和无障碍测试**

- 简体/繁体、浅色/深色。
- font scale 1.0、1.3、2.0。
- compact phone、普通 phone、tablet、foldable。
- 空态、loading、error、下载中和超长标题。
- Widget 短句利用可用空间，长句按语义截断且不低于可读字号；覆盖注册的每种尺寸和目标 launcher frame。
- 自动语义检查加 TalkBack 人工走查；截图通过才不等于无障碍通过。

**真机系统测试**

- 后台播放、锁屏、耳机、蓝牙、来电/audio focus。
- 下载中杀进程、重启、断网、切换 Wi-Fi/蜂窝、磁盘不足。
- 主音频 host 的 HEAD/Range/中断恢复、错误 Content-Length、hash 损坏与渠道 host 切换；不得拿现有无 Range 的应急源冒充通过。
- Widget 在 Pixel Launcher、Samsung 和至少一个目标大陆 OEM launcher 上表现。
- 通知省电限制、后台限制和系统升级。

### 16.2 设备矩阵

PR 最小自动矩阵：

- API 26 compact phone。
- API 33 phone（通知运行时权限边界）。
- API 36 phone。
- API 36 tablet 或 foldable profile。

Release 候选增加：

- 一台当前 Pixel 真机。
- 一台主流 Samsung 真机。
- 若进入大陆渠道，至少一台 Xiaomi/Redmi 与一台 Huawei/Honor/Oppo/Vivo 中的目标机型。
- 手势导航和三键导航。
- 低存储、低内存、无 Play Services 和受限网络场景。

模拟器能覆盖逻辑和布局，不能替代 OEM 后台音频、通知和 launcher Widget 测试。

### 16.3 性能与稳定性门槛

使用 Macrobenchmark 测量冷启动、首页、打开阅读器、长文滚动、搜索和分享页；为真实关键路径生成 Baseline Profile。[Baseline Profiles](https://developer.android.com/topic/performance/baselineprofiles/create-baselineprofile)

在选定的中端参考设备上冻结数字前，先建立可重复基线。最低验收原则：

- 启动和打开分享页不发生 ANR 或可感知的主线程长停顿。
- 2 万字分享源不会在进入页面时生成 bitmap。
- 当前约 8 万字符楞严内容的全文搜索和打开结果可稳定完成。
- 滚动和分页不因图片、字号或播放状态造成持续掉帧。
- 后台播放 2 小时无意外停止，进度误差处于定义阈值内。
- 长图导出峰值内存受预算控制，没有一次持有所有页面。
- Release build 在启用 R8/resource shrinking 后完整通过 smoke tests。

每项数字阈值由首个 reference build 实测后写入 `ANDROID_QUALITY_GATES.md`，不能由 AI 随意编造。

## 17. CI、构建和发布自动化

### 17.1 计划中的统一命令

所有 AI 和 CI 调用仓库脚本，不各自拼接长 Gradle/Xcode 命令：

```bash
./scripts/bootstrap.sh --check
./scripts/validate-content.sh --product lengyan
./scripts/verify.sh --platform android --product lengyan --scope unit
./scripts/verify.sh --platform android --product lengyan --scope ui
./scripts/verify.sh --platform android --product lengyan --scope release
./scripts/verify.sh --platform all --product lengyan --scope contract
```

脚本必须：

- 在干净克隆可运行。
- 使用 pinned JDK、Gradle Wrapper 和依赖版本。
- 在普通构建中只读取已提交的 dependency lockfiles 与 verification metadata；漂移直接失败，不由 CI 自动重写。
- 失败即非零退出，不把缺失测试打印成成功。
- 输出构建、测试、截图和内容报告的明确路径。
- 支持本地和 CI 相同入口。
- 由根 `verify.sh` 路由到内部 `verify-android.sh`；未实现或未知 scope 必须失败，不能静默跳过。

### 17.2 PR CI

Ubuntu runner 执行：

1. schema/content/license 校验。
2. Gradle configuration 和 dependency verification。
3. lint、静态分析、JVM tests。
4. 受影响 App 的 debug 和 unsigned release 构建。
5. Compose instrumentation/screenshot tests（可按快速/夜间矩阵分层）。
6. iOS/Android 共用契约发生变化时同时验证两个平台。

依赖图规则：

- 修改 `Products/lengyan`：验证楞严两平台。
- 修改 Android 共享模块：构建全部 Android App 模块。
- 修改 `Contracts` 或生成器：验证所有产品和两平台。
- 修改单一薄壳：只跑该产品完整矩阵。

### 17.3 定时 CI

- 每夜：完整 Android managed-device matrix、长文、下载和截图测试。
- 每周：全部产品 release build、dependency/license audit、Baseline Profile 检查。
- 每月：受控依赖升级 PR；一次只升级同类工具链，记录迁移说明。
- 每个内容发布前：完整内容 diff、来源和音频 checksum audit。

### 17.4 发布流水线

1. PR 通过并合并主分支。
2. 人工选择产品和版本，生成 release candidate。
3. CI 构建 AAB、mapping、native symbols（如有）、SBOM/依赖清单和校验值。
4. 内部测试轨道验证安装、升级、Widget、通知、音频和购买无关场景。
5. closed testing 收集真实设备反馈。
6. 人工批准 staged rollout：例如 5% -> 25% -> 50% -> 100%。
7. 监控 Play vitals、崩溃、ANR 和反馈；异常时停止 rollout，而不是等待下个版本。
8. 发布 tag、release notes、内容版本和构建 provenance。

Google Play 使用 Android App Bundle 和 Play App Signing；正式 Play App 创建、包名、签名和发布均需要人工确认。[Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)

可在现有 Fastlane 基础上扩展 Android metadata 与 Play 上传，但应先完成一次手工内部发布，再把已验证步骤自动化；大陆商店使用独立 adapter/runbook，不假设都有稳定上传 API。

## 18. 多商店与地区策略

### 18.1 第一阶段

- Google Play international：AAB、Play App Signing、internal/closed testing。
- 核心 App 不依赖 Google 登录、FCM、Play Billing 或 Play Asset Delivery。
- 音频 host、隐私页和反馈端点必须在目标地区实际可访问。

### 18.2 中国大陆作为独立发布工作流

大陆分发不是“把 Play AAB 改成 APK”这么简单，需要单独确认：

- 目标商店名单、主体资质、软件著作权/备案等当期要求。
- 同包名、同签名和升级兼容性。
- APK 架构、渠道审核、隐私弹窗和 SDK 清单。
- CDN/对象存储在大陆网络的可达性、速度和合规。
- 无 Google Play Services 设备上的通知、下载、分享和 Widget。
- 各 OEM 后台策略对音频和提醒的影响。

首发前建立 `ANDROID_DISTRIBUTION_MATRIX.md`，逐商店记录 artifact、签名、审核、隐私、SDK、更新和回滚要求。不要在没有明确需求时预装多个渠道 SDK。

Android developer verification 已进入分阶段实施，2026-09-30 起先在巴西、印度尼西亚、新加坡和泰国对 certified devices 上的分发生效，并计划于 2027 年扩展至全球；发布者账号和 package registration 应提前纳入 release readiness。[Android developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en)

## 19. Android 的 Codex 附加规则

通用任务合同、worktree、提交、二次 review、人工职责和维护节奏由跨平台主计划统一规定。Android 只增加以下规则：

- `android/AGENTS.md` 记录 Kotlin/Compose 边界、Gradle 公共命令、设备矩阵和禁止依赖；不复制根 `AGENTS.md`。
- Codex 不直接手改 generated resources、Gradle cache、AAB/APK、Baseline Profile 输出或签名配置；修改生成源后由任务重建。
- 新依赖必须说明官方来源、许可证、体积/权限影响、替代方案和固定版本；不使用动态版本。
- UI 任务必须提交对应 compact phone、大字体和至少一个宽屏证据；系统集成任务必须说明模拟器不能覆盖的真机项。
- Media3、Widget、通知、备份、深链和下载改动必须在相关 Android API 边界设备验证，不能用 JVM unit test 推断系统行为。
- 每月审查依赖和 target API；每季度审查 OEM 后台行为、CDN 可达性和设备矩阵；每年由人工完成每款签名 key 的恢复演练。
- AI 可生成 unsigned/release candidate、mapping、报告和商店草稿，但不得创建/读取生产 keystore、Play credentials 或正式 rollout。

## 20. 分阶段实施计划

本计划以跨平台主计划 **Gate F2 已通过**为前置：可信 CI、schema v1、stable IDs、楞严 canonical content、audio artifact manifest 和共享 fixtures 已存在。Android 不重复发明这些源文件，只实现 Android adapter 和测试 runner。

时间是假设“一名产品负责人 + Codex 持续开发 + 必要人工内容/真机复核”的日历估算，不是纯编码小时，也**不包含 Foundation 0-2**。阶段可有限重叠，但质量 Gate 不可跳过。

### Phase 0：决策和可复现基线（3-5 个工作日）

交付：

- 确认 publisher namespace、建议 `minSdk`、首发地区和测试设备。
- 审核共享楞严 behavior baseline，明确 Android 必须等价和允许原生差异的项目。
- 冻结音频产品策略：推荐当前卷按需准备、下一卷受控预取、自动缓存；明确计费网络/Wi-Fi、单产品与全局 cache budget、过期/清理入口与是否支持手动 pin，并记录 iOS 当前 28 天无上限策略只作为对照。
- 选择支持 Range/恢复和目标地区的 Android 主音频 host；明确现有 Cloudflare fallback 只用于对照失败场景。
- 确认 API 36、JDK/Gradle/AGP/Kotlin/Compose/Media3 精确版本及升级策略。
- 验证根 `verify.sh` 能路由 Android scope，缺少 Android 工程时明确报告未实现而非假成功。
- 创建 Android ADR 清单，不写产品 UI。

Gate A：F2 输入可由 Android 构建读取；包名/minSdk/渠道/设备/音频 UX/主 host 等人工决定项有 owner 和期限。

### Phase 1：Android 工程骨架（1-2 周）

交付：

- Gradle Wrapper、version catalog、build-logic 和 pinned JDK。
- `:apps:lengyan` + 五个共享模块空骨架。
- Compose 主题、typed navigation、AppContainer 和测试框架。
- lint、unit、debug/release build、managed device CI。
- 基础 `android/AGENTS.md` 和架构 ADR。

Gate B：干净克隆一条命令构建、测试并安装楞严空壳；没有本机隐式配置。

### Phase 2：共享内容和持久化（1-2 周）

交付：

- Android generated-assets task 和 schema validation adapter。
- product/book/audio artifact manifest parser、BookRepository、稳定 ID 和搜索索引；不得读取现有 Swift catalog，也不得直接把含 Apple delivery 字段的楞严现行 catalog 当跨平台 schema。
- DataStore/Room 初始 schema 与 migration tests。
- Android JVM tests 执行既有跨平台 behavior fixtures，不复制 fixture 内容。

Gate C：Android 与 iOS 对相同 fixtures 产生相同目录、全部 leaf path、搜索、每日经句、续读和 audio ID/checksum 结果。

### Phase 3：楞严文本产品闭环（3-5 周）

交付：

- 首页、目录、卷阅读、滚动/分页、搜索、收藏和设置。
- 简繁、主题、当前字号、大字体、TalkBack 和自适应布局。
- deep links、旋转/进程恢复和设备分页 anchor 恢复。
- 目录 disclosure 跨重启/内容升级、跨分支返回、全部 leaf 可达，以及分页字符连续无裁切。
- 主题即时切换无空白/错误背景；tablet 收藏详情在取消当前收藏后保持稳定。
- Mini-player 占位状态与统一 bottom region。

Gate D：用户无需网络完成“打开 -> 找到内容 -> 阅读 -> 收藏 -> 搜索 -> 续读”；截图和长文矩阵通过。

### Phase 4：音频和离线交付（3-5 周）

交付：

- MediaSessionService、ExoPlayer、系统通知和远程控制。
- Android delivery config、独立主 host、DownloadService/Manager、Range 恢复与 bytes/SHA-256。
- 当前卷/下一卷、预取提升、A→B 原子切换、迟到 selection、同卷 resume/异卷从头、冷启动精确恢复、倍速、睡眠定时和进度持久化。
- 按 Phase 0 决策实施有明确容量边界的自动缓存、计费网络、expiry 和清理；不顺带创建已从 iOS 删除的技术存储管理页。
- Mini-player 跨 tab、后台和进程重建。
- 真实音频格式、CDN Range 和 OEM 后台基准。

Gate E：至少三类真机完成 2 小时后台播放、断网/Range 下载恢复、坏文件拒绝、缓存压力、耳机/蓝牙和杀进程测试；所有 iOS 音频行为 fixtures 在 Android 通过。

### Phase 5：系统集成（3-5 周）

交付：

- Glance 小/中/大 Widget、系统 pin 流程和 launcher-specific fallback 引导。
- 每日提醒和权限教育。
- 文字、`.txt`、单图/多图分享与语义文件名。
- 来源、隐私、反馈和开源许可页面。
- 1,800/9,000/20,000 字分享性能报告。

Gate F：Widget/提醒/分享在 API 26、33、36 和目标 OEM 上通过；分享页无预生成卡顿。

### Phase 6：发布质量（2-3 周）

交付：

- Macrobenchmark、Baseline Profile、R8 release smoke tests。
- 完整截图、TalkBack、字体 200%、平板/折叠屏检查。
- 依赖/许可/隐私/内容/音频审计。
- AAB、签名 runbook、Play metadata 和 incident/rollback 文档。

Gate G：无 P0/P1 已知缺陷；所有质量数字来自 reference devices；人工内容和隐私批准完成。

### Phase 7：内部、封闭和正式发布（2-4 周）

交付：

- Play internal -> closed -> staged production。
- 20-30 名覆盖目标年龄与设备的测试用户，而非只由开发者验证。
- 升级、卸载重装、低存储、无网络和权限拒绝反馈闭环。
- 发布 tag、构建 provenance、值班和回滚流程。

Gate H：closed testing 的阻断问题已关闭，production rollout 已人工批准且可暂停/回滚；楞严 Android 才算正式达到多产品基准。

**《楞严经》生产级 Android 预期估算：F2 之后 16-24 周。** 这是 Phase 3-5 有限并行的目标；若各阶段完全串行或真机、CDN、商店验证受阻，按各阶段上限应保留最多约 27 周。AI 可以显著缩短编码和文档时间，但商店、真机、内容、音频和封闭测试仍需要真实日历时间；不能把共享 Foundation 时间隐藏在这个数字里。

## 21. 新经典接入计划

只有楞严 Gate H 通过、共享 API 至少稳定一个发布周期后，才接第二产品；《金刚经》正式发布仍遵循产品计划中的观察期，不因 Android 工程已经可复用而跳过市场验证。

### 21.1 每款产品的标准接入清单

1. 创建产品目录、source manifest 和 rights checklist。
2. 确定版本/底本，导入结构化正文并分配 stable IDs。
3. 生成人工可读内容 diff、简繁 exception 和目录报告。
4. 创建独立 App 模块、永久包名、图标、主题 token 和商店 metadata。
5. 接入精选/每日经句、搜索 fixtures、深链和 Widget 文案。
6. 准备音频 manifest、授权、转码、checksum 和 CDN。
7. 跑共享测试、产品截图、真机音频和 release gates。
8. 独立 internal/closed/staged release。

### 21.2 顺序和估算

| 产品 | 作用 | Android 增量估算 | 主要不确定性 |
|---|---|---:|---|
| 《金刚经》 | 第二产品，验证薄壳和共享平台 | 4-6 周 | 底本、分品结构、音频与精选审校 |
| 《圆觉经》 | 验证十二章结构和导读扩展 | 3-5 周 | 章结构、版本与音频 |
| 《六祖坛经》 | 验证更复杂篇章、人物和语录结构 | 5-8 周 | 版本差异、注释边界、内容权利 |

表中是**经文、权利和音频已准备后的 Android 增量工程估算**，不是完整产品日历。完整周期仍以 `.planning/MAHAYANA_PRODUCT_PLANS.md` 的内容准备、发布和观察期为准。估算同时以共享平台无需大改为前提；不能用“AI 已完成导入”代替人工校勘。

### 21.3 第二产品的架构检验

接入《金刚经》时必须记录：

- 新增代码中多少是产品资源，多少是共享功能修改。
- 是否出现通过 `if (productID == ...)` 处理产品差异。
- 是否需要修改共用 schema，以及旧楞严是否完整回归。
- 构建全部产品的 CI 时间和失败定位是否可接受。
- 哪些抽象有真实第二调用者，哪些只是提前设计。

原则是配置承载稳定差异，产品专属模块承载真实独特功能；不把所有差异硬塞进万能 manifest。

## 22. 必须建立的文档和 ADR

实施不是先写完所有文档再编码，但以下文件应随对应决策落地：

```text
android/AGENTS.md
docs/android/ANDROID_ARCHITECTURE.md
docs/android/ANDROID_PARITY_MATRIX.md
docs/android/ANDROID_QUALITY_GATES.md
docs/android/ANDROID_RELEASE_RUNBOOK.md
docs/android/ANDROID_DISTRIBUTION_MATRIX.md
docs/android/ANDROID_DEVICE_MATRIX.md
docs/android/ADR-0001-native-compose.md
docs/android/ADR-0002-multi-app-modules.md
docs/android/ADR-0003-storage-and-migrations.md
docs/android/ADR-0004-media3-audio-implementation.md
docs/android/ADR-0005-backup-and-privacy.md
docs/android/ADR-0006-signing-and-multi-store.md
docs/android/ADR-0007-share-image-budget.md
```

共享 content contract 和 artifact/delivery 决策只写在根架构/内容 ADR，Android ADR 引用它们并记录平台实现，不复制 schema。产品的 source/release/store 文件也由跨平台主计划定义。

ADR 必须包含 context、decision、alternatives、consequences、验证方式和重新评估条件。被新决定替代时标为 superseded，不静默重写历史。

## 23. 风险登记

| 风险 | 早期信号 | 控制措施 |
|---|---|---|
| iOS/Android 经文漂移 | 同一段落 hash 不同 | 单一内容源、双平台 contract CI |
| 过早抽象多产品 | 大量空接口和 config 分支 | 楞严先闭环，第二真实产品再抽取 |
| Android 后台音频被 OEM 杀死 | 锁屏/省电后停止 | MediaSessionService、真机矩阵、明确故障恢复 |
| 超长分享 OOM/卡顿 | 打开分享即掉帧、bitmap 峰值高 | 延迟生成、分页、像素预算、Macrobenchmark |
| 分页位置漂移 | 字号/旋转后跳到错误页 | stable paragraph anchor、缓存 key 和 migration tests |
| 包名或签名失误 | 上传占位包、非 Play 无法升级 | 发布前人工 Gate、publisher-owned keys、runbook |
| 音频继续膨胀 Git | clone/CI 越来越慢 | 外部存储、manifest/checksum、禁止新增大二进制 |
| 把 iOS 应急 CDN 当 Android 主源 | Range/中断恢复失败、整卷重下 | 独立主 host prototype、delivery config、真实网络测试 |
| 直接消费楞严现行交付 catalog | Apple/CDN/source path 泄漏进 Android contract | F2 拆分 artifact/delivery schema，Android 只消费跨平台生成结果 |
| CDN 在大陆不可用 | 下载慢或失败 | 渠道 host adapter、目标网络实测、镜像策略 |
| Gradle/Compose 依赖快速变化 | AI 使用过期 API | 固定版本、官方文档、月度受控升级 |
| AI 生成伪测试/伪成功 | job 只打印结果 | 强制真实命令、artifact、失败退出和二次 review |
| 内容或授权错误 | 来源字段缺失、版本混用 | 人工内容/法律 Gate，源码 diff 与 rights checklist |
| 多商店 SDK 污染核心 | 权限和隐私清单膨胀 | core 无 Play 依赖，渠道 SDK 需单独 ADR |
| 无账户导致换机丢数据 | 用户误以为自动同步 | 明确说明，后续优先做本地导出而非隐式云备份 |

## 24. 发布完成定义

《楞严经》Android 只有满足以下条件才算完成：

- 干净克隆能用文档中的一条命令构建和测试。
- 正文、目录、简繁、来源和音频 manifest 全部通过 schema/content 校验。
- P0 功能均有自动测试或记录原因的真机验收证据。
- 当前卷/下一卷、预取提升、A→B 原子切换、迟到 selection、同卷 resume/异卷从头、冷启动 seek、取消/空间不足/坏文件、cache expiry/预算等音频行为通过共享 fixture 和真机测试。
- 主音频 host 支持 Range/恢复并在目标地区验证；现有 iOS `workers.dev` 应急 endpoint 不作为通过依据。
- Mini-player 在所有主 tab 和导航模式中紧贴 footer，无重复 inset。
- 目录展开状态跨重启且内容升级可清理失效节点；tablet 取消当前收藏不清空已打开详情。
- 主题快速切换不会让设置/阅读内容消失，也不会暴露错误的 system-bar 或底部背景。
- 当前阅读字体不会因长文或分享缩小；200% font scale 无遮挡。
- 分享页面即时出现；1,800/9,000/20,000 字报告证明分页、体积和内存可控。
- 后台播放、离线下载、Widget、提醒、深链在目标 API/OEM 设备通过。
- Widget 设置入口只展示实际支持的尺寸/样式，并在支持的 launcher 走系统 pin 流程；不存在虚构第三样式。
- 反馈 contract 证明只发送 `productID`、公开 App 版本和用户正文，服务不可用不影响离线核心功能。
- R8 release build、升级、Room migration、低存储和离线场景通过。
- 包名、签名备份、隐私/Data safety、来源、权利和商店资料由人工批准。
- closed testing 的 P0/P1 问题关闭，staged rollout 和回滚流程可执行。
- 仓库中不存在新增大型音频、生产 secret、占位 CI 或无法复现的本机步骤。

## 25. 开工前的人工决策清单

只有以下少数决策需要产品负责人在 Phase 0 锁定，其余工程工作可由 Codex 推进：

1. Android publisher namespace；楞严永久包名在 Phase 0 锁定，其他三款可先保留候选但不得上传占位 App。
2. 首发范围是仅 Google Play，还是同步准备某些大陆商店。
3. `minSdk 26` 是否接受；若要支持 23-25，需要明确目标设备理由。
4. 每款独立 app-signing key 的保管人和离线恢复位置。
5. 音频主 CDN/object storage 的供应商、Range/恢复、地区和预算边界；现有应急 `workers.dev` 不参与选择。
6. 音频采用自动当前卷/下一卷，还是首版就提供 Wi-Fi-only、手动 pin/逐卷管理；推荐先自动、后按证据增加高级控制。
7. 确认首版只移植现有收藏，不把新笔记功能混入 Android P0；若改变范围，应作为独立产品决定。
8. 自动云备份首版关闭的隐私决定。
9. 真机池和 20-30 名 closed testers 的来源。

## 26. 建议的首批实施任务

决策通过后，按以下小 PR 开始，避免一次创建巨大脚手架：

1. **Android 决策 PR：** 验证 Gate F2 输入，记录原生 Compose、多 App 模块、minSdk/package/signing、音频 UX 与主 host checklist；不复制 schema v1。
2. **构建 PR：** `android/` Wrapper、version catalog、build-logic、空楞严 App、真实 CI。
3. **内容 PR：** Android generated assets、book/audio manifest 校验、BookRepository 和跨平台 fixtures；证明不依赖 Swift catalog。
4. **阅读垂直切片 PR：** 首页 -> 卷 -> 滚动阅读 -> 续读，覆盖一卷真实楞严数据。
5. **长文/分页 PR：** 完成字号、分页、旋转、大字体和 2 万字基准。
6. **音频垂直切片 PR：** 一卷独立主 CDN 音频、Range 恢复、bytes/SHA-256、当前/下一卷、预取提升、同卷 resume/异卷从头和 Mini-player。
7. **系统能力 PR：** Widget/pin 引导、提醒和分享分别独立实施与验证。

完成楞严 Gate H 后再创建 `:apps:jingang`。如果第二款产品需要复制通用代码，先修正共享边界；如果只需 manifest、内容和资源，则说明平台设计达到目标。
