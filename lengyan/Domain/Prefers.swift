//
//  Data.swift
//  lengyan
//
//  Created by Xuan on 16/6/26.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

protocol PrefersProtocol {
    var likes:[String]{get}
    var lastPlayFile:[String]?{get set}
    var lastPlayMode:Int?{get set}
    var fontSizeLevel: Int { get set }
    var isDailyReminderOn: Bool { get set }
    var reminderHour: Int { get set }
    var reminderMinute: Int { get set }

    func like(_ path:String)
    func unlike(_ path:String)

    func updateReadingProgress(_ progress: [Int: CGFloat])
    func updateTotalReadingTime(_ time: TimeInterval)

    func persist()
}

class Prefers: NSObject, PrefersProtocol {
    private let userDefaults: UserDefaults
    private var likesCache: [String]

    private static let likesKey = "likes"
    private static let playFileKey = "playFile"
    private static let playModeKey = "playMode"
    private static let fontSizeLevelKey = "fontSizeLevel"
    private static let dailyReminderOnKey = "dailyReminderOn"
    private static let reminderHourKey = "reminderHour"
    private static let reminderMinuteKey = "reminderMinute"
    private static let lastReadPathKey = "lastReadPath"
    private static let lastReadPageKey = "lastReadPage"
    private static let lastReadModeKey = "lastReadMode" // "paged" or "tree"
    private static let lastReadChapterKey = "lastReadChapter"
    private static let lastReadChapterOffsetKey = "lastReadChapterOffset"
    private static let userLikesKey = "userLikes"

    static let shared = Prefers()

    private override init() {
        self.userDefaults = UserDefaults.standard
        self.likesCache = userDefaults.stringArray(forKey: Prefers.likesKey) ?? DEFAULT_STARTS
        super.init()
    }

    var likes: [String] {
        return likesCache
    }

    /// 用户个人收藏（不含系统精选）
    var userLikes: [String] {
        return userDefaults.stringArray(forKey: Prefers.userLikesKey) ?? []
    }

    func like(_ path: String) {
        guard !likesCache.contains(path) else { return }
        likesCache.insert(path, at: 0)
        userDefaults.set(likesCache, forKey: Prefers.likesKey)

        // 同步到用户个人收藏
        var ul = userDefaults.stringArray(forKey: Prefers.userLikesKey) ?? []
        if !ul.contains(path) {
            ul.insert(path, at: 0)
            userDefaults.set(ul, forKey: Prefers.userLikesKey)
        }
    }

    func unlike(_ path: String) {
        if let index = likesCache.firstIndex(of: path) {
            likesCache.remove(at: index)
            userDefaults.set(likesCache, forKey: Prefers.likesKey)
        }

        // 从用户个人收藏移除
        var ul = userDefaults.stringArray(forKey: Prefers.userLikesKey) ?? []
        if let idx = ul.firstIndex(of: path) {
            ul.remove(at: idx)
            userDefaults.set(ul, forKey: Prefers.userLikesKey)
        }
    }

    func isLike(_ path: String) -> Bool {
        return likesCache.contains(path)
    }

    func updateReadingProgress(_ progress: [Int: CGFloat]) {
        userDefaults.set(progress, forKey: "readingProgress")
    }

    func updateTotalReadingTime(_ time: TimeInterval) {
        userDefaults.set(time, forKey: "totalReadingTime")
    }

    var lastPlayFile: [String]? {
        get {
            return userDefaults.array(forKey: Prefers.playFileKey) as? [String]
        }
        set {
            userDefaults.set(newValue, forKey: Prefers.playFileKey)
        }
    }

    var lastPlayMode: Int? {
        get {
            let mode = userDefaults.integer(forKey: Prefers.playModeKey)
            return mode == 0 ? nil : mode
        }
        set {
            userDefaults.set(newValue ?? 0, forKey: Prefers.playModeKey)
        }
    }

    // MARK: - Settings Properties

    /// Font size level: 0=特小, 1=小, 2=中(default), 3=大, 4=特大
    var fontSizeLevel: Int {
        get { userDefaults.integer(forKey: Prefers.fontSizeLevelKey) }
        set { userDefaults.set(newValue, forKey: Prefers.fontSizeLevelKey) }
    }

    var isDailyReminderOn: Bool {
        get { userDefaults.bool(forKey: Prefers.dailyReminderOnKey) }
        set { userDefaults.set(newValue, forKey: Prefers.dailyReminderOnKey) }
    }

    var reminderHour: Int {
        get {
            let h = userDefaults.integer(forKey: Prefers.reminderHourKey)
            return h == 0 ? 7 : h  // default 7:00
        }
        set { userDefaults.set(newValue, forKey: Prefers.reminderHourKey) }
    }

    var reminderMinute: Int {
        get { userDefaults.integer(forKey: Prefers.reminderMinuteKey) }
        set { userDefaults.set(newValue, forKey: Prefers.reminderMinuteKey) }
    }

    // MARK: - Reading Progress

    var lastReadPath: String? {
        get { userDefaults.string(forKey: Prefers.lastReadPathKey) }
        set { userDefaults.set(newValue, forKey: Prefers.lastReadPathKey) }
    }

    var lastReadPageIndex: Int {
        get { userDefaults.integer(forKey: Prefers.lastReadPageKey) }
        set { userDefaults.set(newValue, forKey: Prefers.lastReadPageKey) }
    }

    var lastReadMode: String? {
        get { userDefaults.string(forKey: Prefers.lastReadModeKey) }
        set { userDefaults.set(newValue, forKey: Prefers.lastReadModeKey) }
    }

    /// 按卷阅读：上次阅读的卷号 (0-9)，-1 表示无记录
    var lastReadChapter: Int {
        get {
            let v = userDefaults.integer(forKey: Prefers.lastReadChapterKey)
            return v == 0 ? -1 : v - 1  // 存储 1-10，避免 0 与"未设置"混淆
        }
        set {
            userDefaults.set(newValue + 1, forKey: Prefers.lastReadChapterKey)
        }
    }

    /// 按卷阅读：上次阅读的水平偏移量
    var lastReadChapterOffset: CGFloat {
        get { CGFloat(userDefaults.double(forKey: Prefers.lastReadChapterOffsetKey)) }
        set { userDefaults.set(Double(newValue), forKey: Prefers.lastReadChapterOffsetKey) }
    }

    func persist() {
        // synchronize() is no longer needed in modern iOS but kept for compatibility
        userDefaults.synchronize()
    }
}
