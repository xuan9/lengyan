# AI 驱动的多经典产品工程与维护计划

**日期：** 2026-07-26\
**版本：** v6（Foundation 0 已关闭；Foundation 1 仓库实现完成，托管证据待跑）\
**状态：** 实施中\
**适用产品：** 《楞严经》《金刚经》《圆觉经》《六祖坛经》及后续单经产品

### 文档职责与权威关系

本文件是**跨平台工程主计划**，负责仓库、共享内容契约、产品隔离、AI 工作方式、质量门槛和总体实施依赖。为避免多份计划互相覆盖，采用以下边界：

| 主题 | 实施前权威文件 |
|---|---|
| 产品选择、用户价值、发布顺序和完整产品周期 | `.planning/MAHAYANA_PRODUCT_PLANS.md` |
| 跨平台仓库、共享契约、内容/音频治理和 Codex 流程 | 本文件 |
| Android 技术实现、设备矩阵和 Play/多商店发布 | `.planning/ANDROID_MULTI_PRODUCT_PORTING_PLAN.md` |
| 已经实施的技术决定 | 已接受的 ADR、schema、测试、脚本和代码 |

若 Android 文件与本文件在共享目录、schema、命令或产品顺序上冲突，以本文件为准；Android 平台内部细节以 Android 文件为准。进入实施后，已接受的 ADR 和机器可执行契约会取代相应 `.planning` 段落，计划文件不得继续成为第二套配置。

## 1. 结论

可以实施，也适合主要由 Codex 完成代码、测试、文档和发布自动化，但不能把它理解成“让 AI 复制三份 App 后长期自行运行”。可持续方案是：

1. **一个 Git monorepo。** 所有产品共用一套工程规则、跨平台契约、平台内共享引擎、测试工具和发布自动化。
2. **多个独立单经 App。** 每款在 iOS 和 Android 都有独立应用身份、商店页面、Widget、图标、内容、音频和发布节奏，不做大书架。
3. **平台内共享代码，平台间共享契约。** iOS 使用本地 `ClassicKit` Swift Package；Android 使用原生 Kotlin/Compose 库模块。两个平台共用内容源、schema、稳定 ID、音频 artifact 清单、深链和行为 fixtures，不强行共享 UI/runtime 代码。
4. **稳定差异配置化，独特体验留在薄壳。** 经名、章卷结构、精选池、来源、资源和稳定功能开关进入 `ProductManifest`；真正独有的导读、人物或问答体验保留为产品代码，不制造万能 manifest。
5. **文字与权利信息进入 Git，大音频离开主 Git。** 音频 artifact 由带 SHA-256 的清单描述，平台/渠道交付配置与内容清单分离。
6. **音频 artifact 共享，交付策略按平台分层。** 当前楞严已实现 iOS 15–25 Legacy ODR、iOS 26+ Managed Background Assets 和 Cloudflare 应急回退；新产品与 Android 仍以可替换的 CDN/object storage 为跨平台基线。现有 `workers.dev` 回退源不是 Android 主源，也不是新产品默认基础设施。
7. **AI 用机器检查约束。** 每个改动必须通过真实构建、测试、内容校验和必要的截图/真机证据；禁止用只输出“成功”的占位 CI。
8. **人保留不可委托的最终责任。** 经文与教义编辑、版权/授权、产品身份和签名密钥、隐私/地区合规、各平台正式发布批准。

代码开发可以高度 AI 化；内容真实性、权利判断和生产发布不应完全无人负责。

## 2. 仓库与产品模型

### 2.1 推荐：monorepo + 多独立 App

同一个仓库包含：

- 四款单经 App 的 iOS 薄壳 Target 和 Android App 模块。
- 每款对应的 iOS Widget Extension 与 Android App Widget 注册。
- iOS `ClassicKit` 本地 Swift Package 和 Android 原生共享库模块。
- 一套跨平台 schema、内容生成器和行为 fixtures。
- 每款独立的内容、资产、来源和商店资料。
- 一个受控反馈服务及其数据/保留策略。
- 一套内容校验、构建、测试、截图、性能和发布脚本。

平台内的播放器修复一次即可覆盖该平台所有产品；共享 schema 或行为变更则在同一提交验证 iOS、Android 和所有受影响产品。对 Codex 而言，接口、规则、生成器、调用端和测试位于同一上下文，可显著降低跨仓库版本漂移。

### 2.2 不推荐的两个方案

**不复制产品仓库或平台仓库。** 初期看似快，但 `Book.swift`、Android repository、播放器、Widget、分享和设计系统会迅速形成多个不同版本；AI 需要重复修复，并容易漏掉某一款或某个平台。

**不先做一个多书大 App。** 共用代码库不等于共用产品入口。当前价值是“打开即进入一部经典”，多书书架会引入账户、跨书搜索、资源管理和复杂导航，改变产品定位。

### 2.3 何时才考虑拆仓库

只有出现以下情况之一再评估：

- 某款产品形成完全不同的交互与技术栈。
- 不同团队需要独立权限或法律隔离。
- 发布依赖互相阻塞，且共享模块已经可以独立版本化。

在当前规模和单人 + Codex 模式下，拆仓库没有收益。

### 2.4 不采用跨平台 UI，也暂不采用 KMP

iOS 与 Android 最困难的部分分别依赖 AVFoundation/WidgetKit/UIKit/SwiftUI 和 Media3/Glance/Compose。首版采用两套原生实现，通过同一 fixtures 验证纯行为。只有两个平台都发布、至少两款产品稳定运行，并且纯逻辑重复已被测量后，才评估 KMP；即使采用，也只共享不依赖 UI、媒体和平台存储的模型/算法。

## 3. 当前仓库审计结论

### 3.1 已有基础足够复用（2026-07-26 实测）

- UIKit 阅读流已经承载约 8 万字符内容的《楞严经》数据。
- SwiftUI 已用于听经、收藏、搜索、设置和分享。
- `Book.shared` 已有资源加载和基本结构校验。
- `AudioManager.shared` 已通过 `AudioAssetProvider` / `AudioAssetCoordinator` 处理资源 lease、后台播放、续播、下一卷预取与锁屏控制；冷启动播放位置恢复和生命周期保存已补强，系统和 CDN 分支不再散落在播放器中。
- `Products/lengyan/audio-artifacts.json`、iOS/Android delivery 与 tooling input 已成为分层音频输入；旧 manifest 及 Swift、Node、checksum、媒体索引和 11 个 Apple manifests 均由生成器兼容输出，本地 `--check` 与 CI audio-catalog job 已建立。
- Widget 已支持小/中/大与锁屏尺寸、首次添加引导和刷新恢复；新增了短/长经句、系统尺寸和可读字号下限的渲染测试。简繁体、提醒、分享长图和文字导出已有实现。
- 当前 Xcode 工程包含 App、Asset Downloader Extension、Unit Tests、UI Tests 和 Widget 五个 Target；App Scheme 已提交为 shared scheme。
- `a299864` 已收敛此前 4 个收藏详情稳定性 pending 文件，`bf3d790` 是干净的计划/代码 checkpoint；`a687fb8` 在其上补齐迁移关键行为回归，形成当前 F0 behavior reference。
- 2026-07-26 使用 Xcode 26.6/iOS 26.5 Simulator 在 `a687fb8` 实测 104 个 unit tests（1 个 Legacy ODR integration skip）零失败；目录展开跨重启、冷启动同卷 resume、seek 初始零值保护和 28 天 cache expiry/protected asset 均有专门测试。此前 3 个 iPad 收藏/主题 UI tests 已通过，并已纳入统一 UI smoke 命令。

因此需要的是**产品化抽象和质量基础设施**，不是重新开发阅读器。

### 3.2 审计问题及处理状态

1. `Book.swift` 写死 `lengyanjing-*` 五类资源名称。
2. `Constants.swift` 写死大量楞严路径、精选路径和十卷假设。
3. `ReadingResumeResolver`、首页、分享文件名、Widget、URL Scheme、Bundle ID、ODR Tag 和发布脚本仍含产品硬编码。
4. `Book.shared`、`AudioManager.shared`、`Prefers.shared` 让视图直接依赖全局单例，测试和多产品注入困难。
5. App Scheme 已从 `xcuserdata` 移到 `xcshareddata`；App、Widget、Asset Downloader Extension、11 个 pack 和双栈 Archive 现已收敛到根 `verify.sh`。签名和 App Store 关联仍是外部发行 Gate。
6. 旧 CI 在没有 `Package.swift` 的情况下执行无效 Swift Package 命令；Foundation 1 已删除这些命令，改为调用本地同一验证入口，托管首跑仍需形成证据。
7. 旧 CI 的无障碍、性能和覆盖率 job 只是输出成功文字；Foundation 1 已删除假 job。重新加入任何质量门槛前必须先有真实测量器和失败阈值。
8. 根 `AGENTS.md` 现为唯一 agent 入口，`CLAUDE.md` 已改为指针，`REQUIREMENTS.md` 已重写为当前产品约束；其他历史报告继续按权威顺序逐步归档，不阻塞 contracts。
9. `.git` 约 693MB、Git pack 约 673MB；索引仍有 21 个大型 MP3/M4A 母源/发布文件和 1 个约 7KB 的 M0 smoke 音频。新产品继续这样存放会恶化克隆和 CI。
10. 此项已解决：跨平台 artifact 不含 Apple/CDN/source 配置，并已具备 stable volume mapping、rendition、codec/profile、duration、权利、内容版本和 immutable key；旧 manifest 仅作生成兼容层。
11. `generate-audio-manifest.mjs` 已从 product manifest 解析 artifact、iOS delivery、tooling input 与输出路径，并生成 18 个兼容文件；当前 source-verification Gate 仍会读取 Git 内完整 M4A。后续停止新增大音频并迁移到受控构建存储时，再把普通代码 CI 与 release/audio-integrity CI 分开。
12. 此前 `241fb0c` 后的收藏详情未提交修改已由 `a299864` 收敛；F0 命令、结果与真实发行缺口记录在 `docs/quality/REFERENCE_BASELINE_2026-07-26.md`。后续迁移不再依赖未提交文件。
13. 仓库包含反馈 Worker/D1，以及 Apple/Cloudflare 音频网络交付；“完全本地”已不再是完整数据流描述。当前 `PRIVACY.md` 尚未说明外部音频托管链路，后续需同时描述必要的网络请求、服务方、用途和保留边界。
14. Foundation 1 已将 Node 固定为 22.17.1，把第三方 GitHub Actions 固定到 commit SHA，并以 Xcode 26 runner 执行真实脚本；GitLab 源仓库自动跑 portable Node gate，macOS build/archive 在有资格的 runner 上手动取证。两套托管配置都需首跑成功后才可关闭 Gate F1。
15. Apple 双栈生产代码、11 个 pack 和 Cloudflare 全量回读已验证，但 App Store Connect 上传/关联、签名 Validate、TestFlight、Apple-hosted 真下载以及目标地区真机网络仍未验证；这部分是外部发行 Gate，不能由模拟器测试替代。
16. 当前仓库没有 Android/Gradle/Kotlin 工程；Android 是从零建立原生实现并按行为移植，不存在可继续扩建的旧 Android 代码基线。
17. Cloudflare fallback cache 已从“2 卷/48MiB”改为无文件数/字节上限、28 天未访问后清理；现有 11 条合计 161,420,718 bytes（约 154MiB）。当前单产品应急场景可继续观察，但多产品和 Android 必须显式确定单产品与全局预算，不能只复制时间淘汰策略。
18. `a687fb8` 已为目录展开跨重启、冷启动同卷 resume、seek 初始零值保护和 28 天 expiry/protected asset 增加专门回归；迁移时必须保留这些测试和 stable behavior fixtures。

这些问题不表示不可实施，而是定义了实施顺序：**先建立可信基线，再抽象，再接第二款产品。**

### 3.3 7 月 19–26 日提交对计划的影响

| 提交主题 | 对计划的判断 | 后续动作 |
|---|---|---|
| shared scheme、反馈/隐私发布准备 | F0/F1 部分前移，但 CI 仍不可信 | 保留成果，接入统一命令和真实 CI |
| Apple-hosted + ODR + Cloudflare 音频双栈 | `AudioAssetProvider` 原型阶段已完成，方向正确 | 不重写状态机；补真实发行验证 |
| 楞严音频 manifest + generator | 当前 11 条重复手工权威和 Swift regex 已消除，F2 部分前移 | 保留现有生成链；把交付 catalog 拆成跨产品 artifact manifest 与平台 delivery config |
| 自动音频存储、28 天 cache 与进度恢复 | 用户体验是按需准备、自动缓存/清理和冷启动续播；现行 fallback 最多可保留约 154MiB | 补 expiry/resume tests；Android Phase 0 独立冻结有上限的 cache 策略 |
| Widget 引导、预览和渲染矩阵 | Widget onboarding、语义截断和可读字号下限已成为现有产品行为 | 加入产品配置、简繁和跨平台验收基线 |
| 目录展开持久化、主题和 iPad split-detail/safe area | 导航状态、即时换肤、底部无白块/重复 inset 是产品行为，不是 UIKit 偶然实现 | 补持久化测试并形成 route/theme/layout fixtures；Android 保持用户结果而非复制 UIKit 实现 |
| 长段分页裁切修复 | “每个字符可达、宽度变化不裁字”已有测试证据 | 保留为 iOS 回归并加入 Android 长文门槛 |

## 4. 目标仓库结构

以下是目标态，不要求一次性移动全部现有文件：

```text
lengyan-app/
├── AGENTS.md
├── .github/
│   ├── CODEOWNERS                     # 内容、契约、发布流程的人工责任边界
│   └── workflows/
├── project.yml                       # 通过等价验证后采用 XcodeGen
├── Apps/
│   ├── LengyanApp/                   # AppDelegate、产品入口、专有页面
│   ├── JingangApp/
│   ├── YuanjueApp/
│   └── TanjingApp/
├── Widgets/
│   ├── LengyanWidget/
│   ├── JingangWidget/
│   ├── YuanjueWidget/
│   └── TanjingWidget/
├── Packages/
│   └── ClassicKit/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── ClassicCore/
│       │   ├── ClassicAudio/
│       │   ├── ClassicUI/
│       │   └── ClassicWidgetSupport/
│       └── Tests/
├── android/
│   ├── AGENTS.md
│   ├── settings.gradle.kts
│   ├── gradle/
│   │   ├── libs.versions.toml
│   │   └── verification-metadata.xml
│   ├── build-logic/
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
│   │   ├── Assets.xcassets/
│   │   ├── Localizations/
│   │   ├── audio-artifacts.json
│   │   ├── SOURCE_MANIFEST.yml
│   │   ├── StoreMetadata/
│   │   │   ├── ios/
│   │   │   └── android/
│   │   └── Platform/
│   │       ├── ios/
│   │       │   ├── audio-delivery.json
│   │       │   └── ManagedAssetManifests/   # 生成源；.aar 只进 artifacts
│   │       └── android/
│   │           └── audio-delivery.json
│   ├── jingang/
│   ├── yuanjue/
│   └── tanjing/
├── Contracts/
│   ├── Schemas/
│   └── BehaviorFixtures/
├── tools/                             # 保留当前小写目录，兼容 Linux CI
│   ├── content-validator/
│   └── project-generator-checks/
├── scripts/
│   ├── bootstrap.sh
│   ├── generate-project.sh
│   ├── validate-content.sh
│   ├── verify.sh                      # 唯一公共验证入口
│   ├── verify-ios.sh                  # verify.sh 的内部实现
│   └── verify-android.sh              # verify.sh 的内部实现
├── docs/
│   ├── architecture/
│   ├── content/
│   ├── product/
│   ├── quality/
│   └── release/
├── server/                            # 现有共享反馈服务及其迁移/隐私测试
├── CloudflareAudioFallback/           # 现有楞严应急源；catalog 由 manifest 生成
└── fastlane/
    └── products/                      # 由 Products/StoreMetadata 驱动
```

目录大小写一旦建立不得混用；尤其不在已有 `tools/` 旁再创建 `Tools/`。这是 Linux CI 和 macOS 默认大小写不敏感文件系统之间的真实兼容要求。

### 4.1 模块边界

**`Contracts`（先于两个平台建立）**

- JSON Schema、稳定 ID 规范、深链格式和行为 fixtures。
- 不包含 Swift/Kotlin 运行时代码，也不依赖 Xcode 或 Gradle 才能校验。
- iOS XCTest、Android JVM tests 和独立内容校验器读取同一份输入。
- schema 变更必须同时提供旧数据兼容策略和两个平台的验证结果。

**`ClassicCore`（第一阶段建立）**

- `ProductManifest`、`BookManifest` 和强类型内容模型。
- 资源加载、目录、稳定段落 ID、搜索、导航和来源定位。
- 阅读进度、收藏数据模型及旧数据迁移。
- 不依赖 UIKit，优先使用 Foundation，能够快速跑单元测试。

**`ClassicAudio`（第二款产品复用前抽取）**

- 播放队列、续播、下载状态、睡眠定时和远程控制。
- 只通过协议读取产品音频清单，不访问 `Book.shared`。
- 播放与资源交付分离：`AudioAssetProvider` 负责确保文件可用，播放器只接收本地 URL。
- 现有 App 内的 `AudioAssetProvider`、lease、单任务提升、selection generation、当前/下一卷和 failover 状态机作为迁移输入，先原样锁定测试，再移入模块；不为“重新抽象”重写已经验证的并发逻辑。
- 现有楞严保留 `LegacyODRAudioAssetProvider`（iOS 15–25）与 `ManagedBackgroundAssetsAudioAssetProvider`（iOS 26+）；后者已完成代码和 Archive 验证，但仍以真实发行环境验证为上线条件。
- 当前 `CDNAudioAssetProvider` 是用户主动播放时的应急整文件回退，使用前台 `URLSessionDownloadTask`；缓存位于可清理的 Caches，现行策略无数量/字节上限并在 28 天未访问后清理。它不等同于新产品所需的有明确预算、可恢复后台 CDN provider。
- 新产品默认采用可替换 CDN + background `URLSession`；Managed Background Assets 只有在楞严真实发行链路和运营收益得到验证后才按产品增加，不要求旧系统走同一实现。
- AVFoundation、ODR、URLSession 和 Background Assets 的实现细节留在模块内部，业务页面不直接调用这些 API。

**`ClassicUI`（逐步抽取，不先重写）**

- 设计 Token、共享 SwiftUI 页面、UIKit 阅读组件和分享预览。
- 产品专有的首页结构或深读页面保留在 App 薄壳。
- 现有 Objective-C `RATreeView` 先由适配层包住，不为模块化强制重写。

**`ClassicWidgetSupport`**

- 主 App 与 Widget 共用的数据结构、编码和深链规则。
- 每款 Widget 仍是独立 Extension Target。

Android 模块职责、Navigation、Media3、Glance 和存储边界由 Android 计划定义。首轮 iOS 只完整建立 `ClassicCore`；其他模块先建立必要协议边界，在出现第二个真实产品调用者时再抽取实现，避免为了“架构漂亮”制造过度抽象。

## 5. 产品与构建配置

### 5.1 每款产品独立拥有

- iOS App/Widget Targets 与 Android App module/Widget registration。
- iOS Bundle ID、Android application ID、Widget 身份、深链 namespace 和 App Icon。
- iOS App Group/UserDefaults、Android DataStore/Room、资源缓存和下载命名空间。
- 经文内容、目录、精选池、音频清单、来源页和修订日志。
- 简繁本地化、隐私/Data safety、各商店元数据、截图和独立版本号。

### 5.2 现有楞严用户数据

现有楞严 App 的 Bundle ID 和持久化键不能因为重构而变化。当前 App Group `group.org.fuxuan.books` 应先为楞严保留；新产品使用独立 App Group。若以后统一命名，必须先做显式迁移并验证 Widget 数据。

当前 `/A1/B1/...` 路径已经被收藏和进度使用。对楞严而言，它们应作为 legacy stable ID 保留，或提供完整映射；不得通过重建目录静默使老用户收藏失效。

`expandedOutlinePaths`、阅读模式快照、`lastPlayTime`/`lastTotalTime` 和当前音频 ID 也已成为迁移输入。新产品必须按 product namespace 隔离；楞严迁移必须过滤不存在的旧 path，并证明升级后目录展开状态与冷启动播放位置不会被默认值覆盖。

Android 没有既有楞严用户数据，但从首版开始仍必须持久化 `editionID + paragraphID`，不得把设备分页序号当稳定位置。未来如果增加本地导入/导出，跨平台只交换版本化领域数据，不复制 UserDefaults、DataStore 或数据库文件。

### 5.3 `ProductManifest`

运行时配置至少包含：

```json
{
  "schemaVersion": 1,
  "productID": "lengyan",
  "editionID": "lengyan-2026-07",
  "contentVersion": "2026.07.1",
  "titles": {
    "zh-Hans": "楞严经",
    "zh-Hant": "楞嚴經"
  },
  "bookManifest": "book-manifest.json",
  "navigationMode": "hierarchyAndVolumes",
  "featuredParagraphIDs": [],
  "features": {
    "audio": true,
    "dailyVerse": true,
    "guidedReading": false,
    "personIndex": false
  },
  "audioManifest": "audio-manifest.json",
  "sourceManifest": "SOURCE_MANIFEST.yml"
}
```

`ProductManifest` 只描述稳定、跨平台的产品能力。章节数量等可从 `BookManifest` 推导的数据不重复保存；独特产品功能也不通过不断增加布尔值硬塞进配置。

Bundle ID、application ID、签名 Team、App Group、渠道 host 等构建/交付身份放在 `Products/<id>/Platform/<platform>/` 和工程配置中，不混入运行时内容文件。证书、keystore、密码和生产 token 永不写入仓库。

## 6. 内容与音频治理

### 6.1 经文数据

- Git 保存可审阅的结构化文字、来源清单、生成规则和最终发布数据。
- canonical source 统一使用 UTF-8、NFC、明确换行/空白规则和确定性序列化；内容 hash 必须基于规范化结果，避免 Swift、Kotlin 和独立校验器各自产生不同摘要。
- 每个段落有稳定 ID、底本定位、简繁文字、内容修订号和可选音频时间码。
- 原典修订单独提交，diff 中不能混入 UI 重构。
- 自动检查目录、正文、索引、简繁、来源和音频映射的一致性。
- 经文变更必须输出“改前、改后、来源、理由、复核人”。Codex 可以生成差异和校验，但不能自行决定经文字句。

### 6.2 音频数据

主 Git 不再新增大型音频二进制。推荐流程：

1. 无损母带保存在受控外部存储。
2. 构建用压缩音频由固定脚本生成或从受控构建存储下载。
3. `audio-manifest.json` 记录 audio/track ID、正文映射、可用 renditions、codec、时长、字节数、SHA-256、artifact key、权利引用和内容版本。
4. `scripts/bootstrap.sh --product jingang --audio` 只下载该产品所需资源并校验哈希。
5. 普通代码 CI 不下载全部音频；音频集成和 Release CI 才获取完整资源。

楞严迁移现已完成：`audio-artifacts.json` 是跨平台身份与完整性输入，Apple/CDN/source path 分别位于 iOS delivery 与 tooling input；`generate-audio-manifest.mjs` 校验源文件并生成旧 manifest、Swift、Node、checksum、两份媒体索引、静态健康信息和 11 个 Apple manifests，不再正则解析 Swift 源码。Android delivery 明确保留为 `planned`，待主站和格式实测后再选择 rendition。

不建议立即改写已有 673MB Git 历史。先停止继续增长；历史清理应作为独立、可回滚的仓库迁移项目处理。

### 6.3 内容清单与交付配置分层

跨平台 `audio-manifest.json` 不保存 ODR Tag、完整 CDN host 或商店专有字段。交付信息位于：

```text
Products/<id>/Platform/ios/audio-delivery.json
Products/<id>/Platform/android/audio-delivery.json
```

内容清单回答“这是什么文件、对应哪一卷、是否正确”；平台配置回答“这个渠道到哪里取得它、何时回退、缓存策略是什么”。同一 track 可以有 AAC/M4A 与 Opus 等多个 rendition，平台通过受测策略选择，两个平台仍以 audio ID 和正文映射保持一致。生产 host 可由受控环境配置注入，但 artifact key 和 checksum 必须可审阅。

### 6.4 ODR 迁移与长期交付

ODR 已进入弃用周期，因此共享接口不能暴露 `NSBundleResourceRequest`。当前楞严已经建立 backend-neutral `AudioAssetProvider` 与 lease 契约，后续工作是产品化和生成配置，不是重新设计接口：

- **现有楞严：** iOS 15–25 使用 Legacy ODR；iOS 26+ 使用 Apple-hosted Managed packs；用户主动播放时 Apple 明确失败或连续无进展才使用 Cloudflare 应急回退。后台下一卷预取不得触发公共回退流量。
- **新产品和 Android：** 默认使用同一受控 CDN/object storage；iOS 15+ 通过 background `URLSession`，Android 通过 Media3 下载。
- **当前 Cloudflare 限制：** Static Assets 实测忽略 Range 并返回完整文件，且 `workers.dev` 没有中国大陆 SLA；它只保留为楞严应急源，Android 与新产品必须另选支持 Range、恢复、容量与地区要求的主 host。
- **iOS 26+ 可选优化：** 新产品是否采用 Apple-Hosted Managed Background Assets，必须等楞严完成 App Store Connect pack 关联、TestFlight/生产真机和目标网络验证后再决定。
- **未来移除：** 当支持系统范围允许时删除 ODR Provider，而不改播放器、页面或产品内容模型。

Apple 已确认 ODR 从 iOS/iPadOS 27 起弃用并建议迁移；Managed Background Assets 可用于目标 iOS 26+ 的 App。弃用不等于当前版本立即失效，因此现有楞严迁移应行为保持、可回滚；但新产品不再建立新的 ODR 依赖。

不能为了采用新 API 立即放弃当前中老年用户仍在使用的旧设备；最低系统与资源交付策略必须作为产品决策测试，而不是由框架迁移顺带决定。

### 6.5 反馈服务

- `server/` 是正式部署单元，必须有锁定工具链、单元/迁移/隐私测试和独立发布 runbook。
- 多产品请求只增加必要的 `productID` 与公开 App 版本，不附带设备标识、型号、系统版本或用户阅读数据。
- 每款 App 的隐私说明、Apple Privacy Manifest 和 Google Play Data safety 必须与 Worker/D1 的真实字段、保留和删除流程一致。
- 隐私数据流还必须列出 Apple/Google/第三方音频 host 的请求目的、可能处理的网络元数据、缓存位置和地区路由；“正文与进度本地保存”不能被表述为“App 完全不联网”。
- 客户端失败不能阻塞离线阅读；服务端 schema 变更先做向后兼容阶段，再删除旧字段。
- AI 可以执行迁移检查和生成数据流 diff，但生产数据库、Cloudflare 权限和隐私声明仍需人工批准。

## 7. 工具链与工程管理

### 7.1 短期

- 保留已经提交的 shared App Scheme，并把 Widget/Asset Downloader Extension 的可复现 build/archive 校验接入公共脚本；只在独立调用确有需要时再提交目标级 shared scheme。
- 修正 CI，使干净克隆只用仓库真实存在的命令即可构建。
- CI Xcode image 必须支持 iOS 26 SDK 和 Asset Downloader Extension；工具链不满足时明确失败，不能通过弱化/跳过 extension 得到绿色。
- 用 `.xcconfig` 收敛最低系统、版本、签名以外的共享 Build Settings。

### 7.2 增加第二款 Target 前

建议采用 XcodeGen，把 Target、Scheme、资源、测试和配置写成可审阅的 `project.yml`。`project.pbxproj` 可以提交，但视为生成物，不再手工编辑。这样 Codex 修改的是稳定的 YAML，而不是大量随机 UUID。

由于当前工程包含 ODR Tag、Widget、Asset Downloader Extension、Managed Background Assets、Objective-C Bridging Header 和旧资源组，迁移必须先做等价性试验：

- Debug/Release Build Settings 对比。
- 主 App、Widget 与 Asset Downloader Extension 均可构建，主 App/Widget 可启动。
- 11 个 ODR Tag、Managed manifests、App Group、弱链接、App 内不嵌完整 M4A 和 Apple/CDN 音频状态语义不变。
- Bundle ID、Entitlements、URL Scheme 和本地化不变。
- Unit/UI Test Target 仍正确关联。

未通过这些检查时保留现有工程，不把“引入生成器”与《金刚经》功能开发混在一起。

本地 Swift Package 是 Apple 原生支持的组织方式，不等于引入第三方运行时依赖；它适合把共享代码及单元测试从多个 App Target 中隔离出来。

### 7.3 跨平台工具链

完全由 Codex 长期维护的前提不是“机器上刚好装过”，而是仓库能验证工具版本：

- iOS CI 使用明确的 Xcode/macOS image；升级 Xcode 以单独 PR 完成，不能继续固定在当前过期的 Xcode 15。
- Android 使用 Gradle Wrapper、Java toolchain、Version Catalog、dependency verification、dependency lockfiles 和锁定的插件版本；只有受控依赖升级 PR 可以重写 lockfiles/verification metadata。
- Fastlane 由 `Gemfile.lock` 固定；反馈服务/内容工具若使用 Node，则提交 package lock 并在 bootstrap 中检查版本。
- CI 中的第三方 GitHub Actions 固定到完整 commit SHA，由单独、可审阅的升级 PR 更新。
- XcodeGen 若采用，固定版本并让 `generate-project.sh --check` 验证生成结果；若等价性试验失败，继续维护原生 `.xcodeproj`，不阻塞产品。
- `bootstrap.sh --check` 只检查并给出明确缺项；安装全局工具必须是用户可见步骤，不由 CI 或 Codex 隐式修改开发机。
- 任何生成器只写 build/generated 目录，除非该生成物明确要求提交；生成源与生成物的权威关系必须写入 ADR。

## 8. Codex 长期工作方式

### 8.1 仓库级指令

新增简短的根 `AGENTS.md`，只写每次都必须遵守的事实：

- 支持的 Xcode/iOS、JDK/Gradle/Android 版本和工具检查命令。
- 唯一公共构建、测试、内容校验和截图命令。
- 共享代码与产品代码的目录边界。
- 不得擅改经文、来源、权利清单、Bundle/application ID 和签名配置。
- 修改共享契约或平台模块必须验证哪些产品和平台。
- UI 改动必须检查的平台设备、字号和简繁模式。
- 提交与 review 的最低证据。

在 `Products/AGENTS.md` 增加内容治理规则，在 `Packages/ClassicKit/AGENTS.md` 和 `android/AGENTS.md` 增加各平台公共 API 与兼容性规则。更深层文件只在确有局部差异时建立。不要把完整产品报告复制进 `AGENTS.md`；Codex 官方建议保持该文件精简、把规则放在最接近代码的位置，并用 linters/tests 等基础设施执行规则。

### 8.2 每个任务的输入契约

每个任务或 Issue 至少写：

```text
目标
用户行为 / 问题复现
影响产品与平台
范围内
范围外
验收标准
必须执行的命令
需要的截图 / 性能证据
内容或持久化迁移影响
隐私、权限、资源与发布影响
```

模糊的“优化一下”不直接进入实施；先由 Codex 把它转换成覆盖真实目标的可验证任务，不能为了容易通过测试而缩小用户要求。

### 8.3 标准执行循环

1. Codex 读取 `AGENTS.md`、任务文件和受影响模块。
2. 检查工作区、当前分支和最近提交；并行任务使用独立 Git worktree，不让两个会话修改同一脏目录。
3. 先复现或建立能证明目标的失败测试/fixture，再完成范围内实现。
4. 运行 `./scripts/verify.sh --platform <ios|android|all> --product <id> --scope affected`。
5. UI 改动在规定设备、简繁和大字体下截图检查。
6. 保存验证命令、结果、截图/性能 artifact 和未运行项；不能只写“已测试”。
7. 实现上下文完成后，由新的 Codex 上下文做 findings-first review；发现问题后回到原任务修正并重跑证据。
8. 一个行为主题一个提交，提交信息说明用户可见结果和数据迁移影响。
9. 人审核产品体验、内容差异、权利、密钥、隐私和生产发布决定。

“让另一个上下文再 review”有帮助，但不能代替自动测试和人的内容审核。

## 9. 必须补齐的文档

不需要先写几十份文档。先建立少量权威文件，并让 Android 细节从 Android 计划逐步迁入 `docs/android/`，不要复制同一规则。

### P0：架构迁移前

1. **`AGENTS.md`**：Codex 的永久仓库规则和唯一真实命令。
2. **`docs/architecture/ADR-0001-monorepo-native-platforms.md`**：monorepo、独立 App、原生双平台、何时评估 KMP/拆仓。
3. **`docs/architecture/ADR-0002-asset-delivery.md`**：artifact/delivery 分层、CDN、Legacy ODR、Background Assets 和 Android Media3。
4. **`docs/architecture/MIGRATION_PLAN.md`**：从当前单例/硬编码到 Manifest、注入和跨平台 contracts 的迁移及回滚点。
5. **`docs/quality/QUALITY_GATES.md`**：构建、单测、UI、截图、性能、无障碍、服务端和内容校验硬门槛。
6. **`docs/content/CONTENT_SCHEMA.md`**：稳定 ID、目录、正文、简繁、来源和音频时间码规范。
7. **`docs/product/LENGYAN_BEHAVIOR_BASELINE.md`**：当前应保留的用户行为；不要把 stale `REQUIREMENTS.md` 当现状。
8. **`docs/PRIVACY_DATA_FLOW.md`**：App、音频 host、反馈 Worker/D1、备份和保留的数据流。

### P0：每款产品开发前

9. **`Products/<id>/PRODUCT.md`**：用户、核心流程、MVP、非目标和验收标准。
10. **`Products/<id>/SOURCE_MANIFEST.yml`**：底本、扫描/数字来源、权利、编辑、校对和修订历史。
11. **`Products/<id>/audio-artifacts.json`**：音频权利、renditions、哈希与正文版本对应关系。
12. **`Products/<id>/RELEASE_CHECKLIST.md`**：该产品两个平台的身份、内容、隐私和发布证据。

### P1：首个新产品上架前

13. **`docs/release/RELEASE_RUNBOOK.md`**：版本、截图、隐私、签名、TestFlight/Play/其他商店、回滚和事故处理。
14. **`docs/android/` 下的架构、设备、质量和分发文档**：只承载 Android 特有规则，清单见 Android 计划。

现有 `CLAUDE.md` 和 `REQUIREMENTS.md` 与实际搜索、Widget、分享、反馈和架构状态不一致。Phase 1 必须更新、明确标注 historical，或移入 archive；不能让后续 AI 同时读取互相冲突的指令。`.planning` 文件用于决策过程，不替代上述实施契约。

## 10. 真实质量门槛

### 10.1 统一命令

最终应只有少量稳定入口：

```bash
./scripts/bootstrap.sh --check
./scripts/generate-project.sh --platform ios --check
./scripts/validate-content.sh --product all
./scripts/verify.sh --platform ios --product lengyan --scope unit
./scripts/verify.sh --platform android --product lengyan --scope ui
./scripts/verify.sh --platform all --product lengyan --scope contract
./scripts/verify.sh --platform all --product all --scope release
```

`verify.sh` 是人、Codex 和 CI 的唯一公共入口；`verify-ios.sh`、`verify-android.sh` 只是内部实现。脚本负责选择 Scheme/device、DerivedData/Gradle 输出和 artifact 目录，Codex 不应每次临时拼一套平台命令。尚未实现的 scope 必须明确失败或报告 unsupported，不能返回绿色成功。

### 10.2 CI 矩阵

- 每个 PR：Manifest/内容 schema、服务端 lint/tests、受影响平台单测和 App 构建。
- 修改音频 catalog、provider、pack 或 fallback：运行 Swift 音频 tests、Node catalog/static-assets tests、shell/package checks 和无内嵌 M4A 的 Archive 校验；真实 Apple-hosted 下载仍由发行 Gate 负责。
- 修改 `Contracts`、schema 或生成器：验证所有现有产品的 iOS/Android contract tests；新产品未建立前不制造空通过矩阵。
- 修改 `ClassicCore`：构建全部现有 iOS App + Widget；修改 Android shared library：构建全部现有 Android App modules。
- 修改单款内容/资产：验证该产品两个平台和共享内容校验。
- iOS UI 变化：至少 iPhone/iPad、简繁、浅深色和最大支持动态字体；Android UI 变化按 Android 设备矩阵验证。
- 修改反馈 API/schema：客户端 contract tests、Worker tests、migration 和 privacy data-flow diff 同时执行。
- 每晚：所有已存在产品的 Unit/UI smoke、内容校验、截图和无完整音频 release build。
- Release：获取并校验完整音频，执行平台签名外的可复现构建、安装/升级验证；上传由人工批准的 release workflow 完成。

CI 只有真正执行并解析结果才能通过。占位 `echo`、没有阈值的覆盖率说明、未运行的无障碍检查必须删除或明确标记为未实现，不能显示绿色成功。

### 10.3 回归基线

产品化重构前先为楞严建立以下基线：

- 首次启动、继续阅读、目录跳转、搜索与收藏。
- 全目录 disclosure state 跨 tab 和重启保持；跨分支返回到正确层级；iPad 收藏 split-detail 能回到根阅读流，取消当前收藏时仍保留已打开详情。
- 每个 canonical leaf 恰好可达一次；长段在 iPhone/iPad、旋转和窄窗口下不漏字符、不裁最后一行。
- 当前卷暂停后恢复；其他卷从头播放；App 冷启动恢复时异步 seek 不得先被 `0` 进度覆盖。
- 当前播放 A 时请求 B 不提前中断 A；下一卷预取可提升复用；迟到选择不能抢占；用户取消/空间不足不误触 CDN；下载文件须通过 bytes + SHA-256 后才播放。
- CDN cache 的受保护项、28 天未访问清理和未来容量上限由可注入时钟/预算测试覆盖，不能只测试手工传入“保留两卷”。
- iOS 15–25 Legacy ODR、iOS 26+ Managed packs、Cloudflare 明确失败/无进展回退、后台播放、锁屏控制和无网络错误；抽取模块后同一状态语义继续成立。
- Widget 小/中/大与锁屏尺寸、短/长经句语义截断、可读字号下限、首次添加引导、刷新恢复和深链。
- 简繁切换、大字体、VoiceOver 关键标签；主题快速切换时设置、tab bar、当前 reader 和 safe-area 背景不消失、不闪白/黑块。
- 短文本、9,000 字、20,000 字分享预览和导出。
- 现有收藏与阅读/播放进度迁移。
- 反馈只在用户主动发送后传输允许字段，离线阅读不依赖反馈服务。

新引擎必须先让这些行为在楞严上保持一致，才允许增加《金刚经》iOS Target；Android 先通过自身楞严发布 Gate，才增加《金刚经》Android module。性能阈值在 reference device 建立基线后冻结，不使用当前 CI 中未经测量的“启动 <2 秒、内存 <100MB”等文字作为证据。

## 11. Git 与发布管理

### 11.1 分支

- 指定一个受保护 trunk（目标名为 `main`），并使其始终可构建、可发布；当前功能分支整理完成前不假设已经达到该状态。
- 用 `.github/CODEOWNERS` 和 required checks 保护 `Products/**/Content`、`Contracts/`、发布 workflow、隐私与签名配置；AI 生成的 PR 不能自行满足这些人工批准。
- Codex 使用短期分支：`codex/<issue>-<summary>`。
- 并行任务使用独立 worktree；同一 schema、工程文件或内容文件的并行编辑需先分解所有权。
- 不长期维护 `develop` 和多个漂移分支。
- 架构迁移、内容修订、产品功能和商店资料尽量分开提交。
- 发布标签统一为 `<platform>/<product>/vX.Y.Z`，例如 `ios/lengyan/v1.6.0`、`android/jingang/v1.0.0`。

### 11.2 提交

- 一个提交解决一个可说明的行为或基础设施问题。
- 若 ADR 规定某生成物需要提交，则它与生成源同一提交；否则只提交生成源，并由干净克隆重建。
- 不在功能提交里改经文；不在内容提交里重构播放器。
- 每个提交记录执行过的验证，失败或未运行项必须说明。

### 11.3 版本

- App 版本各自演进，不要求四款同时发布。
- `ClassicKit` 在 monorepo 内随提交锁定，不需要过早发布远程 Package 版本。
- 内容有独立 `contentVersion`，文字修订可追踪到具体 App 版本。
- 共享 schema 只做向后兼容迁移；破坏性升级必须提供数据迁移器。
- iOS build number 与 Android versionCode 分别单调递增，不要求两个平台同号；`contentVersion` 与 App 版本独立。
- 商店 metadata 的长期权威源位于 `Products/<id>/StoreMetadata/<platform>/`，Fastlane 等工具目录由生成/同步检查驱动，避免两份文案漂移。

## 12. 人与 AI 的职责

### Codex 可以负责

- 架构迁移、功能实现、重构、测试和 CI。
- 生成项目配置、内容校验器和资源脚本。
- UI 实现、模拟器迭代、截图对比和可访问性检查。
- 生成经文 diff、查找不一致、检查漏段与音文映射。
- 更新文档、变更日志、发布资料草稿和提交。
- 在无生产 secrets 的环境生成候选构建、校验值、SBOM/依赖清单和 release draft。

### 必须有人最终确认

- 每个底本、标点、异文和注释的发布决定。
- 文字、音频、字体、图片的授权及适用范围。
- 佛学解释和产品分类用语。
- 真机主观体验，尤其是中老年用户可读性。
- Apple/Google/其他商店账号、永久应用身份、签名证书/keystore、隐私回答和正式上架。
- CDN、Cloudflare/D1、生产迁移、成本和地区合规决定。

所以可采用“**AI 完成工程，人负责内容与发布治理**”，而不是声称产品完全无人维护。

## 13. 组合实施路线

这不是一个完全串行的项目。正确依赖是“先共享基线与 contracts，再让 iOS 产品化和 Android 楞严基准并行；内容工作可并行，产品发布仍顺序验证”。

### Foundation 0：整理当前基线（已完成）

- 以 `8172e47..bf3d790` 为审计范围；收藏详情 pending diff 已在 `a299864` 收敛，`bf3d790` 提供干净 checkpoint，`a687fb8` 提供迁移关键行为锁定。
- 已归档 Xcode 26.6 下 104 unit tests（1 个预期 skip）和关键 iPad UI tests，并补目录展开重启、冷启动音频 resume、seek 零值保护和 cache expiry 专门回归。
- 将 Apple-hosted 未验证项、Cloudflare 地区限制和隐私文案缺口列为明确 release blockers/accepted risks，不用单元测试结果掩盖。
- 固定最终可安装 reference commit；后续分享、导航、Widget、音频或服务端修复不得与架构迁移混成一个提交。

**Gate F0：** reference commit、迁移输入和行为基线可定位；没有依赖未提交用户文件才能恢复的关键状态。

### Foundation 1：可信仓库（仓库实现完成，托管 Gate 待关闭）

- 已保留 shared App Scheme；新增根 `AGENTS.md`、工具链检查和统一 `verify.sh`，覆盖 App、Widget、Asset Downloader Extension 与音频 Archive 校验。
- 已保留真实 audio-catalog 检查；根 Node 固定为 22.17.1，删除不存在的 Swift Package 命令和假通过 quality jobs，iOS CI 改用 Xcode 26 runner。
- 已在根目录建立 GitHub/GitLab 均可识别的 `CODEOWNERS`；GitHub workflow 使用最小权限且第三方 Action 固定到 commit SHA，GitLab 源仓库有真实 portable gate。
- 已将 `CLAUDE.md` 收敛为入口指针，并把 `REQUIREMENTS.md` 更新为当前楞严产品边界。
- 反馈 Worker lockfile、14 个 tests、语法、Wrangler dry-run 和 high-severity audit 已进入公共命令；privacy data-flow 文案仍归 I0 外部发行闭环。

**Gate F1：** 干净克隆可用一条公共命令构建/测试当前 iOS App；CI 每个绿色 job 都有真实执行证据。

**当前状态：** 本地公共命令、unit/build/UI/archive 均通过；Gate F1 只剩 GitLab/GitHub 首个托管 pipeline 的可定位成功记录和 required-check 设置，不能因配置文件已提交而提前宣布关闭。

### Foundation 2：共享内容契约（2-4 周）

- 已建立 `ProductManifest`、`BookManifest`、content package、audio artifact、source manifest、behavior fixture 的 Draft 2020-12 schema，以及稳定 ID 与 canonical UTF-8/NFC/hash 规则。
- 已登记四个产品：楞严是 `legacy-migration`；金刚、圆觉、坛经只处于 `source-review`。四份 commit-pinned CBETA XML 仅作受限校勘参考，未导入正文，默认商业权利会阻断发布。
- 独立 Node validator 已校验产品间引用、楞严十个 legacy JSON 哈希、现行 11 条音频逐项兼容、source/rights gate 和 8 类跨平台 fixtures，并通过负向测试；已接入根 `verify.sh contracts` 和 Node CI。
- 已将 11 条楞严音频拆为 product-neutral artifact、iOS/Android delivery 与 repository tooling input；十卷映射到稳定 volume ID，codec/profile、duration、bytes、SHA-256 和 immutable artifact key 完整。旧 `AudioAssets/audio-manifest.json` 成为生成投影，连同原有 17 个下游产物保持逐字节兼容。
- 已把现有楞严数据生成两套 `legacy-migration` 结构化包：每套 1,262 段、1,669 个 section，并建立覆盖全部旧节点的 path map；现有 iOS runtime 与 `lengyan/data/` 保持不变。
- 生产 chapter map 可可靠定位 1,133/1,155 个 leaf path；其余 22 项保留旧路径和提示但明确 `volumeID: null`，不得由 AI 猜测。逐段测试证明正文只发生 288 处确定性的 CRLF-to-LF 规范化。
- 8 份共享 fixtures 已覆盖搜索简繁匹配/片段、按时区与内容版本选择每日经句、续读归一化、旧收藏迁移、legacy path 到 stable location、分享文件名、深链和同卷 resume/异卷从头播放；现有 iOS XCTest 直接读取同一 JSON 并执行生产 policy。
- 停止新增大音频到 Git，确定 CDN/object storage 和 artifact/delivery 分层。

**当前工程状态：** Foundation 2 的本地工程条件已完成：完整 legacy map、可逆 migration package、artifact/delivery 生成链、8 类 fixtures 与 iOS adapter 均由公共验证命令执行。现有 iOS 仍保留 legacy 存储格式；stable resolver 先作为迁移证明，后续切换必须另做可回滚的数据迁移。上述完成不代表正文 canonical，也不能把 planned Android delivery 当作已选定主站。

**并行发布阻断项：** 楞严 authoritative source/rights/text review 与 22 项卷映射裁定继续记录为人工治理工作；它们阻止 canonical promotion 和正式新渠道发布，但不阻止用锁定的现有正文快照开发、测试 Android 兼容实现。Android 自身 fixture adapter 在 Phase 2/Gate C 完成，不能循环地作为创建 Android 工程之前的 F2 条件。

**Gate F2（本地工程 Gate 已通过）：** 独立 validator 可在 macOS/Linux 校验楞严；schema v1、8 类 fixtures、iOS adapter 和迁移报告已 review。Node 22.17.1 公共 Gate 通过，Xcode 26.6/iOS 26.5 Simulator 共 114 项测试（1 项真实 ODR 环境测试按预期跳过）零失败。Android 工程可进入 Phase 1；托管 CI 证据、权威正文与发行权利仍分别受 F1 和 release Gate 管理。

### Track I：iOS 产品化

**I0：现有音频发行闭环（可与 Foundation 1–2 并行）**

- 按当前单次 submission 的 pack 限制完成 11 个 pack 的 10+1 审核/上传、处理、build 关联和签名 Validate；限制变化时以当期 App Store Connect 为准。
- 在 iOS 15 与 iOS 26 真机验证 ODR/Managed 下载、取消、恢复、版本更新、低空间和 Cloudflare 回退；目标地区网络单独记录。
- 更新隐私政策与数据流，使 Apple/Cloudflare 音频请求和反馈服务描述与生产一致。

**Gate I0：** `BackgroundAssets/IMPLEMENTATION_STATUS_2026-07-19.md` 的“仍需真实发行环境验证”已关闭或逐项由人工接受风险；未通过时不把 Managed packs 复制到新产品。

**I1：`ClassicCore` 与 provider 边界（3-6 周）**

- 引入本地 Swift Package 和强类型内容模型。
- 新代码通过注入访问 repository；`Book.shared`/`Prefers.shared` 保留为迁移 facade，不一次性重写 UI。
- 楞严从 Manifest 启动，旧收藏、进度、Widget 和播放行为保持。
- 把已验证的 provider/lease/coordinator 及测试迁入 `ClassicAudio`，通过生成的产品 catalog 注入；新增适合新产品的 background URLSession provider，不改变当前楞严双栈行为。

**Gate I1：** 楞严回归矩阵通过；provider 切换不改变 UI 或播放状态语义。

**I2：多 Target（1-2 周）**

- 完成 XcodeGen 等价性试验并记录采用/拒绝决定。
- 创建《金刚经》空壳 App/Widget，配置独立 Bundle ID、App Group、资源和 metadata。

**Gate I2：** 两款可独立安装，数据、Widget、深链、反馈 productID 和音频命名空间不串产品。

**I3：《金刚经》iOS MVP（6-10 周 + 至少 8 周观察）**

- 周期与顺序以 `.planning/MAHAYANA_PRODUCT_PLANS.md` 为准。
- 《圆觉经》内容准备可并行，但正式工程扩展遵守观察 Gate。

### Track A：Android 楞严与多产品

- Gate F2 后按 `.planning/ANDROID_MULTI_PRODUCT_PORTING_PLAN.md` 建立 Android 原生工程。
- 《楞严经》生产级 Android 在有限并行下预计 16-24 周，**不包含 Foundation 0-2**；各阶段完全串行或外部验证受阻时应按最多约 27 周预留。它可与 Track I1/I2 并行，但共享 schema 修改需同一 PR 验证两平台。
- Android 楞严发布 Gate 通过后才创建《金刚经》Android module；经文/权利/音频已批准后的 Android 增量工程预计 4-6 周。
- Android 后续顺序同样是《金刚经》→《圆觉经》→《六祖坛经》。

### Track C：内容、音频和权利（可并行）

- 《金刚经》底本、三十二分结构、简繁例外、精选、来源和授权先行。
- 《圆觉经》《六祖坛经》只做来源/版本/权利准备，不在观察 Gate 前复制完整工程。
- 母带、转码、checksum、朗读授权和 CDN 预估由独立清单管理。

AI 会缩短编码、差异检查和文档时间，但不能压缩授权、录音、校对、商店审核和真实用户观察。产品计划中的 9-15 个月是三款新产品的内容与主发布线周期，不是“双平台全部上架”的承诺。按一名产品负责人 + Codex、有限并行和内容/音频按期就绪假设，双平台组合先按 **12-20 个月容量区间**规划，并在 Android Gate H 与金刚经 iOS I3 后用真实交付速度重新估算。

## 14. 决策 Gate

### 14.1 已锁定方向

- 一个 monorepo、多个独立单经 App。
- iOS/Android 原生 UI 和系统集成。
- 平台内共享实现、平台间共享 schema/fixtures。
- stable paragraph ID，不持久化设备页码作为跨版本身份。
- 大音频离开 Git；新产品以 CDN/object storage 为默认交付。
- 《金刚经》→《圆觉经》→《六祖坛经》的产品顺序。

### 14.2 Phase 0-2 必须人工确定

| 决策 | 推荐默认 | 冻结时点 |
|---|---|---|
| iOS 新产品最低版本 | 先保持 iOS 15，依据设备数据再提高 | Asset delivery ADR |
| 新产品是否采用 Managed packs | 楞严 Gate I0 通过后再按产品评估，不因代码已存在而默认复制 | 新产品 audio delivery ADR |
| Android `minSdk` | 暂定 26，按目标用户/渠道设备数据验证 | Android 工程创建前 |
| iOS/Android 永久应用身份 | 沿用明确 publisher namespace，每款独立 | 创建商店记录前 |
| 签名密钥 | 每款独立；人工离线备份，CI 仅用受控凭据 | 首个 release candidate 前 |
| CDN/对象存储 | 另选支持 Range/恢复/目标地区的主 host；现有 `workers.dev` 仅是楞严应急源 | Android/新产品 audio prototype 前 |
| Android 音频存储体验 | 推荐当前卷按需准备、下一卷受控预取、自动缓存；不默认复制已删除的技术存储页 | Android Phase 0 |
| XcodeGen | 等价性试验通过才采用 | 第二 iOS Target 前 |
| Android 自动备份 | 默认关闭以符合当前“本地保存”承诺；若开启需先更新隐私 | Android release 前 |
| 首批 Android 渠道 | Google Play international；大陆作为独立 Gate | 包名/签名冻结前 |

### 14.3 不允许隐式决定

AI 不得通过创建占位商店 App、生成生产 key、提高最低系统、启用云备份、增加第三方 analytics/SDK、选择底本或修改经文来“推进进度”。这些动作必须有显式 ADR/人工批准。

## 15. 跨平台主要风险

| 风险 | 控制措施 |
|---|---|
| 两份计划或旧文档继续漂移 | 文档职责表、ADR supersedes、AGENTS 路由和 drift check |
| 共享 manifest 变成万能配置 | 只配置稳定差异；产品独特体验保留薄壳代码 |
| iOS/Android 内容不一致 | 单一 canonical source、schema、hash 和双平台 fixtures |
| 架构重构破坏楞严老用户 | reference commit、legacy ID map、迁移 fixtures、兼容 facade |
| 音频交付绑定单一商店 | artifact/delivery 分层、CDN baseline、provider 边界 |
| Git 和 CI 继续变慢 | 禁止新增大音频、普通 PR 不拉全量、历史清理独立项目 |
| AI 在脏工作区互相覆盖 | 独立 worktree、短分支、文件所有权和小提交 |
| 假 CI 或窄测试给出错误信心 | 公共 verify 入口、真实 artifacts、reference devices、二次 review |
| 服务端与隐私说明不一致 | privacy data-flow contract、schema/migration tests、人工发布 Gate |
| 多产品发布身份/签名出错 | 永久 ID checklist、每款独立 key、离线恢复演练 |

## 16. 开工与完成门槛

可以开始 Foundation 0 的条件：

- 认可本文件的文档职责和“一个 monorepo、多个独立 App、原生双平台”方向。
- 指定产品/发布批准人与经文内容负责人；可以是同一人，但每次批准要区分角色。
- 允许先整理当前工作区和可信 CI，不直接复制《金刚经》Target 或 Android UI 抢进度。

共享 Foundation 只有满足以下条件才算完成：

- 干净克隆可运行文档中的公共命令，且缺工具会明确失败。
- 当前楞严 iOS 的 Scheme、build、unit/UI smoke、内容和反馈 tests 真实执行。
- schema v1、stable ID、legacy map、behavior fixtures 和 audio artifact manifest 已提交并双人/双上下文 review。
- 现有 11 条音频的 Swift/Node/checksum/Apple manifests 已由同一 canonical manifest 生成或结构化校验，不再靠正则解析源码维持一致。
- CI 不再包含假无障碍、假性能或不存在的 Package 命令。
- `CLAUDE.md`、`REQUIREMENTS.md`、`AGENTS.md` 和实际命令不存在互相冲突的活跃指令。
- 没有新增大型音频、生产 secrets 或未经批准的应用身份。

## 17. 最终建议

**可以实施。F0 已由干净 checkpoint、104 个 unit tests 和迁移关键专门回归关闭；当前工作是完成统一验证入口和真实 CI，再将现行楞严交付 catalog 演进为“跨产品 artifact + 平台 delivery”契约。Gate F2 前不创建新 App 壳；Gate F2 后让 iOS 模块化与 Android 楞严有限并行，共享经文、身份、音频 artifact 和行为证据，UI、播放、Widget、存储与发布保持平台原生。**

## 参考

- Codex 对仓库持久指令的建议：[AGENTS Guidance](https://learn.chatgpt.com/docs/customization/overview#agents-guidance)
- Apple 对本地 Swift Package 的组织方式：[Organizing your code with local packages](https://developer.apple.com/documentation/Xcode/organizing-your-code-with-local-packages)
- Apple 的 ODR 弃用说明：[On-demand resource size limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits/)
- Apple 的后续资源方案：[Background Assets](https://developer.apple.com/documentation/backgroundassets/)
- Apple-Hosted Managed Background Assets 的系统要求：[Overview of Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs)
- XcodeGen 的声明式 Target/Scheme 配置：[XcodeGen GitHub](https://github.com/yonaskolb/XcodeGen)
- Android 官方架构建议：[Recommendations for Android architecture](https://developer.android.com/topic/architecture/recommendations)
