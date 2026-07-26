# 音频资源双栈实施状态（2026-07-19）

结论：**生产代码、11 个按卷 Apple 资源包与零超额 Cloudflare 应急下载通道均已完成。** App 在 iOS 15–25 继续使用旧 ODR，在 iOS 26+ 使用 Managed Background Assets；只有用户主动播放时 Apple 通道明确失败或连续 15 秒没有下载进展，才切换到 Cloudflare。公网地址已完成 11/11 全量回读验证并在生产 plist 中启用。用户明确要求跳过 TestFlight，因此 Apple-hosted 的真实线上链路不属于本轮验证范围。

> **2026-07-26 状态补充：** 11 条楞严音频已拆为 product-neutral artifact、iOS/Android delivery 和 repository tooling input；`AudioAssets/audio-manifest.json` 改为第 18 个兼容生成产物，原 Swift/Node/checksum/media/Apple 输出逐字节不变。Cloudflare fallback cache 已从“最多 2 卷/48 MiB”调整为 Caches 内无数量/字节上限、28 天未访问后清理；11 条合计 161,420,718 bytes（约 154 MiB）。`a687fb8` 已补目录展开跨重启、冷启动同卷 resume、seek 初始零值保护和 28 天 expiry/protected asset 专门回归；Xcode 26.6/iOS 26.5 Simulator 现通过 104 个 unit tests（1 个 Legacy ODR integration skip）零失败。此前 3 个关键 iPad UI tests 也通过，统一命令会在可信 CI 中持续执行。下方 2026-07-19 验证表保留为当日发行快照；Apple-hosted 真实发行缺口没有因此关闭。

## 已完成

- 统一 `AudioAssetProvider` / `AudioAssetCoordinator`，播放器不直接依赖 ODR、Managed API 或 CDN。
- iOS 15–25 保留 `NSBundleResourceRequest`；iOS 26+ 使用 `AssetPackManager`，26.0–26.3 与 26.4+ API 分支均可编译。
- 当前卷开始播放后静默准备下一卷；用户切到该卷时提升并复用原请求，不重复下载。
- 当前播放 A 时选择 B，A 不会中断；界面立即显示 B 正在准备及进度，只有 B 完整可读后才原子切换。
- iOS 26 首次启用 Managed 时将旧 ODR tags 的保留优先级降为零；`ly01` 仍保留兼容 tag，但不再是 initial-install。
- Cloudflare 备用线路只用于明确播放请求；后台预取失败不会触发公网下载。
- Apple 的可回退交付错误会立即切换；用户取消和本机空间不足不会切换。无进展 15 秒会先取消 Apple 请求，再切换 Cloudflare，并立即显示“正在使用备用线路准备…”。
- 音频 artifact、iOS delivery 与 tooling input 是分层输入；旧 manifest、Swift、Node、checksum、简繁媒体索引、静态健康信息和 11 个 Apple manifests 均由 `generate-audio-manifest.mjs` 写入/检查。
- CDN 使用内容寻址路径 `audio/v1/<sha256>/<id>.m4a`；响应声明或实际接收字节超过目录值时立即取消，下载完成后必须同时通过精确字节数和 SHA-256 才进入系统 Caches。备用音频迁移旧 Application Support 缓存，并在后台/终止维护时清理超过 28 天未访问且未受保护的文件；当前没有数量或字节上限。
- 不向用户暴露技术性的音频存储页。iOS 26+ 只在系统发出低空间信号或下载实际返回空间不足时取消预取并清理未使用资源包，保护正在播放、用户正在等待及最近播放的卷；iOS 15–25 继续由 ODR 管理。代码不主动读取设备剩余容量。
- Cloudflare 使用纯 Workers Static Assets：没有 Worker 脚本、R2 bucket/binding 或 `run_worker_first`。这是为了满足“不接受任何可能的超额费用”；配置测试会阻止这些计费路径被误加回来。
- 生产地址：`https://lengyan-audio-fallback.dhyana9.workers.dev`；部署版本：`efde653d-4a39-439b-8a96-2979d4e4b480`。

## 2026-07-19 验证结果（历史快照）

| 验证项 | 结果 |
|---|---|
| Cloudflare 部署 | 12 个资源成功发布：11 个 M4A + 1 个健康契约；无 bindings |
| 公网全量回读 | 11/11 通过 HTTPS、精确大小、SHA-256、`afinfo`、MIME、immutable cache、ETag、HEAD 与 Range 安全行为 |
| Cloudflare 本地测试 | 3/3 通过；含 25 MiB 上限、11 条内容寻址清单、assets-only/no-R2 配置断言 |
| iOS 18.6 完整单元测试 | 89 passed / 0 failed / 0 skipped |
| iOS 26.5 完整单元测试 | 88 passed / 0 failed / 1 条预期的旧 ODR 条件跳过 |
| iOS 18.6 备用线路 UI E2E | 2/2 通过：Apple 立即报错、Apple 无进展 watchdog；每项均实测卷一/卷二 Cloudflare 下载、校验、A→B 无缝切换 |
| iOS 26.5 备用线路 UI E2E | 2/2 通过：与 iOS 18.6 相同的两条端到端路径 |
| 故障转移场景 | 明确失败、15 秒 watchdog、进度重置、预取提升、取消不切 CDN、普通/ODR 专用空间不足不切 CDN、超大响应中止、坏文件拒绝、缓存命中与选择竞态均覆盖 |
| Thread Sanitizer | 音频资源与故障转移聚焦测试 23/23 通过，未报告数据竞争 |
| Static Analyze | 通过；仅有项目既有、与音频备用线路无关的 warning |
| Unsigned Release Archive | `/tmp/lengyan-reviewed-release-20260719-2318.xcarchive` 成功 |
| Archive 双栈校验 | minOS、弱链接、11 个 ODR tags、无 initial-install/prefetch tags、App 内 0 个 M4A、11 个源 hash、生产 Cloudflare=true 全部通过 |

Static Assets 实测会忽略 `Range` 并返回完整文件 200，因此备用下载被中断时会重下当前卷；最大一卷约 20.1 MiB，不影响完整性校验或播放切换语义。

## 模拟器故障注入

Debug App target 使用专用编译条件 `AUDIO_FALLBACK_UI_TESTS`。只有同时带 `--uitesting` 时，才接受以下启动参数：

- `--audio-primary-fault immediate`：Apple primary 立即返回不可连接错误。
- `--audio-primary-fault stall`：Apple primary 保持无进展，由 watchdog 触发备用线路。
- `--audio-primary-fault out-of-space`：模拟本机空间不足；按生产策略不得切 Cloudflare。
- `--audio-fallback-stall-timeout 2`：仅测试时将 watchdog 缩短到 2 秒。
- `--reset-audio-fallback-cache`：启动时仅清理 Caches 下的 `AudioFallback` 测试缓存。

UI 测试为稳定观察瞬时提示另设 1.5 秒 presentation delay；真实 Cloudflare 请求、完整 M4A 下载、大小/SHA-256 校验和播放器切换没有替换为 mock。Release 构建成功，且产物扫描确认不包含上述故障参数、测试 provider 或缓存重置入口。

## 仍需真实发行环境验证

- App Store Connect 中 11 个 `.aar` 的上传、处理与 build 关联。
- Apple-hosted pack 的真实下载、取消、失败重试、断点恢复、删除与版本更新。
- 中国大陆移动、联通、电信真机下 Apple 与普通 Cloudflare 的网络表现；普通 Cloudflare 不等于中国大陆专网。
- 签名 Archive、App Store Validate、TestFlight 与生产真机表现。
- iOS 15、iOS 26.0–26.3 以及未来系统的实机运行；代码路由和可用性边界已覆盖，但模拟器不能替代设备。

部署、复验和 Archive 校验命令见 `BackgroundAssets/README.md` 与 `BackgroundAssets/CLOUDFLARE_FALLBACK.md`。
