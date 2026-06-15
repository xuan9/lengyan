//
//  L10n.swift
//  lengyan
//
//  本地化字符串 helper：根据当前简繁选择直接加载对应 lproj Bundle
//
//  为什么需要：iOS 8+ 起 `-AppleLanguages` launch argument 不会自动刷新
//  Bundle.main.preferredLocalizations 的内部缓存，导致 fastlane snapshot /
//  UITest 在 zh-Hant 模式下 NSLocalizedString 仍返回简体。本 helper 通过
//  Book.shared.isSimplifiedChinese（已正确响应 launch argument）直接选择 lproj
//  Bundle，绕过 NSBundle 缓存。
//

import Foundation

enum L10n {
    /// 当前激活的 lproj Bundle（zh-Hans / zh-Hant）
    static var bundle: Bundle {
        // 直接读 -AppleLanguages launch argument（fastlane snapshot / UITest 用）
        // 与 Book.shared.isSimplifiedChinese 同源，但避免任何潜在耦合问题
        let lprojName = currentLprojName()
        if let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    /// 取本地化字符串（替代 NSLocalizedString，保证 launch argument 切换语言时立即生效）
    static func str(_ key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func currentLprojName() -> String {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-AppleLanguages"), i + 1 < args.count {
            let raw = args[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: "()\"' "))
            if raw.hasPrefix("zh-Hant") || raw.hasPrefix("zh-TW") || raw.hasPrefix("zh-HK") {
                return "zh-Hant"
            }
            if raw.hasPrefix("zh-Hans") || raw.hasPrefix("zh-CN") {
                return "zh-Hans"
            }
        }
        return Book.shared.isSimplifiedChinese ? "zh-Hans" : "zh-Hant"
    }
}
