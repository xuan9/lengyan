# 《楞严》App Store 元数据

本文件不再复制商店文案，避免与实际上架内容产生第二套、过期的信息源。

## 唯一文案来源

- 简体中文：[`fastlane/metadata/zh-Hans`](fastlane/metadata/zh-Hans)
- 繁体中文：[`fastlane/metadata/zh-Hant`](fastlane/metadata/zh-Hant)

名称、副标题、关键词、宣传文本、详细描述和版本说明均应直接修改上述目录，并通过 Fastlane 上传。不要从历史提交中恢复“完全本地运行”“零数据收集”、逐句同步、睡眠定时、圆形/竖排锁屏组件或未经验证的无障碍测试声明。

## 隐私发布检查

- App Store Connect 的简体中文 Privacy Policy URL 指向：
  `https://xuan9.github.io/lengyan/privacy.html`
- App Store Connect 的繁体中文 Privacy Policy URL 指向：
  `https://xuan9.github.io/lengyan/privacy-hant.html`
- 两种语言的 Support URL 均指向：
  `https://xuan9.github.io/lengyan/`
- App 内“设置 → 关于”最底部的“隐私政策”使用原生页面显示当前简繁体文案，不跳转浏览器；上述公开网址仍供 App Store 与外部访问使用。
- 反馈只发送正文与 `CFBundleShortVersionString` 所示的公开 App 版本号，不发送设备型号、系统名称与版本、构建号或设备标识。
- App Store 隐私问卷只申报 `User Content` / `Customer Support`，用途为 `App Functionality`，并选择“不关联用户”和“不用于追踪”。公开 App 版本号只是反馈处理所需的上下文，不应另行申报为 `Other Diagnostic Data`。
- 不申报 `Device ID`、诊断数据或 `Tracking`；代码不得上传 IDFV、精确硬件型号、系统版本或构建号。
- 反馈最多保留 30 天，之后自动删除；提前删除请求可通过支持页或 App 内“反馈”提交。
- 主 App 与 Widget 各自包含 `PrivacyInfo.xcprivacy`；发布前复核其中的 collected-data 声明及 `UserDefaults` Required Reason API 理由仍与代码一致。
- 每次发布前核对 [`PRIVACY.md`](PRIVACY.md)、iOS payload、Worker schema、保留任务和商店问卷一致。

## 发布前人工验证

Fastlane 文案只是仓库内来源，不能替代 App Store Connect 的外部配置。提交新版本前还必须确认：

1. 隐私问卷已经保存并显示在商店预览中；
2. 确认反馈服务与自动清理已经部署，再发布支持站新版，确认简繁隐私页已替换旧的“完全不传输、100% 安全”承诺；
3. 上述三个公开页面均可匿名访问，网页反馈也只提交正文；
4. 反馈服务的限速和自动清理已经部署，并确认包括可恢复副本在内的实际保留时间不超过 30 天；
5. 当前商店截图和版本说明没有展示尚未上线或未经验证的能力。
