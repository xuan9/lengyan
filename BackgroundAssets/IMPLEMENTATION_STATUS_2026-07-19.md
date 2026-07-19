# 音频资源双栈实施状态（2026-07-19）

结论：**生产代码、11 个按卷 Apple 资源包与零超额 Cloudflare 应急下载通道均已完成。** App 在 iOS 15–25 继续使用旧 ODR，在 iOS 26+ 使用 Managed Background Assets；只有用户主动播放时 Apple 通道明确失败或连续 15 秒没有下载进展，才切换到 Cloudflare。公网地址已完成 11/11 全量回读验证并在生产 plist 中启用。用户明确要求跳过 TestFlight，因此 Apple-hosted 的真实线上链路不属于本轮验证范围。

## 已完成

- 统一 `AudioAssetProvider` / `AudioAssetCoordinator`，播放器不直接依赖 ODR、Managed API 或 CDN。
- iOS 15–25 保留 `NSBundleResourceRequest`；iOS 26+ 使用 `AssetPackManager`，26.0–26.3 与 26.4+ API 分支均可编译。
- 当前卷开始播放后静默准备下一卷；用户切到该卷时提升并复用原请求，不重复下载。
- 当前播放 A 时选择 B，A 不会中断；界面立即显示 B 正在准备及进度，只有 B 完整可读后才原子切换。
- iOS 26 首次启用 Managed 时将旧 ODR tags 的保留优先级降为零；`ly01` 仍保留兼容 tag，但不再是 initial-install。
- Cloudflare 备用线路只用于明确播放请求；后台预取失败不会触发公网下载。
- Apple 明确失败会立即切换；无进展 15 秒会先取消 Apple 请求，再切换 Cloudflare，并立即显示“正在使用备用线路准备…”。
- CDN 使用内容寻址路径 `audio/v1/<sha256>/<id>.m4a`；下载完成后必须同时通过精确字节数和 SHA-256 才进入 Application Support 缓存，且排除 iCloud 备份。
- 设置页分别显示 Apple/ODR 与备用缓存占用；删除音频会清理两侧缓存，正在播放的 lease 受保护。
- Cloudflare 使用纯 Workers Static Assets：没有 Worker 脚本、R2 bucket/binding 或 `run_worker_first`。这是为了满足“不接受任何可能的超额费用”；配置测试会阻止这些计费路径被误加回来。
- 生产地址：`https://lengyan-audio-fallback.dhyana9.workers.dev`；部署版本：`efde653d-4a39-439b-8a96-2979d4e4b480`。

## 验证结果

| 验证项 | 结果 |
|---|---|
| Cloudflare 部署 | 12 个资源成功发布：11 个 M4A + 1 个健康契约；无 bindings |
| 公网全量回读 | 11/11 通过 HTTPS、精确大小、SHA-256、`afinfo`、MIME、immutable cache、ETag、HEAD 与 Range 安全行为 |
| Cloudflare 本地测试 | 3/3 通过；含 25 MiB 上限、11 条内容寻址清单、assets-only/no-R2 配置断言 |
| iOS 18.6 完整单元测试 | 84 passed / 0 failed / 0 skipped |
| iOS 26.5 完整单元测试 | 83 passed / 0 failed / 1 条既有条件跳过 |
| 故障转移场景 | 明确失败、15 秒 watchdog、进度重置、预取提升、取消不切 CDN、空间不足不切 CDN、坏文件拒绝、缓存命中与选择竞态均覆盖 |
| Thread Sanitizer | 故障转移聚焦场景通过，未报告数据竞争 |
| Static Analyze | 通过；仅有项目既有、与音频备用线路无关的 warning |
| Unsigned Release Archive | `/tmp/lengyan-static-fallback-release-20260719.xcarchive` 成功 |
| Archive 双栈校验 | minOS、弱链接、11 个 ODR tags、无 initial-install/prefetch tags、App 内 0 个 M4A、11 个源 hash、生产 Cloudflare=true 全部通过 |

Static Assets 实测会忽略 `Range` 并返回完整文件 200，因此备用下载被中断时会重下当前卷；最大一卷约 20.1 MiB，不影响完整性校验或播放切换语义。

## 仍需真实发行环境验证

- App Store Connect 中 11 个 `.aar` 的上传、处理与 build 关联。
- Apple-hosted pack 的真实下载、取消、失败重试、断点恢复、删除与版本更新。
- 中国大陆移动、联通、电信真机下 Apple 与普通 Cloudflare 的网络表现；普通 Cloudflare 不等于中国大陆专网。
- 签名 Archive、App Store Validate、TestFlight 与生产真机表现。
- iOS 15、iOS 26.0–26.3 以及未来系统的实机运行；代码路由和可用性边界已覆盖，但模拟器不能替代设备。

部署、复验和 Archive 校验命令见 `BackgroundAssets/README.md` 与 `BackgroundAssets/CLOUDFLARE_FALLBACK.md`。
