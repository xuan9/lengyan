# 音频资源双栈实施状态（2026-07-19）

结论：**生产代码与 11 个按卷资源包已完成。** App 在 iOS 15–25 使用旧 ODR，在 iOS 26+ 使用 Managed Background Assets。用户已明确要求跳过 TestFlight 前置验收，因此 Apple-hosted 的实际上传、下载、断点恢复与真机链路不属于本轮已验证范围。

## 已完成

- 统一 `AudioAssetProvider` / `AudioAssetCoordinator`，播放器不直接依赖 ODR 或 Managed API。
- iOS 15–25 保留 `NSBundleResourceRequest`，当前卷与下一卷各持有独立 lease。
- iOS 26+ 使用 `AssetPackManager`；26.0–26.3 与 26.4+ API 分支均可编译。
- 仅在当前音频真正开始播放后，静默请求下一卷；用户随后切到该卷时提升并复用同一请求。
- 新选择下载失败或较旧请求迟到时，不停止或抢占当前播放。
- 完成、停止、切换模式、内存警告、低磁盘与终止路径会取消预取并释放资源。
- iOS 26 首次启用 Managed 时会把全部旧 ODR tags 的保留优先级降为零，并用一次性标记避免重复迁移；实际回收时间仍由系统决定。
- `ly01` 保留旧 ODR tag，但已移除 initial-install 属性；iOS 26 不再因兼容旧路径而随 App 安装卷一，iOS 15–25 新安装用户首次播放卷一时按需下载。
- 用户主动选择另一卷时，当前卷继续播放，但播放器栏、沉浸界面和目标卷行会立即显示“正在准备 + 进度”；自动预取保持静默。
- 生产目录固定为 `ly01`–`ly10`、`lyz1` 共 11 卷；每卷一个 `onDemand` pack，文件路径为 `Audio/<id>.m4a`。
- 设置页可查看 Managed 本地包概况并删除已下载音频；正在播放的卷受保护。
- 下载扩展只接受 M0 与上述 11 个生产 pack ID；M0 用户界面诊断入口已关闭。

## 本机验证

| 验证项 | 结果 |
|---|---|
| iOS 18.6 聚焦测试 | 8 passed / 0 failed；含 ODR `ly01 → ly02` 当前播放与下一卷预取集成测试、预取提升竞态及迁移判断 |
| iOS 26.5 路由测试 | 2 passed / 0 failed；运行时工厂选择 Managed provider，一次性旧 ODR 降级判断通过 |
| iOS 26.5 App | Debug build、安装、启动成功 |
| Generic iOS | Debug build 与 build-for-testing 成功 |
| 生产 pack 打包 | 11/11 `.aar` 成功；源文件 SHA-256 与 `afinfo` 校验通过 |
| Unsigned Release Archive | `/tmp/lengyan-no-odr-preinstall-20260719.xcarchive` 成功（含 pending UX、旧 ODR 降级修复与取消 `ly01` 初始安装） |
| Archive 双栈校验 | `scripts/verify-dual-stack-archive.sh` 通过；主 App minOS 15、extension minOS 26、BackgroundAssets 弱链接、11 个精确 ODR tags、所有旧 ODR pack 均无初始安装/预取优先级、App 内 0 个 M4A |

## 明确未验证

- App Store Connect 中 11 个 `.aar` 的上传、处理与 build 关联。
- Apple-hosted pack 的真实下载、取消、失败重试、断点恢复、删除与版本更新。
- 签名 Archive、App Store Validate、TestFlight 与生产真机网络表现。
- iOS 15、iOS 26.0–26.3 和未来系统的实机运行；代码路由和可用性边界已经覆盖，但不能替代设备验证。

打包与 Archive 校验命令见 `BackgroundAssets/README.md`。
