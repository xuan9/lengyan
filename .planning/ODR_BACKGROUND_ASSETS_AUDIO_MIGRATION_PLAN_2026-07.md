# 楞严经音频：ODR 退场、点播、离线缓存与 CDN 迁移计划

研究日期：2026-07-18\
适用工程：lengyan-app，当前最低系统 iOS 15.0\
状态：研究完成，等待按里程碑实施

> 2026-07-18 发布复核：本报告发现的 asset-pack 发布阻断项已经先行修复。
> 当前 Debug 仍设置 `EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE = YES` 以方便本地测试，
> Release 已改为 `NO`；`ly01` 暂时保留为 initial-install tag。后续 CDN/HLS
> 迁移仍未实施，正文中其余“当前”描述均以研究日代码为基线。

## 0. 最终建议

这项工作不应做成“把 ODR API 一比一换成 Background Assets API”。那样仍然要等整卷下载完才能听，不能解决首播等待，而且 Managed Background Assets 在 App 仍安装时不会自动清理资源。

推荐的目标架构是：

1. 在线播放主路径：Cloudflare R2 Standard + 自定义域名 + 音频 HLS VOD，App 使用 AVPlayer。
2. 边播边存和离线：使用 AVAssetDownloadURLSession / AVAssetDownloadTask。它能在下载 HLS VOD 时播放，并复用相同 rendition 已下载的分片。
3. Apple 托管备用路径：在 iOS 26+ 验证并采用 Apple-Hosted Managed Background Assets，作为“下载完再播”的中国大陆/离线备用来源，而不是流媒体主路径。
4. 旧系统过渡：iOS 15–25 暂留 ODR 作为回退；CDN/HLS 稳定两个版本后，主路径不再依赖 ODR。未来新系统即使移除 ODR，也已有 CDN 路径，iOS 26+ 还可有 Background Assets 回退。
5. CDN 选择：Cloudflare R2 明显优于 GitHub。GitHub Releases 只作为故障备用，不作为主 CDN。免费 Cloudflare 和 GitHub 都不提供中国大陆境内 CDN 保证。
6. App 包：不直接打包全部音频；默认在线听，明确提供“离线下载”。可选的“智能缓存最近收听”默认关闭或只在 Wi‑Fi 下开启。
7. 音频：单声道方向成立，但不能声称会提高源音质。首选候选为 22.05 kHz、mono、AAC-LC 32 kbps；须盲听通过后才替换。若听感不过关，保留当前 44 kbps HE-AACv2 或测试 40 kbps mono。

一句话回答几个核心问题：

- 迁移到哪个免费 CDN：在 Cloudflare 与 GitHub 之间选 R2；若只做整包下载，Apple-Hosted Background Assets 比二者更省运维。
- 是否直接打包：不建议，所有用户都会永久承担约 116–154 MiB。
- 点播是否更好：是，默认点播更符合省空间和快速首播；离线应是用户可见、可管理的选择。
- 点播时顺便缓存整卷是否容易：普通远程 M4A 不容易可靠复用；HLS VOD + AVAssetDownloadTask 是 Apple 原生、复杂度适中的做法。
- 能否读取剩余磁盘：能，不弹权限框；但必须在隐私清单声明 Disk Space / E174.1，且不能把该值传出设备。

## 1. 当前工程的事实与紧急问题

### 1.1 当前不是点播

现有链路是整文件 ODR 下载完成后，再拿本地 Bundle URL 创建 AVPlayerItem：

- 11 个资源分别使用 ly01–ly10、lyz1 标签：lengyan.xcodeproj/project.pbxproj:73–83。
- 点击曲目后调用 beginAccessingResources：lengyan/Domain/AudioManager.swift:128–214。
- 成功后才从 request.bundle.url 读取本地文件并播放：AudioManager.swift:250–314。
- 默认 repeatAll，并静默下载下一整卷：AudioManager.swift:19、338–341、509–555。

所以目前“等待下载”不是播放器缓冲，而是整卷必须先落地。

### 1.2 P0（已修复）：Release 曾把所有音频直接嵌入 App

报告初审时 Debug 和 Release 都配置了：

- EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE = YES：project.pbxproj:1051、1080。
- ly01 是 initial-install tag：project.pbxproj:1059、1088。

Apple 的 Build Settings Reference 明确说，Embed Asset Packs 会把所有已构建的 asset packs 放进产品包，只适合无服务器测试，因为它会抵消 ODR 的体积收益。

2026-07-18 已将 Release 改为不嵌入 asset packs，Debug 保持嵌入；`ly01`
仍作为首卷 initial-install tag。发布 Archive 仍须实际解开 IPA，确认完整音频没有进入
主 App bundle。后续实施时继续遵循：

- Archive 后实际解开 IPA，证明完整音频没有进入主 App bundle。
- 去掉 ly01 的 initial-install，除非产品明确要求第一卷随安装占空间。

官方依据：[Embed Asset Packs In Product Bundle](https://developer.apple.com/documentation/xcode/build-settings-reference)。

### 1.3 P0：当前代码阻止 ODR 自动回收

成功的 NSBundleResourceRequest 长期保存在 AudioManager.resourceRequests，成功路径不调用 endAccessingResources。预取成功后也继续持有请求。进程存活期间，播放或预取过的包会一直被标为正在使用，系统不能清理。

还存在：

- 默认循环会在用户不知情时预取下一整卷。
- 没有取消、暂停、恢复、仅 Wi‑Fi、手动删除、全部清理、缓存上限、TTL。
- 下载状态只在内存中；重启后不能可靠显示本地状态。
- 快速点击 A、B 时可能并发下载，较晚完成的旧选择反而抢占播放。
- 没有远程 catalog 的版本、大小、哈希、备用源字段。
- 当前播放器没有远端流媒体所需的 buffering、stall、loaded ranges 和错误状态。

这些问题应先修，不能指望换 CDN 后自然消失。

## 2. 音频资产实测

### 2.1 当前资产

| 集合 | 数量 | 格式 | 总时长 | 总体积 |
|---|---:|---|---:|---:|
| source-media 原文件 | 10 | MP3，22.05 kHz，stereo，64 kbps | 7:47:17 | 214.00 MiB |
| App 十卷 | 10 | HE-AACv2，22.05 kHz，stereo，约 44 kbps | 7:47:06 | 148.30 MiB |
| App 楞严咒 | 1 | HE-AACv2，约 44 kbps | 18:15 | 5.65 MiB |
| App 全部音频 | 11 | M4A | 8:05:21 | 153.94 MiB |

原 MP3 并不是真正的高质量母带：它们已经是 22.05 kHz、64 kbps 的有损文件。任何 MP3 → AAC 都是再次有损编码，不能恢复原来已经丢失的细节。

十个源 MP3 在完整解码时各出现一次可恢复的 Header missing / Invalid data 帧错误；现有 11 个 M4A 可完整解码无错误。批量替换前应优先寻找无损或更高码率母带，并把完整解码校验设为发布门槛。

### 2.2 单声道是否合理

全轨左右声道相关度实测约 0.9666–0.9994；大多数轨高于 0.996。L-R 差分能量显著低于主信号。说明录音几乎是单声道人声，转 mono 很有希望。

但第十卷的全轨相关度最低，且个别瞬间可能有相位或立体声内容。盲听必须覆盖：

- 每轨开头和结尾；
- 齿音、爆破音、密集诵读；
- 安静段和背景噪声；
- 第十卷相关度较低的片段；
- iPhone 扬声器、耳机、蓝牙设备。

### 2.3 全量 32 kbps mono 试转结果

从 10 个源 MP3 解码、0.5L + 0.5R 下混、编码为 22.05 kHz mono AAC-LC 32 kbps：

- 十卷合计 110.32 MiB；
- 比当前十卷 148.30 MiB 小 25.6%；
- 若楞严咒暂时保留现状，总音频约 115.97 MiB；
- 比当前全部 153.94 MiB 小约 24.7%；
- 10 个候选文件均能完整解码。

5 分钟代表样本的相对失真测试显示：24、32、40、48 kbps 随码率上升持续改善；24 kbps 体积最小但失真明显更大。客观指标不能替代感知质量，因此当前只能把 32 kbps 定为候选，不能直接宣布为最终规格。

### 2.4 音量也是待处理问题

mono 下混后的综合响度约为 -18.7 至 -23.5 LUFS，轨间差约 4.8 LU；部分轨的 true peak 最高约 +2.4 dBTP，存在编码后峰值过载风险。

建议：

- 先寻找更好的母带，避免用限制器掩盖源文件问题。
- 盲听同时比较“只下混”和“轻量响度/峰值修正”。
- 不要盲目统一到很响的播客标准；诵经内容应保留自然动态。
- 可把 -20 LUFS 左右、true peak 不高于 -1 dBTP 作为测试候选，而不是未经听测的硬规则。

## 3. Apple ODR 与 Background Assets 研究结论

### 3.1 弃用不等于立即失效

Apple 已说明 ODR 从 iOS/iPadOS/tvOS/visionOS 27 起 deprecated，未来版本会移除；当前近期仍可工作。Apple 没公布最终移除的系统版本或日期。

来源：

- [ODR size limits and deprecation note](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits/)
- [App Store What’s New](https://developer.apple.com/app-store/whats-new/)

因此正确动作是现在迁移并保留可回退路径，不是因为“iOS 27 已经不能用”而仓促删除。

### 3.2 Managed Background Assets 的适用范围

- Background Assets 基础框架从 iOS 16 开始。
- Apple-hosted Managed Asset Packs / AssetPackManager 从 iOS 26 开始。
- 当前 App 最低支持 iOS 15，所以 Apple-hosted Managed BA 不能成为唯一实现。
- Managed BA 有 essential、prefetch、onDemand 三种策略。
- 本 App 为节省空间应把所有长音频设为 onDemand，不用 essential 或 prefetch。

官方资料：

- [Background Assets framework](https://developer.apple.com/documentation/backgroundassets)
- [Overview of Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs/)
- [Creating managed asset packs](https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs)
- [Downloading Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)

### 3.3 它最像 ODR，但不是流媒体

ODR → Managed BA 的主要映射：

| ODR | Managed Background Assets |
|---|---|
| ODR tag | Asset Pack ID |
| initial install / prefetch / on-demand tag | essential / prefetch / onDemand |
| beginAccessingResources | ensureLocalAvailability |
| request.progress | statusUpdates AsyncSequence |
| conditionallyBeginAccessingResources | assetPackIsAvailableLocally / localStatus |
| request.bundle.url | AssetPackManager.url(for:) |
| endAccessingResources 后系统可回收 | 没有直接等价；App 必须显式 remove |

ensureLocalAvailability 返回前，整包必须已经本地可用。Apple 所说的 streaming decompression 是资源包解压方式，不表示 AVPlayer 能边下 pack 边播。

### 3.4 Apple-hosted 配额与发布约束

- Apple Developer Program 每个 App 含 200 GB Apple-hosted assets。
- 每个 App record 最多 200 个 asset packs。
- 一次 App Review submission 最多提交 10 个不同 packs。
- 内容可以独立于 App build 更新，但需要审核，不是即时 CDN 发布。
- 同一 pack 的新版本可能被旧 App build 使用，所以路径和格式必须向后兼容；破坏性变化使用新 Pack ID。

本 App 推荐一轨一 pack，共 11 packs，保持最小下载和清理粒度。为绕开单次 10-pack 审核上限，在 App 版本送审前先分 10 + 1 两批让 packs 审核通过，不要为了审核限制把两条长音频永久绑在一个 pack。

来源：

- [Apple-hosted asset pack size limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits)
- [Submit Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-apple-hosted-asset-packs/)
- [Discover Apple-Hosted Background Assets, WWDC25](https://developer.apple.com/videos/play/wwdc2025/325/)

### 3.5 集成要求

需要：

- 新增 Apple-hosted Managed Background Download extension；
- App 和 extension 使用相同 App Group；
- App Info.plist 添加 BAAppGroupID、BAHasManagedAssetPacks、BAUsesAppleHosting；
- 使用 Xcode 的 ba-package 生成 manifest 和 .aar；
- 本地 ba-serve HTTPS 测试；
- TestFlight 与 App Store Connect 上传、版本和审核流程。

当前环境 Xcode 26.6 已有 xcrun ba-package，可开始 POC。

必须先验证一个官方文档没有明确回答的问题：主 App deployment target 15 + Managed extension/runtime 26 的 Archive、App Store validation、iOS 15 安装行为。POC 未通过前，不把 Apple-hosted BA 放到关键路径。

## 4. 方案比较

| 方案 | 首播 | 持久离线 | 自动清理 | iOS 15 | 中国大陆 | 运维 | 结论 |
|---|---|---|---|---|---|---|---|
| 全部打包进 App | 立即 | 是 | 仅卸载 App | 是 | 最稳 | 低 | 不推荐，所有用户永久占空间 |
| Apple-hosted Managed BA | 整包后播放 | 是 | App 显式 remove | 仅 26+ | 值得实测，Apple 未给 SLA | 中 | ODR 等价备用 |
| R2 远端 M4A | 快 | 需另行下载 | App 自管 | 是 | best-effort | 低 | 最快 MVP |
| R2 HLS VOD | 快 | 原生支持边播边下 | AVAssetDownloadStorageManager + App 策略 | 是 | best-effort | 中 | 推荐目标 |
| GitHub Releases | 取决于跳转和网络 | 可下载 | App 自管 | 是 | 无保证 | 低 | 只作备用 |
| Cloudflare/GitHub 免费境内 CDN | — | — | — | — | 不存在保证 | — | 硬性大陆 SLA 需付费 + ICP |

## 5. 推荐的播放与下载产品设计

### 5.1 三种用户可理解的状态

1. 在线播放
   - 默认行为。
   - AVPlayer 播 R2 HLS，尽快出声。
   - 只使用系统临时缓冲，不承诺下次仍在。

2. 智能缓存最近收听
   - 建议默认关闭；也可在首次使用时明确询问。
   - 开启后用 AVAssetDownloadTask 边播边下载相同 HLS asset，避免相同 rendition 的重复 segment 流量。
   - 默认只保留最近 2 轨或最多 64 MiB，30 天未播放即低优先级淘汰。
   - 自动任务只在 Wi‑Fi、非 Low Data Mode、空间充足时开始。

3. 离线保留
   - 用户点击下载图标后开始。
   - 设高 eviction priority，不设置短 TTL。
   - 不静默删除，除非系统极端低空间；App 必须能识别已被系统清理并允许重下。
   - 提供逐轨删除、删除全部、占用空间显示。

### 5.2 播放源优先级

每次播放按下列顺序解析：

1. 当前有效的离线 HLS。
2. 已在本地的 Apple Managed pack 或 legacy ODR。
3. R2 HLS 在线地址。
4. R2 progressive M4A 备用地址。
5. 固定版本的 GitHub Release 地址。
6. iOS 26+ 提示“改为 Apple 托管下载后播放”；旧系统提示重试或使用 legacy ODR。

不要把 failover 放在同一个 Cloudflare Worker 中，否则 Cloudflare 故障时主备一起失效。

### 5.3 普通 AVPlayer 缓冲不能当缓存

preferredForwardBufferDuration 只是系统提示，不保证把整文件下载完，也不保证跨启动保存。

普通 M4A 若想同时播放和保存：

- 另开 URLSessionDownloadTask 可能重复下载；
- 自定义 AVAssetResourceLoader 把 Range 数据写缓存，需要自己处理 seek、并发、断点、校验和状态恢复，首版不值得。

HLS VOD 是更合适的目标，因为 Apple 明确支持 AVAssetDownloadTask 下载时播放，并复用相同 variant 的已下载 segments。

来源：

- [AVAssetDownloadTask](https://developer.apple.com/documentation/avfoundation/avassetdownloadtask)
- [Offline playback and storage](https://developer.apple.com/documentation/avfoundation/offline-playback-and-storage)
- [Using AVFoundation to play and persist HLS](https://developer.apple.com/documentation/avfoundation/using-avfoundation-to-play-and-persist-http-live-streams)
- [preferredForwardBufferDuration](https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredforwardbufferduration)

## 6. Cloudflare、GitHub 与中国大陆

### 6.1 R2 作为主源

截至 2026-07-18，R2 Standard 每月包含：

- 10 GB-month 存储；
- 1,000,000 Class A 操作；
- 10,000,000 Class B 操作；
- 互联网 egress 免费。

当前全部音频不到 0.2 GB，远低于存储额度。假设 300 DAU 每人每天播放 1 小时，32 kbps 音频每月约 130 GB 传输；R2 egress 仍免费。10 秒 HLS segment 约 324 万请求/月，未考虑边缘缓存也低于 1000 万 Class B。

R2 是含免费额度的按量计费服务，通常要完成 subscription checkout；预算告警只发邮件，不会硬性停止账单。

来源：

- [R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [R2 public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- [R2 limits](https://developers.cloudflare.com/r2/platform/limits/)

### 6.2 推荐的 R2 配置

- R2 Standard bucket；创建时可测试 apac location hint，但它只是 best-effort。
- 绑定 audio.example.com 自定义域名。
- 生产关闭 r2.dev；它只适合开发且有限流。
- 音频数据面直接由 R2 custom domain 服务，不经过 Worker。
- 对 /audio/versions/ 路径创建显式 Cache Rule。
- 当前 M4A，以及 HLS 的 M3U8/M4S 都不要依赖默认扩展名缓存列表。
- 音频和 segment 使用内容哈希版本路径，永不覆盖：
  - /audio/versions/v2/ly01/hash/...
- 不可变内容设置一年 TTL 和 immutable。
- catalog 设置短 TTL、ETag，保留内置 fallback。
- M4A 使用 Content-Type audio/mp4。
- HLS playlist 使用 application/vnd.apple.mpegurl。
- 验证 HEAD、bytes=0-0、中间 Range 均返回正确 Content-Length / 206 / Content-Range。
- Cache key 忽略无意义 query string，防止随机参数打散缓存。
- 设置 R2 使用量与低额预算告警。

Cloudflare 支持从缓存处理客户端 Range；源响应必须有 Content-Length。

来源：

- [R2 cache integration](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/)
- [Default cache behavior and Range](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
- [R2 CORS](https://developers.cloudflare.com/r2/buckets/cors/)

### 6.3 GitHub 的正确定位

GitHub Releases 官方允许：

- 每个 release 最多 1000 assets；
- 单文件小于 2 GiB；
- 没有具体的 release 总大小或带宽 feature quota。

但 GitHub AUP 保留在相对过量时限速文件托管、暂停账户或要求迁移的权利；Release 下载还可能返回 302，Range、缓存、CORS 不是为 App 音频给出的稳定服务契约。

因此：

- 只使用固定 tag 的 browser_download_url；
- 客户端跟随 302；
- 不保存跳转后的临时 URL；
- 不用 latest；
- 不用 Pages、raw、Git LFS 作为主源；
- 不把私有 GitHub token 放进 App；
- 仅在录音授权允许公开分发时使用 public Releases。

来源：

- [About GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [Release assets API](https://docs.github.com/en/rest/releases/assets)
- [GitHub Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)
- [Git LFS billing](https://docs.github.com/en/billing/concepts/product-billing/git-lfs)

### 6.4 中国大陆必须诚实处理

Cloudflare 官方说明：

- China Network 是 Enterprise 的独立付费订阅；
- 需要 ICP 与 JD Cloud 内容审核；
- R2 不能直接部署为免费 China Network 内的境内 bucket/custom domain；
- 跨境访问会有明显延迟和可靠性风险。

GitHub 也没有中国大陆专项节点、性能或位置 SLA 的官方保证。

因此免费条件下只能：

- R2 主源 + GitHub Releases 备用；
- iOS 26+ 测试 Apple-hosted BA 下载备用；
- 上线前用中国移动、联通、电信真机测试；
- 用首声时间、失败率、seek 和 rebuffer 数据决定是否默认开启在线听。

如果“中国大陆稳定快速”是硬 SLA，就必须评估有 ICP 的中国对象存储/CDN或 Cloudflare Enterprise China Network，不能在免费账号上承诺。

来源：

- [Cloudflare China Network](https://developers.cloudflare.com/china-network/)
- [China Network available products](https://developers.cloudflare.com/china-network/reference/available-products/)
- [Global Acceleration](https://developers.cloudflare.com/china-network/concepts/global-acceleration/)
- [ICP requirements](https://developers.cloudflare.com/china-network/concepts/icp/)

Apple 没公布 Background Assets 在中国大陆的专门 SLA。认为 Apple 托管更接近 App Store 分发链路只是合理推断，必须以 TestFlight 实测为准。

## 7. 磁盘空间、过期与自动清理

### 7.1 能读取，不需要用户授权弹窗

使用 URLResourceValues：

- 用户明确发起离线下载：volumeAvailableCapacityForImportantUsage。
- 自动预取或智能缓存：volumeAvailableCapacityForOpportunisticUsage。

它们给的是系统认为适合当前用途的可用容量，不是绝对承诺；检查后其他 App 仍可能占用空间，所以必须继续处理 ENOSPC 和下载失败。

来源：

- [Checking volume storage capacity](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity)
- [URLResourceValues](https://developer.apple.com/documentation/foundation/urlresourcevalues)

### 7.2 隐私清单

该 API 是 Required Reason API。lengyan/PrivacyInfo.xcprivacy 当前只有 UserDefaults，没有 Disk Space。

需要添加：

- NSPrivacyAccessedAPICategoryDiskSpace
- 理由 E174.1

E174.1 允许为了判断能否写文件、低空间时删除缓存或避免下载而读取磁盘信息。App 必须根据结果产生用户可见的行为，且不能把磁盘容量或派生值传出设备。

若未来在 UI 中显示精确剩余空间，还需核对是否同时使用 85F4.1；本计划不要求显示设备总剩余空间，只显示本 App 音频占用和“空间不足”。

来源：

- [Required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [NSPrivacyAccessedAPIType reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

### 7.3 统一缓存元数据

为每个资产持久化：

- trackID；
- source 类型：HLS / BA / ODR；
- content version、ETag；
- byteCount；
- downloadedAt、lastPlayedAt；
- pinned；
- local availability；
- expiration；
- 当前系统返回的本地 URL 只在其允许的生命周期内使用。

仅 11 条音频，不需要数据库；一个由 actor 串行管理、原子写入 Application Support 的 Codable index 即可。

### 7.4 默认策略

智能缓存：

- opportunistic capacity 低于 1 GiB：不新建自动缓存；
- 最多最近 2 轨或 64 MiB，先达到者为准；
- 30 天未播放即到期；
- low eviction priority；
- 只在 Wi‑Fi、非 Low Data Mode 下自动开始。

显式离线：

- important capacity 检查；
- pinned，高优先级；
- 不按 TTL 静默删除；
- 允许用户逐条/全部删除。

清理顺序：

1. 已过期且未 pinned。
2. LRU 未 pinned。
3. 超出 byte/track 上限的未 pinned。
4. 仍不足则停止下载并提示用户，不擅自删 pinned。

永不删除：

- 正在播放；
- 正在下载；
- 即将无缝播放的下一轨；
- 用户 pinned 的离线音频。

清理触发：

- App 启动后异步；
- 下载前；
- 播放结束或切轨；
- 进入音频存储设置页；
- 收到相关文件缺失或低空间错误后。

### 7.5 两种下载技术的差异

HLS：

- AVAssetDownloadStorageManager 设置 expirationDate 和 eviction priority；
- App 同时维护自己的 2-track / 64 MiB / LRU 规则；
- 保存系统提供的下载位置，不移动资产；
- 始终容忍系统已清理本地文件。

Managed BA：

- Apple 明确说 App 仍安装时不会自动移除 packs；
- 必须调用 remove(assetPackWithID:)；
- downloadSize 是压缩传输大小，安装后可能更大；
- 下载前按 catalog 中的安装体积，并为下载、解包、版本更新和安全余量留空间；
- 播放中禁止 remove/checkForUpdates，避免打开的 URL 与更新并发。

## 8. 音频生产流水线

### 8.1 母带优先

实施前先向屏东能净协会确认并寻找：

- WAV、AIFF、FLAC 或更高码率原始文件；
- 楞严咒 lyz1 的母带；
- 明确的 App、公开 CDN、GitHub Release 再分发授权；
- 署名文字和是否允许格式转换、下混、响度处理。

如果只能用现有 MP3：

- 记录每个可恢复解码错误的位置；
- 人工听检错误前后；
- 一次解码后直接生成所有交付物，绝不从现有 M4A 再转。

### 8.2 候选规格

必须盲测三档：

| 候选 | 目的 |
|---|---|
| mono AAC-LC 24 kbps | 体积下限，不默认采用 |
| mono AAC-LC 32 kbps | 推荐平衡点 |
| mono AAC-LC 40 kbps | 质量回退 |
| 当前 HE-AACv2 约 44 kbps | 基线 |

共同设置：

- 22.05 kHz，避免无意义升采样；
- 0.5L + 0.5R 下混；
- 保留 title、album、artist、track number；
- progressive M4A 的 moov atom 放文件头；
- 固定编码器版本和参数；
- 输出 SHA-256、字节数、时长、codec/profile；
- 全文件 decode、duration、seek、首尾和元数据验证。

AAC-LC 是 iOS 15+ 最保守的兼容选择。HE-AAC v1 mono 24/32 kbps 可作为额外实验，但不要因理论效率跳过设备盲听。

### 8.3 盲听门槛

- 至少 3–5 位听者；
- 随机隐藏 A/B 文件名；
- 每档至少覆盖 10 个短片段；
- iPhone 扬声器、普通耳机、蓝牙至少各一轮；
- 重点记录齿音、金属感、尾音、背景抽动、相位变化；
- 任一关键片段出现稳定可识别劣化就升级码率或保留现状。

32 kbps 通过后再全量替换；不能以“文件更小、能解码”代替音质验收。

### 8.4 一份编码，多种封装

从最终 AAC 资产生成：

- progressive M4A：R2 备用、GitHub Release、Managed BA pack；
- HLS VOD：同一 AAC bitstream remux 为 10 秒 CMAF/fMP4 segments，不再次有损编码；
- 每轨一个 master/media playlist，单码率即可；
- 只有真实网络测试证明需要时才增加第二个 bitrate rendition。

## 9. App 内部重构计划

### 9.1 数据模型

用 Codable AudioCatalog 替换当前仅有 file/name/extension 的松散字典。每轨至少包括：

- id、title、artist；
- durationMs；
- codec、sampleRate、channels、bitrate；
- byteCount、installedByteCount；
- contentVersion、sha256；
- hlsURL；
- progressiveURL；
- githubFallbackURL；
- managedPackID、managedRelativePath；
- legacyODRTag；
- minimumAppVersion。

App 内置一份 last-known-good catalog；远端 catalog 失败、格式不支持或校验失败时使用内置版本。

### 9.2 组件边界

新增或重构为：

- AudioAssetProvider：解析 local HLS、Managed BA、ODR、remote URL。
- AudioDownloadManager actor：HLS/URLSession/BA 下载状态、取消、恢复和进度。
- AudioCachePolicy：磁盘预检、TTL、LRU、pinned。
- AudioCatalogService：远端 catalog、版本、回退。
- AudioPlayerObserver：增加 waitingToPlay、buffering、stall、failed、loaded progress。
- AudioManager：只负责产品状态和播放队列，不直接持有所有底层下载对象。

### 9.3 状态机

状态至少包括：

- notAvailable；
- streaming；
- buffering；
- downloading；
- downloaded；
- expired / evicted；
- failed；
- paused / cancelled。

每次用户选轨生成 selection token。旧下载或旧播放请求完成时，若 token 已过期，只更新缓存状态，不抢占当前播放。

### 9.4 网络策略

- 用户点播放：允许蜂窝，但在首次大流量使用时说明。
- 智能缓存：默认 Wi‑Fi only，respect Low Data Mode。
- 显式离线：用户可选择允许蜂窝。
- 使用 allowsConstrainedNetworkAccess、allowsExpensiveNetworkAccess、waitsForConnectivity。
- force quit、后台回调和重新启动后恢复 AVAssetDownloadURLSession。
- 处理音频中断、耳机拔出、路由变化、锁屏、远程控制和切网。

## 10. 分阶段迁移

### 阶段 0：立即止损，1–2 天

- Release 禁止 EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE。
- 移除 ly01 initial-install。
- 关闭无提示的下一轨预取，或仅在明确设置 + Wi‑Fi + 空间允许时执行。
- 切轨/播放结束时正确 endAccessingResources。
- 加 selection token、取消和真实状态恢复。
- Archive/IPA 体积验收。

退出条件：Release 主 App 不包含 11 条完整音频；播放后的旧 ODR request 可释放。

### 阶段 1：音频与 catalog 试生产，2–4 天

- 获取授权和更好母带。
- 生成 24/32/40 kbps mono 候选。
- 完成盲听并冻结规格。
- 生成 progressive M4A、HLS、哈希和 AudioCatalog。
- 当前音频保留为 rollback 版本。

退出条件：全部文件 decode/seek/metadata 通过，盲听签字，catalog 可复现生成。

### 阶段 2：R2 与备用源，1–2 天

- 建 R2 Standard bucket、自定义域名和 Cache Rule。
- 上传不可变版本资源。
- 验证 MIME、Range、Cache-Control、ETag、缓存命中。
- 同名 progressive 文件上传固定 GitHub Release。
- 配置告警。

退出条件：自动脚本能从主、备 URL 下载并校验每轨。

### 阶段 3：在线点播 MVP，4–6 天

- AudioCatalog / Provider 抽象。
- AVPlayer 远端 HLS 播放。
- buffering/stall UI、seek、错误和 fallback。
- feature flag 灰度。
- ODR 仍保留为回退。

退出条件：iOS 15、当前主流系统、iOS 26/27 均能首播、切轨、锁屏、恢复。

### 阶段 4：边播边下与存储管理，4–7 天

- AVAssetDownloadURLSession。
- 智能缓存和离线下载 UI。
- AVAssetDownloadStorageManager policy。
- Disk Space / E174.1 隐私清单。
- LRU、TTL、pinned、删除全部。
- 重启、后台、force quit、低空间恢复。

退出条件：相同 rendition 边播边下无重复 segment 路径；系统清缓存后 App 不显示虚假离线。

### 阶段 5：Apple-hosted BA POC，3–5 天 + 审核等待

- 主 App min iOS 15 + extension min iOS 26 的最小 POC。
- 一个小 onDemand pack，经 ba-serve、internal TestFlight、external TestFlight。
- iOS 15/25 安装验证，iOS 26/27 下载验证。
- 中国移动/联通/电信与海外实测。
- POC 通过后做 11 个一轨一 pack，分 10 + 1 预审。

退出条件：混合 deployment validation 通过；Apple 托管性能达到回退路径要求。

### 阶段 6：灰度与 ODR 退场，至少 2 个 App 版本

- 5% → 25% → 100% 在线路径。
- 观察首声、失败、rebuffer、fallback、下载完成率。
- 两个稳定版本后移除 ODR 主路径。
- 保留上一版 catalog 和 CDN 文件至少 90 天。
- 最终删除 ODR tags、KnownAssetTags、NSBundleResourceRequest 代码和资源引用。

注意：监控不得上传磁盘容量或其派生值；E174.1 禁止这样做。

## 11. 测试矩阵与上线门槛

### 11.1 网络

地区/网络：

- 中国移动、联通、电信：Wi‑Fi + 蜂窝；
- 欧洲、北美；
- 高延迟、丢包、断网、切 Wi‑Fi/蜂窝；
- Low Data Mode、低电量、后台、force quit。

指标建议：

- 海外 Wi‑Fi 首声 P50 ≤ 1.5 s、P95 ≤ 4 s；
- 大陆首声 P50 ≤ 2.5 s、P95 ≤ 6 s；
- 播放启动失败率 < 1%；
- rebuffer time ratio < 1%；
- 随机 seek P95 ≤ 3 s；
- 主源故障时备用源切换可用。

若大陆不达标：

- 不在大陆用户上默认承诺在线体验；
- 优先展示 Apple 托管“下载后播放”；
- 再评估付费境内 CDN + ICP。

### 11.2 存储

- 可用空间恰好低于/高于阈值；
- 下载中其他 App 抢占空间；
- 自动缓存过期；
- pinned 不被 App 自动删除；
- 当前/下一轨不被清理；
- 系统清除 HLS download 后状态自愈；
- BA remove 后可重新 ensure；
- App 删除后所有缓存消失；
- Application Support / Caches 资源不进入 iCloud backup。

### 11.3 播放

- 首播、暂停、恢复、seek；
- 上次进度；
- repeat one/all；
- 下一轨预取；
- 快速连点 A/B/C，不被旧完成回调抢占；
- 锁屏、耳机、蓝牙、来电、Siri；
- catalog 更新时旧本地资产仍可播；
- 播放中不删除或更新当前 BA pack。

### 11.4 分发

- Release IPA 不嵌音频；
- TestFlight 的 HLS、GitHub fallback 和 BA 分别验证；
- 旧 App build + 新 pack 兼容；
- App Review 无 pack、pack 尚未批准、CDN 不可用时有可理解的错误；
- 录音授权、署名、隐私政策和第三方服务披露齐全。

## 12. 还容易遗漏的问题

1. 版权与公开分发
   - 现有 App 内使用授权不一定等于允许放在公开 R2/GitHub URL。
   - GitHub public repo/release 会让资产更容易复制。

2. 源文件质量
   - 所谓原文件仍是有损 MP3，且存在可恢复帧错误。
   - lyz1 没有对应母带。

3. 费用不是硬封顶
   - R2 免费额度超出后按量计费，budget alert 不会自动断流。

4. 热链与滥用
   - 公开音频 URL 可能被第三方引用。低 DAU 下先监控，不必首版引入易失效签名 URL。

5. 更新兼容
   - 不覆盖 immutable key。
   - 旧 App 用到的 path/codec 至少保留 90 天。
   - BA 破坏性更新必须新 Pack ID。

6. 数据与隐私
   - Cloudflare/GitHub 会处理请求 IP 等网络日志；隐私政策需说明外部内容托管。
   - 不上传磁盘容量。
   - 网络性能遥测应最小化、聚合化，并遵守现有隐私承诺。

7. 无障碍和数据费用
   - 下载/缓冲/离线状态需 VoiceOver 可读。
   - 蜂窝大文件下载必须用户可控。

8. App Store 内容审核
   - Apple-hosted packs 需要审核，不能当即时发布 CDN。
   - 同批 10-pack 限制要排进发布流程。

9. 备份与恢复
   - 可重新下载的音频不得进入 iCloud backup。
   - 用户换机后恢复“已下载列表”不等于文件已经存在，应重新确认本地 availability。

10. 可观测性与回滚
    - 必须能按 catalog/feature flag 回退到上一版 URL。
    - 不能依赖唯一远端 manifest 才能启动播放页。

11. 仓库体积与母带保存
    - 10 个源 MP3 和 11 个交付 M4A 当前都是普通 Git blob，不是 Git LFS，总计约 368 MiB。
    - source-media 没有进入 Xcode target，但会持续拖慢 clone、备份和历史体积。
    - 先确认至少两份可恢复的母带备份，再把母带放到私有对象存储或归档盘；代码仓库只保留 catalog、哈希、生成脚本和必要的小样。
    - 不要在没有验证备份的情况下从 Git 历史删除媒体；若以后清理历史，应作为单独、可回滚的仓库维护任务。

## 13. 工作量和推荐排序

单人开发粗估：

| 工作 | 工程时间 |
|---|---:|
| P0 ODR/Archive 止损 | 1–2 天 |
| 音频试制与盲听 | 2–4 天 |
| R2/GitHub 与发布脚本 | 1–2 天 |
| HLS 在线播放 | 4–6 天 |
| 离线/缓存/空间策略 | 4–7 天 |
| Background Assets POC | 3–5 天，不含审核等待 |
| 真机、国内网络、灰度修复 | 5–10 天 |

推荐优先级：

1. 先修 Release 嵌包和 ODR 不释放。
2. 同时确认录音授权和母带。
3. R2 + progressive/HLS 点播上线，覆盖 iOS 15+。
4. 再做 HLS 离线与智能缓存。
5. Apple-hosted BA 作为 iOS 26+ 备用来源做 POC。
6. 两个稳定版本后移除 ODR 主路径。

## 14. 最终验收清单

- [ ] Release IPA 不含全部音频。
- [ ] 默认播放不永久占用整轨磁盘。
- [ ] 首声和 rebuffer 达到地区门槛。
- [ ] 用户能下载、取消、查看、删除离线音频。
- [ ] 智能缓存有 TTL、LRU、byte/track cap。
- [ ] pinned、当前轨、下一轨不被 App 自动删。
- [ ] Disk Space / E174.1 已声明且磁盘值不出设备。
- [ ] R2 Range、MIME、Cache Rule、immutable URL、告警已验证。
- [ ] GitHub 仅为备用，客户端处理 302。
- [ ] 中国三大运营商与海外完成真机 TestFlight。
- [ ] mono 32 kbps 完成盲听；未通过则不替换。
- [ ] 所有编码完整 decode/seek/metadata/hash 通过。
- [ ] 录音公开 CDN/格式转换授权有书面记录。
- [ ] BA mixed-deployment POC 和 10-pack 发布流程通过。
- [ ] 旧 catalog 和旧文件保留回滚窗口。
- [ ] 两个稳定版本后才移除 ODR。

## 15. 主要官方资料

Apple：

- [ODR size limits and deprecation](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits/)
- [Background Assets](https://developer.apple.com/documentation/backgroundassets)
- [Creating managed asset packs](https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs)
- [Downloading Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)
- [Apple-hosted asset pack limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits)
- [WWDC25 Apple-Hosted Background Assets](https://developer.apple.com/videos/play/wwdc2025/325/)
- [AVAssetDownloadTask](https://developer.apple.com/documentation/avfoundation/avassetdownloadtask)
- [Offline playback and storage](https://developer.apple.com/documentation/avfoundation/offline-playback-and-storage)
- [Checking volume storage capacity](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity)
- [Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

Cloudflare：

- [R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [R2 public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- [R2 cache integration](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/)
- [Cloudflare China Network](https://developers.cloudflare.com/china-network/)

GitHub：

- [About Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [Release assets API](https://docs.github.com/en/rest/releases/assets)
- [Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)
