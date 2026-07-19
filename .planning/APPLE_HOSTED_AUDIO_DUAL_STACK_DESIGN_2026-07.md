# 楞严经音频双轨交付设计：iOS 15–25 ODR + iOS 26+ Apple 托管资源包

设计日期：2026-07-19\
工程：`lengyan-app`\
最低系统：iOS 15.0\
状态：M1/M2 已实施；发布端 hosted 验证待后续补齐

> 2026-07-19 实施授权更新：用户明确要求不等待 TestFlight / Validate，
> 直接完成双栈改造。因此 M0 发布闸门不再阻止实施，但未完成的
> Apple-hosted 真实链路证据仍必须如实记录，不视为已验收。

> 本文记录已经选定的 Apple-hosted 方向。它取代
> `ODR_BACKGROUND_ASSETS_AUDIO_MIGRATION_PLAN_2026-07.md` 中“R2/HLS 为主路径”的建议；
> 原文仍保留作方案比较和音频编码研究，不代表当前实施决定。

## 0. 决策摘要

采用一个播放器、一套资源协调逻辑、两个系统下载后端：

| 系统 | 资源后端 | 行为 |
|---|---|---|
| iOS 15–25 | 现有 `NSBundleResourceRequest` / ODR | 保持可安装、可播放、播放当前卷时静默准备下一卷 |
| iOS 26+ | Apple-hosted Managed Background Assets | 每卷 `onDemand` 下载，复用同一套“当前卷 + 下一卷”状态机 |

核心决定：

1. 现有 11 个有效音频继续保持 11 个 ODR tag；移除 `ly01` 的 initial-install 属性，避免 iOS 26 安装旧 ODR 卷一后又下载 Managed 卷一。工程中无资源引用的陈旧 `KnownAssetTags` 项 `lyzpg1` 在 M1 清理。
2. 新增 11 个 Managed asset packs：卷一至卷十各一包，楞严咒单独一包。
3. Managed manifests 全部使用 `onDemand`。播放开始后，由 App 显式请求下一包来实现动态静默预取；不能把 manifest 写成 `prefetch`，后者是安装/更新策略，不是“只下载下一卷”。
4. 播放器不直接接触 ODR 或 `AssetPackManager`。统一资源层返回一个带生命周期的本地 URL lease。
5. 同一资源最多一个底层下载任务。静默预取中的下一卷被用户点选时，直接把现有请求提升为前台请求，不重新下载。
6. 每次选曲都有 generation/token；迟到的旧请求只能更新缓存状态，绝不能抢播。
7. ODR 活跃访问最多保留“当前播放 + 下一卷预取”两个；Managed 已下载文件默认保留，因为全部音频目前约 154 MiB，但提供显式清理能力。
8. 先做一个小 pack 的双系统 POC。原始计划要求发布闸门后才改造；后续用户明确豁免 TestFlight/Validate 前置闸门，允许直接实施，未测项仍保留为发布风险。

## 1. 当前基线与必须保持的体验

工程当前有 11 个 `.m4a`：

| 逻辑顺序 | 资源 ID | 当前 ODR tag | Managed pack ID（建议） | 大小约 |
|---:|---|---|---|---:|
| 1 | `ly01` | `ly01`，on demand | `org.fuxuan.lengyan.audio.ly01` | 10.9 MiB |
| 2 | `ly02` | `ly02` | `org.fuxuan.lengyan.audio.ly02` | 14.1 MiB |
| 3 | `ly03` | `ly03` | `org.fuxuan.lengyan.audio.ly03` | 14.9 MiB |
| 4 | `ly04` | `ly04` | `org.fuxuan.lengyan.audio.ly04` | 15.8 MiB |
| 5 | `ly05` | `ly05` | `org.fuxuan.lengyan.audio.ly05` | 12.4 MiB |
| 6 | `ly06` | `ly06` | `org.fuxuan.lengyan.audio.ly06` | 13.7 MiB |
| 7 | `ly07` | `ly07` | `org.fuxuan.lengyan.audio.ly07` | 15.7 MiB |
| 8 | `ly08` | `ly08` | `org.fuxuan.lengyan.audio.ly08` | 14.9 MiB |
| 9 | `ly09` | `ly09` | `org.fuxuan.lengyan.audio.ly09` | 20.1 MiB |
| 10 | `ly10` | `ly10` | `org.fuxuan.lengyan.audio.ly10` | 15.8 MiB |
| 11 | `lyz1` | `lyz1` | `org.fuxuan.lengyan.audio.lyz1` | 5.6 MiB |

总资源约 153.9 MiB。Release 已设置 `EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE = NO`，必须保持。

当前 `repeatAll` 顺序为：

```text
ly01 → ly02 → … → ly10 → lyz1 → ly01
```

必须保持以下用户体验：

- 用户开始真正播放当前卷后，下一卷在 UI 不打扰用户的情况下开始准备。
- 下一卷准备完成后，上一卷结束不再等待下载，并在播放器切换开销内尽快衔接。本阶段不把它表述为采样级无缝/gapless；若以后要求真正无缝，需另做下一 `AVPlayerItem` 预入队与双 lease 设计。
- 若尚未完成，上一卷正常播放不受影响；到切换时才显示下载进度或错误。
- 用户主动点选正在静默准备的下一卷时，显示同一个任务的进度，不启动第二次下载。
- `repeatOne`、播放一次和指定次数模式不自动准备其他卷。
- 楞严咒结束后的“下一卷”是卷一。

## 2. 资源包设计与审核发布

### 2.1 一音频一包

每个 Managed pack 只含一个稳定路径，例如卷一：

```json
{
  "assetPackID": "org.fuxuan.lengyan.audio.ly01",
  "downloadPolicy": { "onDemand": {} },
  "fileSelectors": [
    { "file": "Audio/ly01.m4a" }
  ],
  "platforms": ["iOS"]
}
```

好处：

- 用户只下载所选的一卷；
- “下一卷”请求不会带上无关音频；
- 可逐卷删除、重试、更新；
- 同一套稳定 ID 可直接映射旧 ODR tag 与新 pack ID。

不同 pack 不得包含相同相对路径。已下载的 packs 会合并到共享命名空间；同一路径冲突的行为不能依赖。

### 2.2 为什么保留 11 包

Apple 的限制是每次 App Review submission 最多包含 10 个不同 packs，不是每个 App 只能有 10 个。每个 App 最多 200 packs、总量 200 GB。

首发顺序：

1. 提交 `ly01`–`ly10` 十个 packs；
2. 第一批可分发后，单独提交 `lyz1`；
3. 两批都可分发后，再发布启用 Managed 后端的 App build；
4. 若 App Store Connect 要求 pack 与 build 同批，先用关闭 Managed 路由的兼容 build 完成资源审核，再启用新路由。

不建议仅为省掉第二次审核而把一个音频塞入主 bundle；那会让所有 iOS 15–25 用户也永久承担该体积。也不建议把楞严咒和某卷合并；用户会下载无关内容，清理粒度也会绑定。

双轨版本移除 `ly01` 的 **initial-install 属性，但保留 `ly01` ODR tag**。这样 iOS 26+ 不会在安装阶段取得一份不会作为主路径使用的旧 ODR 卷一，避免 Managed 再下载卷一时约 10.9 MiB 的双份占用。代价是 iOS 15–25 的新安装用户首次播放卷一时也需要按需下载；现有即时进度反馈负责承接这段等待。

### 2.3 更新约束

- `assetPackID`、相对路径和音频格式对同一内容世代保持稳定。
- 同一 pack ID 的新 live 版本会提供给旧 App build，因此更新必须向后兼容。
- 如果未来改成不兼容的编码、目录或播放器约定，使用新 pack ID，例如 `...ly01.v2`，由新 App catalog 选择。
- 不持久化 `AssetPackManager` 返回的本地 URL；每次进程启动后重新解析。

## 3. 总体架构

```text
列表 / 阅读页 / 锁屏上一首下一首
              │
              ▼
        AudioManager (@MainActor)
        选择 token、UI、播放模式
              │
              ▼
      AudioAssetCoordinator (actor)
      去重、当前 lease、下一卷预取
          ┌───┴──────────────────┐
          ▼                      ▼
 iOS 15–25 ODR Provider   iOS 26+ Managed Provider
 NSBundleResourceRequest   AssetPackManager
          └───┬──────────────────┘
              ▼
       AudioAssetLease(localURL)
              │
              ▼
       AudioPlayerObserver / AVPlayer
```

版本判断只在 provider factory 中出现：

```swift
if #available(iOS 26.0, *),
   policy.managedEnabled,
   catalog.managedPacksReady {
    // ManagedBackgroundAssetsAudioAssetProvider
} else {
    // LegacyODRAudioAssetProvider
}
```

实际 factory/router 还要接收 Managed feature flag、pack catalog readiness 和 fallback policy：只有系统版本满足、开关启用且 catalog 已就绪时才返回 Managed，否则返回 ODR。播放器、列表和阅读页不散落系统版本或灰度判断。受控 fallback 前必须先取消/释放 Managed consumer，禁止两套后端同时下载同一卷。

### 3.1 建议文件

新增：

- `lengyan/Domain/AudioAssets/AudioAssetModels.swift`
- `lengyan/Domain/AudioAssets/AudioAssetProvider.swift`
- `lengyan/Domain/AudioAssets/AudioAssetCoordinator.swift`
- `lengyan/Domain/AudioAssets/LegacyODRAudioAssetProvider.swift`
- `lengyan/Domain/AudioAssets/ManagedBackgroundAssetsAudioAssetProvider.swift`
- `lengyan/Domain/AudioAssets/AudioAssetProviderFactory.swift`
- `lengyan/Domain/AudioAssets/AudioAssetCatalog.swift`

调整：

- `AudioManager.swift`：保留公开入口、播放模式和 UI 映射；移除直接 ODR、两个轮询 Timer 和 `resourceRequests`。
- `AudioPlayerObserver.swift`：增加明确的 `replaceItem(url:)`、`stopAndRemoveItem()` 与“本代曲目首次真正播放”事件。
- `MediaModels.swift`：把内容 ID 与交付信息稳定关联；播放状态和资源交付状态分开。
- App target / 新 downloader extension：共享 App Group 和 Background Assets 配置。

## 4. 统一资源契约

不能只返回裸 `URL`。ODR URL 仅在相应 `NSBundleResourceRequest` 保持访问期间有效，所以统一层必须返回带生命周期的 lease：

```swift
struct AudioAssetDescriptor: Hashable, Sendable {
    let id: String
    let fileName: String
    let fileExtension: String
    let odrTag: String
    let managedPackID: String
    let managedRelativePath: String
}

enum AudioAssetIntent: Sendable {
    case playback
    case prefetch(ownerID: String)
}

enum AudioAssetEvent: Sendable {
    case queued
    case progress(completed: Int64, total: Int64?)
    case ready(AudioAssetLease)
}

struct AudioAssetRequestHandle: Sendable {
    let requestID: UUID
    let assetID: String
    let events: AsyncThrowingStream<AudioAssetEvent, Error>
}

final class AudioAssetLease: @unchecked Sendable {
    let id: UUID
    let assetID: String
    let localURL: URL
}

enum AudioAssetEvictionResult: Sendable {
    case removed
    case releasedToSystem
}

protocol AudioAssetProvider: Sendable {
    func request(_ asset: AudioAssetDescriptor,
                 intent: AudioAssetIntent) async -> AudioAssetRequestHandle
    func promote(requestID: UUID) async
    func cancel(requestID: UUID) async
    func release(_ lease: AudioAssetLease) async
    func evict(assetID: String) async throws -> AudioAssetEvictionResult
}
```

`request` 先登记 consumer 并立即返回 handle，终态 `ready` 事件才携带 lease；因此下载尚未完成时也能取消或提升。上面只表达边界，不作为最终可编译签名。

必须满足的不变量：

1. 每个 asset 同时最多一个底层传输。
2. playback 与 prefetch 是不同 request/consumer ID；取消一个 consumer 不能误杀另一个仍需要的请求。
3. 每个 ODR request 最多调用一次 `beginAccessingResources`。
4. 每次调用 `beginAccessingResources` 后，无论完成回调成功或失败，都必须且只能调用一次 `endAccessingResources`；`conditionallyBeginAccessingResources` 返回 true 的访问也必须配对一次 end。
5. lease 未释放前，本地 URL 必须有效；provider 按 lease UUID 幂等 release，重复 release 不可重复 end/remove。
6. 播放器最多持有一个 current lease；协调器最多另持有一个 next-prefetch lease。
7. 任何异步完成只有在 selection token 仍匹配时才可替换播放器。

## 5. 状态模型

资源交付状态与 AVPlayer 播放状态分开：

```text
unknown
  → checking
    ├─ local → ready
    └─ remote → acquiring(intent, progress)
                  ├─ prefetch + 用户点选 → acquiring(playback, same task)
                  ├─ success → ready(lease)
                  ├─ cancel → unknown
                  └─ failure → failed(retryable)

ready(prefetched)
  ├─ 成为下一首 → ready(playing)，转移同一 lease
  └─ 目标变化/模式变化 → release

ready(playing)
  └─ 新 AVPlayerItem 已接管/stop → release
```

协调器同时维护三个不同概念，不能再用一个 `currentTrack` 混用：

- `requestedAssetID`：用户最后一次选择，用于 selection token；
- `pendingAssetID`：正在取得、尚未交给播放器的资源；
- `playingAssetID`：AVPlayer 当前实际装载的资源，也是锁屏 Now Playing 标题的唯一依据。

请求 B 失败而 A 仍可播放时，清空 pending、在 B 行显示错误，但锁屏和播放器仍显示 A。

首版 UI 可继续映射为现有四态：

- 静默 prefetch：列表仍显示 `notDownloaded`，不弹 UI；
- 用户点中 prefetch：显示 `downloading` 和真实进度；
- ready：显示 `downloaded`；
- 失败：显示 `error` 和重试。

不要把 `downloaded` 布尔值当成跨启动事实。ODR 可能被系统回收；Managed 也可能被用户清除。进程重启后应向 provider 核实，无法无副作用核实时先显示 `unknown`，不要伪造已下载。

## 6. 当前卷与下一卷的精确时序

### 6.1 用户选择当前卷

```text
select(track B)
  1. 生成 selectionToken B
  2. 若 B 正是 next prefetch：复用并 promote；否则 request(.playback)
  3. 展示 B 的前台进度
  4. ready 回来后检查 token 仍是 B
  5. AVPlayer 安装 B 的 item
  6. 保存 B current lease
  7. 新 item 接管后才释放旧 current lease
  8. B 首次真正开始播放时，触发一次 next prefetch
```

如果用户先点 A、再点 B，而 A 最后才完成，A 的 token 已失效，绝不能播放。Managed 释放其逻辑 lease 后可让已下载 pack 留在磁盘；ODR 必须立即 release/end，不能把迟到结果继续钉住而突破 current + next 上限。

若 B 下载失败，保留旧曲目的 item 和 lease；用户仍可恢复旧曲目，不因一次失败把播放器清空。

### 6.2 静默准备下一卷

触发条件：

- 当前 item 已 `readyToPlay`，并且播放器 rate 首次大于 0；
- 当前 selection generation 尚有效；
- 模式仍为 `repeatAll`；
- 本 generation 尚未触发过；
- next 与 current 不同。

这是对现有实现的一项有意修正：当前代码在插入 `AVPlayerItem` 后就预取，即使恢复出的 item 尚未真正播放。新实现只在真正播放后预取，避免“仅打开过播放器但没听”也消耗流量；M1 的目标是保持用户体验，不是逐行保留这个副作用。

触发后：

- ODR：默认/较低优先级开始 `beginAccessingResources`；
- Managed：对下一包调用 `ensureLocalAvailability`，UI 保持安静；Managed 没有文档化的 `loadingPriority` 等价 API；
- 用户点选 next：复用任务。ODR 把 `loadingPriority` 调成 urgent；Managed 只把任务标为前台并显示进度；
- 当前卷结束而 next 尚未 ready：复用任务并进入可见等待，ready 后自动播放；
- 当前卷继续正常播放，next 失败不能打断 current。

### 6.3 何时取消 next

- 播放模式离开 `repeatAll`；
- 用户选了不是 current、也不是 next 的其他曲目；
- 播放器 stop/清空；
- ODR 发出低磁盘通知；
- App 在后台长时间暂停，且没有即将继续播放的依据（第二阶段策略）。

取消 Managed 系统下载时，必须调用下载状态提供的 `Progress.cancel()`；只取消 Swift `Task` 不等于取消系统下载。若同一资源还有 playback consumer，则不得取消底层下载。

## 7. 两个 provider 的实现边界

### 7.1 Legacy ODR，iOS 15–25

`LegacyODRAudioAssetProvider` 负责：

- 精确持有 `[assetID: Entry]`，每个 entry 包含 request、generation、consumers、lease、`beginCallbackReceived` 和 `endCalled`；
- 先 `conditionallyBeginAccessingResources`：返回 true 表示已取得访问，最终必须 end；返回 false 表示尚未取得访问，可在同一 request 上调用 `beginAccessingResources`；
- prefetch 转 playback 时提高 `loadingPriority`，不再调用一次 `begin...`；
- 观察 `Progress`，用 async events 代替当前 0.1/0.2 秒 Timer 轮询；
- 最后一个 lease/consumer 释放后，对捕获的精确 request 调用 `endAccessingResources`；Apple 要求每次 begin 在完成回调到达后都配对 end，即使回调带 error；
- 最后一个 consumer 取消且下载未完成时调用 `request.progress.cancel()`，等待 begin 完成回调（通常为取消错误）后再 exactly-once end；不得在回调前调用 end；
- 收到 `NSBundleResourceRequestLowDiskSpaceNotification` 时先释放 next，绝不打断 current。

`endAccessingResources` 只表示 App 不再占用，并不保证文件立即从磁盘删除；ODR 的 `evict` 只能 release 并降低 preservation priority，返回 `releasedToSystem`，实际回收仍由系统决定。

### 7.2 Managed Background Assets，iOS 26+

`ManagedBackgroundAssetsAudioAssetProvider` 负责：

1. 先启动 `statusUpdates(forAssetPackWithID:)` 监听；
2. 用 `assetPack(withID:)` 获取 pack；
3. 调用 `ensureLocalAvailability`；
4. 成功后通过稳定相对路径重新解析 URL；
5. `finished`/`failed`、`ensure...` 返回/抛错、最后一个 consumer 离开或 provider shutdown 时结束本次监听 Task；取消路径不能假设一定收到 terminal event，entry 销毁时必须主动取消监听；
6. 用 pack ID 任务表合并 playback 与 prefetch consumers；
7. 取消时调用事件中 `Progress.cancel()`；失败后再次 `ensure...` 即重试；
8. 只有没有播放/预取 lease 时才允许 `remove(assetPackWithID:)`。

版本分支：

- iOS 26.0–26.3：使用 `ensureLocalAvailability(of:)`；
- iOS 26.4+：音频播放优先使用 `ensureLocalAvailability(of:requireLatestVersion: false)`，已有可用版本时不为更新阻塞播放；若未来内容有强制更新需求才改为 `true`。

App 主动调用 `checkForUpdates()` 首版只安排在没有 active current lease 的时机。Apple 仍可能自动更新已下载 pack，因此 POC 必须验证“当前 URL 正在播放时新版本到达”的行为；在确认其文件生命周期前，不把 app-triggered update 与当前播放并发。

Managed pack 在 App 仍安装时不会自动删除。系统会后台更新已下载 pack，但 App 必须自己提供空间释放策略。

## 8. 本地空间策略

“下载任务”和“磁盘上仍有文件”是两件事：

- 活跃访问上限：current + next 两个。
- ODR：release 后交给系统保留或淘汰。
- Managed：当前总量只有约 154 MiB，首版默认保留所有成功下载的卷，避免用户反复听时重复耗流量。
- 设置页后续增加“已下载音频占用”和“删除全部”；也可逐卷删除。Managed 可保证调用 remove，ODR 只能释放给系统回收，界面文案必须反映这个差异。
- 当前播放卷不可删除；next 正在准备时先取消，再删除；删除操作与 player lease 串行化。
- 若以后音频扩展超过约 256 MiB，再加入 LRU/上限策略；不要在首版偷偷删除刚听过的卷。

继续保留现有“蜂窝网络也可静默准备”的行为，避免本次迁移暗改产品语义。后续可单独增加“仅 Wi‑Fi 预下载下一卷”选项；低数据模式、低电量和系统调度下的真实行为必须通过 POC 测量，不自行承诺。

## 9. Extension 与配置

Apple-hosted Managed packs 需要：

- 新建 Managed Background Download extension；
- extension 使用 iOS 26+ `StoreDownloaderExtension`；
- 主 App 与 extension 共享 App Group；POC 可先复用现有 `group.org.fuxuan.books`，减少签名变量；
- 主 App Info 配置 `BAAppGroupID`、`BAHasManagedAssetPacks = YES`、`BAUsesAppleHosting = YES`；
- 使用 Xcode 26 的 `ba-package` 生成 `.aar`，本地用 Apple 提供的测试流程验证，再上传 App Store Connect。

必须先验证 Apple 文档未明确保证的组合：

```text
主 App deployment target iOS 15
  + embedded downloader extension iOS 26+
  + 同一 build 继续包含 ODR 交付
  + 同一 App Store 版本按运行系统切换两套后端
```

这是发布门槛，不是可推迟到上线后的普通测试。

## 10. 降级与故障处理

- iOS 15–25 永远选 ODR。
- iOS 26+ 默认选 Managed，但首发保留构建开关/配置开关，可整体切回 ODR 以便 TestFlight 灰度。
- 普通断网、用户取消或空间不足时，不自动偷偷再发起一次 ODR 大下载；显示可重试错误即可。
- 只有明确属于 pack 缺失、配置错误或 Apple-hosted 发布事故时，才允许受控回退 ODR，并记录原因，防止 Managed 与 ODR 双份下载互相打架。
- 当前播放不因 next 预取失败中断。
- App 被挂起或杀死后，on-demand 是否继续、取消后是否断点续传，Apple 没有给出足够强的保证；实现不能假设，交给 POC 决定恢复策略。

## 11. 实施里程碑

### M0：一个小 pack 的可行性 POC

- 主 App 保持 deployment target 15.0；extension 采用可通过编译/签名的最窄 iOS 26 配置。
- 加一个非生产小文件的 `onDemand` pack。
- 完成 Archive、Validate 和 TestFlight/App Store hosted 流程。
- iOS 15、25：安装、启动、现有 ODR 播放与 next prefetch。
- iOS 26.0、26.4、27：Managed 下载、进度、取消、重试、播放。
- 验证同一 Archive 的 ODR 产物没有丢失，旧系统不会加载 extension-only API。

POC 失败时停止 Managed 全量改造：继续全系统 ODR，直到最低系统可提升，或重新选择自托管方案。

### M1：先重构 ODR，不改变后端

- 加 catalog、provider 协议、fake provider、coordinator 和 lease。
- factory 暂时在所有系统返回 ODR。
- 修复 selection token、精确 request 释放、Timer 轮询和模式切换取消。
- 从 Xcode `KnownAssetTags` 删除无资源引用的陈旧 `lyzpg1`，保留 11 个有效 ODR tags。
- 接入 memory warning、播放模式变化、stop/remove item、后台长时间暂停、ODR low-disk 通知注册/注销，以及 terminate 时 best-effort `releaseAll`；正确性不得依赖 terminate。
- 验证用户可见体验与当前版本一致，并确认“选中但没有真正播放”不再触发 next prefetch 这一有意修正。

### M2：Managed 后端与 extension

- 实现 iOS 26/26.4 API 分支。
- 生成 11 个 `.aar` 与 manifest 校验脚本。
- 完成 10 + 1 两批资源审核。
- 上线前完成基础空间管理：显示 Managed 已下载占用、删除全部；逐卷删除可随后补齐。
- TestFlight 仅对 iOS 26+ 启用 Managed；旧系统继续 ODR。

### M3：生产灰度

- 小比例/内部开关启用 Managed。
- 测量中国移动、联通、电信及常见 Wi‑Fi 下每包获取时间、失败率和下一卷命中率。
- 确认一整卷播放期间足以完成下一卷下载；不对 Apple 中国大陆链路作未经实测的 SLA 承诺。
- 稳定后默认启用，继续保留 ODR 代码和资源作为旧系统路径。

### M4：缓存管理

- 增加逐卷删除、缓存详情和失败恢复。
- 音频继续扩张时再实现 LRU/容量上限；基础“占用 + 删除全部”不是 M4 才开始。

## 12. 验收与测试矩阵

单元测试：

- provider router：15/25 → ODR；26+ 仅在 feature flag 与 catalog readiness 都满足时 → Managed；fallback 前已停止旧 Managed consumer；
- catalog 精确顺序为 `ly01...ly10, lyz1`，简繁 media manifests 一致；
- 11 个内容 ID 与 11 个唯一 ODR tags、pack IDs、相对路径一一对应，工程没有额外 `lyzpg1`；
- 每个 Managed pack 恰好含预期 M4A，大小/哈希匹配且文件可完整解码；
- 一个 asset 只有一个底层下载；
- prefetch → playback 复用同一任务；
- A 后 B 的迟到 A 永不抢播；
- B 下载失败时 Now Playing/`playingAssetID` 仍是 A，B 只处于错误状态；
- ODR 每次 begin 完成回调（含错误/取消）后恰好一次 end；conditional false 不提前 end，conditional true 最终 end；
- 重复 release 同一 lease 不会重复 end/remove；
- 活跃 lease 最多 current + next；
- 仅 `repeatAll` 预取，切换模式立即取消/释放；
- item 被选中或恢复但未真正开始播放时不预取；
- `lyz1 → ly01` 正确回环；
- 低磁盘只释放 next，不释放 current；
- 删除 Managed pack 不与播放 lease 并发；
- consumer 全部离开、取消无 terminal event、provider shutdown 时均无残留 status listener。

集成测试：

- iOS 15、25 的 ODR 本地命中、首次下载、预取提升、失败重试、低磁盘；
- iOS 26.0 与 26.4+ 的 API 分支；
- 当前卷播放中杀进程、切后台、断网/恢复；
- 取消后的重试是续传还是重下；
- 当前 pack 正在播放时系统自动更新到新版本，以及无 current lease 时主动 `checkForUpdates()`；
- pack v2 上线后旧 App build 仍能按原路径播放；
- App Store/TestFlight 下 10 + 1 packs 全部可获取；
- 中国三网下记录首包时间和 next-prefetch 命中率。

Archive 检查：

- Release 仍为 `EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE = NO`；
- 主 App 没有意外嵌入 154 MiB 音频；
- 旧 ODR manifests/asset packs 仍存在；
- `KnownAssetTags` 仅含 11 个实际音频 tags，不含陈旧 `lyzpg1`；
- downloader extension 已签名嵌入；
- iOS 15/25 可安装且启动时不触发 iOS 26 symbol。

## 13. 官方依据

- [Creating managed asset packs](https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs)
- [Downloading Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)
- [Submit Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-apple-hosted-asset-packs/)
- [Apple-hosted asset pack limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits)
- [Discover Apple-Hosted Background Assets, WWDC25](https://developer.apple.com/videos/play/wwdc2025/325/)
- [ODR: Managing Requests](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/Managing.html)
- [ODR: Linear progression and preservation](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/PreservingDownloadedResources.html)
