# M0 验收状态（2026-07-19）

结论：**M0 的 App Store Validate / TestFlight hosted 部分仍未通过。** 用户于 2026-07-19 明确豁免该前置闸门，授权直接实施 11 个生产音频包的双栈改造。本文仍保留未验收项，不将产品实施等同于 Apple-hosted 真实发布链路已验证。

## 已通过

| 项目 | 证据 | 结果 |
|---|---|---|
| 小 pack | `scripts/package-m0-asset-pack.sh` | `ba-package` 成功；`.aar` 约 8 KB |
| pack 内容 | marker + `managed-assets-smoke.m4a` | M4A 1.500 秒、7,279 bytes；源码 SHA-256 `795e029f28dba620c41cdb36da01128f9bb2ca5a9e58eab7174d293b3f91baaa` |
| Managed API | `ManagedAssetPackM0POCView.swift` | 26.0–26.3 与 26.4+ API 分支均通过 Xcode 26.5 编译；有进度、取消、重试、验证、播放、停止、删除和事件日志 |
| ExtensionKit 下载扩展 | `LengyanAssetDownloaderExtension` | iOS 26.0；只允许 M0 pack；正确嵌入 `lengyan.app/Extensions/` |
| Release build | unsigned generic iOS build | 成功；主 App `minOS 15.0`，extension `minOS 26.0` |
| 无签名 Archive | `/tmp/lengyan-m0-audio-20260719.xcarchive` | Archive 成功 |
| Archive 结构 | `scripts/verify-m0-archive.sh` | `BackgroundAssets` 弱链接；3 个 BA 配置键正确；11 个精确 ODR tags/asset packs；App 内 0 个 M4A |
| 旧系统安装/启动 | iPhone 16 Pro Simulator，iOS 18.6 | 安装、冷启动成功；进程 PID 65792 持续存活 |
| 旧 ODR 当前卷 + 下一卷 | `LegacyODRM0IntegrationTests`，iOS 18.6 | 当前树强化复验 1 test / 0 failures；显式断言 `ly01 → ly02`，前者进入播放器，后者预取完成，两个音频文件均可读 |
| 当前播放版 iOS 26 烟测 | iPhone 17 Simulator，iOS 26.5 | Debug build、安装、启动成功；启动 PID 85745；不代表 hosted pack 验收 |

## 尚未通过

| 闸门 | 当前状态 | 所需权威证据 |
|---|---|---|
| 签名 Archive | 阻塞 | 主 App、Widget、downloader extension 的 Distribution profiles 和有效签名身份 |
| App Store Validate | 阻塞 | Xcode Organizer / App Store Connect 返回通过 |
| M0 `.aar` Apple hosting | 阻塞 | pack 上传、处理并关联到目标 App 的 App Store Connect 记录 |
| iOS 15 下界 | 未测 | iOS 15 真机或可用 Runtime 的安装、启动、当前 ODR 播放与 next prefetch |
| `< iOS 26` 上界 | iOS 18.6 已测 | 当前可用最高旧路径 Runtime 的证据已取得；若测试计划指定其他旧系统，仍需补测 |
| iOS 26.0–26.3 | 未测 | TestFlight 下载、进度、取消、重试、验证、播放、删除 |
| iOS 26.4+ | 当前播放版已在 26.5 编译、安装、启动；hosted pack 未测 | TestFlight Apple-hosted pack 的完整操作日志；确认走 `requireLatestVersion: false` |
| iOS 27 | 未测 | 可用系统/设备上的同一 Managed 流程 |

## 已确认的外部阻塞

本机 `security find-identity -v -p codesigning` 返回 `0 valid identities found`。带 `-allowProvisioningUpdates` 的签名 Archive 返回 `No Accounts: Add a new account in Accounts settings`，因此无法在当前环境生成 profiles、Validate、上传 `.aar` 或发布 TestFlight build。

解除阻塞后按以下顺序继续：

1. 在 Xcode 登录具备团队 `A37UYHPM4V` 权限的 Apple Developer / App Store Connect 账号。
2. 为 `org.fuxuan.lengyan`、`org.fuxuan.lengyan.widget`、`org.fuxuan.lengyan.asset-downloader` 建立自动签名资料。
3. 生成签名 Archive，并运行 `scripts/verify-m0-archive.sh --require-signed <archive>`。
4. 上传 M0 `.aar`，完成 App Store Validate，再上传同一 M0 build 到 TestFlight。
5. 补齐上表的真机/TestFlight 证据；全部通过后才进入设计文档 M1/M2。
