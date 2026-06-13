//
//  HapticManager.swift
//  lengyan
//
//  极度克制的触觉反馈体系
//  隐喻：木鱼轻叩，非弹幕点赞
//  原则：只在确认类操作触发，导航类静默
//

import UIKit

/// 触觉反馈管理器 — 禅意极简
/// 遵循「叩木鱼」原则：只在有意义的确认动作产生反馈
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    // MARK: - 预创建反馈生成器，避免延迟

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let successNotification = UINotificationFeedbackGenerator()

    /// 收藏/取消收藏 — 如轻叩木鱼
    func bookmarkToggle() {
        lightImpact.impactOccurred()
    }

    /// 通用轻触觉 — 标签 / 卡片轻点
    func lightTap() {
        lightImpact.impactOccurred()
    }

    /// 完成一卷 — 功德圆满的渐进确认
    func chapterComplete() {
        successNotification.notificationOccurred(.success)
    }

    /// 预热反馈引擎（在预期触发前调用以减少延迟）
    func prepare() {
        lightImpact.prepare()
        successNotification.prepare()
    }
}
