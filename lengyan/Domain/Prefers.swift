//
//  Data.swift
//  lengyan
//
//  Created by Xuan on 16/6/26.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

enum ReadingResumeMode: String, Codable {
    case chapter
    case paged
    case tree
}

struct ReadingResumeSnapshot: Codable, Equatable {
    let mode: ReadingResumeMode
    let path: String?
    let pageIndex: Int?
    let chapter: Int?
    let chapterOffset: Double?
    let chapterCharacterIndex: Int?
    let chapterPageIndex: Int?
    let revision: Int?
    let updatedAt: TimeInterval
}

enum ReadingResumeTarget: Equatable {
    case chapter(chapter: Int, offset: CGFloat)
    case paged(path: String, pageIndex: Int)
    case tree(path: String)
}

/// Converts a stored snapshot into a resume destination and normalizes stored
/// offsets. Corpus membership is validated by `Prefers`/`Book` at the boundary.
enum ReadingResumeResolver {
    static func target(from snapshot: ReadingResumeSnapshot) -> ReadingResumeTarget? {
        switch snapshot.mode {
        case .chapter:
            guard let chapter = snapshot.chapter, (0..<10).contains(chapter) else {
                return nil
            }
            return .chapter(
                chapter: chapter,
                offset: validOffset(CGFloat(snapshot.chapterOffset ?? 0))
            )
        case .paged:
            guard let path = validPath(snapshot.path) else { return nil }
            return .paged(path: path, pageIndex: max(snapshot.pageIndex ?? 0, 0))
        case .tree:
            guard let path = validPath(snapshot.path) else { return nil }
            return .tree(path: path)
        }
    }

    private static func validPath(_ path: String?) -> String? {
        guard let path = path, !path.isEmpty, path != "/" else { return nil }
        return path
    }

    private static func validOffset(_ offset: CGFloat) -> CGFloat {
        guard offset.isFinite, offset > 0 else { return 0 }
        return offset
    }

    static func snappedChapterOffset(
        _ offset: CGFloat,
        pageWidth: CGFloat,
        maximumOffset: CGFloat
    ) -> CGFloat {
        guard
            offset.isFinite,
            pageWidth.isFinite,
            pageWidth > 0,
            maximumOffset.isFinite
        else { return 0 }

        let upperBound = max(maximumOffset, 0)
        let snapped = (offset / pageWidth).rounded() * pageWidth
        return min(max(snapped, 0), upperBound)
    }
}

protocol PrefersProtocol {
    var likes:[String]{get}
    var userLikes:[String]{get}
    var lastPlayFile:[String]?{get set}
    var lastPlayMode:Int?{get set}
    var fontSizeLevel: Int { get set }
    var isDailyReminderOn: Bool { get set }
    var reminderHour: Int { get set }
    var reminderMinute: Int { get set }
    var hasSeenSwipeGuide: Bool { get set }

    func like(_ path:String)
    func unlike(_ path:String)

    func updateReadingProgress(_ progress: [Int: CGFloat])
    func updateTotalReadingTime(_ time: TimeInterval)

    func persist()
}

class Prefers: NSObject, PrefersProtocol {
    private let userDefaults: UserDefaults
    private var likesCache: [String]
    private let readingPathValidator: (String) -> Bool

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
    // Keep the existing V2 key name, but use it solely as the outline
    // snapshot from now on. Older builds may have stored a chapter snapshot in
    // this slot; migration readers below handle that shape without dual-writing.
    private static let outlineResumeSnapshotKey = "readingResumeSnapshotV2"
    private static let chapterResumeSnapshotKey = "chapterResumeSnapshotV2"
    private static let legacyPagedResumeSnapshotKey = "pagedResumeSnapshotV2"
    private static let legacyTreeResumeSnapshotKey = "treeResumeSnapshotV2"
    private static let readingResumeRevisionKey = "readingResumeRevisionV2"
    private static let userLikesKey = "userLikes"
    private static let searchHistoryKey = "searchHistory"
    private static let hasSeenSwipeGuideKey = "hasSeenSwipeGuide"
    private static let hasSeenDailyReminderPromptKey = "hasSeenDailyReminderPrompt"
    private static let hasSeenWidgetGuideKey = "hasSeenWidgetGuide"

    static let shared = Prefers(userDefaults: .standard)

    init(
        userDefaults: UserDefaults,
        readingPathValidator: @escaping (String) -> Bool = { Book.shared.isValidResumePath($0) }
    ) {
        self.userDefaults = userDefaults
        self.likesCache = Prefers.loadUserLikes(from: userDefaults)
        self.readingPathValidator = readingPathValidator
        super.init()
    }

    /// 用户个人收藏（不含系统精选）
    var likes: [String] {
        return likesCache
    }

    /// 用户个人收藏（不含系统精选）
    var userLikes: [String] {
        return likesCache
    }

    func like(_ path: String) {
        guard !likesCache.contains(path) else { return }
        likesCache.insert(path, at: 0)
        persistUserLikes()
    }

    func unlike(_ path: String) {
        guard let index = likesCache.firstIndex(of: path) else { return }
        likesCache.remove(at: index)
        persistUserLikes()
    }

    func isLike(_ path: String) -> Bool {
        return likesCache.contains(path)
    }

    private func persistUserLikes() {
        likesCache = Prefers.uniquePaths(likesCache)
        userDefaults.set(likesCache, forKey: Prefers.userLikesKey)
        userDefaults.set(likesCache, forKey: Prefers.likesKey)
    }

    private static func loadUserLikes(from userDefaults: UserDefaults) -> [String] {
        if let storedUserLikes = userDefaults.stringArray(forKey: userLikesKey) {
            let paths = uniquePaths(storedUserLikes)
            userDefaults.set(paths, forKey: userLikesKey)
            userDefaults.set(paths, forKey: likesKey)
            return paths
        }

        if let legacyLikes = userDefaults.stringArray(forKey: likesKey) {
            let curatedPaths = Set(DEFAULT_STARTS)
            let paths = uniquePaths(legacyLikes.filter { !curatedPaths.contains($0) })
            userDefaults.set(paths, forKey: userLikesKey)
            userDefaults.set(paths, forKey: likesKey)
            return paths
        }

        userDefaults.set([], forKey: userLikesKey)
        userDefaults.set([], forKey: likesKey)
        return []
    }

    private static func uniquePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
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

    var lastPlayTime: Double {
        get { userDefaults.double(forKey: "lastPlayTime") }
        set { userDefaults.set(newValue, forKey: "lastPlayTime") }
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
        get {
            if userDefaults.object(forKey: Prefers.fontSizeLevelKey) == nil {
                return 2  // 默认为 中 (Medium)
            }
            return userDefaults.integer(forKey: Prefers.fontSizeLevelKey)
        }
        set { userDefaults.set(newValue, forKey: Prefers.fontSizeLevelKey) }
    }

    var isDailyReminderOn: Bool {
        get { userDefaults.bool(forKey: Prefers.dailyReminderOnKey) }
        set { userDefaults.set(newValue, forKey: Prefers.dailyReminderOnKey) }
    }

    var reminderHour: Int {
        get {
            if userDefaults.object(forKey: Prefers.reminderHourKey) == nil {
                return 8  // 默认为 8:00 AM
            }
            return userDefaults.integer(forKey: Prefers.reminderHourKey)
        }
        set { userDefaults.set(newValue, forKey: Prefers.reminderHourKey) }
    }

    var reminderMinute: Int {
        get {
            if userDefaults.object(forKey: Prefers.reminderMinuteKey) == nil {
                return 0  // 默认为 0 分
            }
            return userDefaults.integer(forKey: Prefers.reminderMinuteKey)
        }
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

    /// The volume reader retains one position: the most recently read volume.
    /// Outline progress is stored separately and never replaces it.
    var chapterResumeTarget: ReadingResumeTarget? {
        if let snapshot = latestValidStoredSnapshot(
            keys: [
                Prefers.chapterResumeSnapshotKey,
                Prefers.outlineResumeSnapshotKey,
            ],
            modes: [.chapter]
        ),
           let target = ReadingResumeResolver.target(from: snapshot) {
            return target
        }
        guard (0..<10).contains(lastReadChapter) else { return nil }
        let offset = lastReadChapterOffset
        return .chapter(
            chapter: lastReadChapter,
            offset: offset.isFinite && offset > 0 ? offset : 0
        )
    }

    func chapterResumeCharacterIndex(for chapter: Int) -> Int? {
        guard let snapshot = latestValidStoredSnapshot(
            keys: [
                Prefers.chapterResumeSnapshotKey,
                Prefers.outlineResumeSnapshotKey,
            ],
            modes: [.chapter]
        ),
              snapshot.chapter == chapter,
              let characterIndex = snapshot.chapterCharacterIndex,
              characterIndex >= 0 else { return nil }
        return characterIndex
    }

    /// Paged and tree presentation styles share one outline position. Legacy
    /// per-mode V2 snapshots are read only for migration and are no longer
    /// written independently.
    var outlineResumeTarget: ReadingResumeTarget? {
        if let snapshot = latestValidStoredSnapshot(
            keys: [
                Prefers.outlineResumeSnapshotKey,
                Prefers.legacyPagedResumeSnapshotKey,
                Prefers.legacyTreeResumeSnapshotKey,
            ],
            modes: [.paged, .tree]
        ),
           let target = ReadingResumeResolver.target(from: snapshot) {
            return target
        }

        guard let path = lastReadPath,
              !path.isEmpty,
              path != "/",
              readingPathValidator(path) else { return nil }
        if lastReadMode == ReadingResumeMode.tree.rawValue {
            return .tree(path: path)
        }
        return .paged(path: path, pageIndex: max(lastReadPageIndex, 0))
    }

    /// Suitable for prompts that should appear only after genuine, restorable
    /// reading activity. Unlike checking raw legacy keys, this rejects stale or
    /// root paths through the configured corpus validator.
    var hasValidReadingProgress: Bool {
        chapterResumeTarget != nil || outlineResumeTarget != nil
    }

    /// Records the most recently read volume. This is intentionally one slot,
    /// not a ten-volume history. Legacy scalar keys support one-way migration;
    /// progress changed after a downgrade is not merged back into V2 state.
    func recordChapterReading(
        chapter: Int,
        offset: CGFloat,
        characterIndex: Int? = nil,
        pageIndex: Int? = nil,
        at date: Date = Date()
    ) {
        guard (0..<10).contains(chapter) else { return }
        let safeOffset = offset.isFinite ? max(offset, 0) : 0
        let safeCharacterIndex = characterIndex.map { max($0, 0) }
        let safePageIndex = pageIndex.map { max($0, 0) }
        let revision = nextReadingResumeRevision()

        lastReadChapter = chapter
        lastReadChapterOffset = safeOffset
        let snapshot = ReadingResumeSnapshot(
            mode: .chapter,
            path: nil,
            pageIndex: nil,
            chapter: chapter,
            chapterOffset: Double(safeOffset),
            chapterCharacterIndex: safeCharacterIndex,
            chapterPageIndex: safePageIndex,
            revision: revision,
            updatedAt: date.timeIntervalSince1970
        )
        save(snapshot, forKey: Prefers.chapterResumeSnapshotKey)
    }

    func recordPagedReading(path: String, pageIndex: Int, at date: Date = Date()) {
        guard !path.isEmpty,
              path != "/",
              pageIndex >= 0,
              readingPathValidator(path) else { return }
        preserveLegacyCanonicalChapterIfNeeded()
        let revision = nextReadingResumeRevision()

        lastReadPath = path
        lastReadPageIndex = pageIndex
        lastReadMode = ReadingResumeMode.paged.rawValue
        let snapshot = ReadingResumeSnapshot(
            mode: .paged,
            path: path,
            pageIndex: pageIndex,
            chapter: nil,
            chapterOffset: nil,
            chapterCharacterIndex: nil,
            chapterPageIndex: nil,
            revision: revision,
            updatedAt: date.timeIntervalSince1970
        )
        save(snapshot, forKey: Prefers.outlineResumeSnapshotKey)
    }

    func recordTreeReading(path: String, at date: Date = Date()) {
        guard !path.isEmpty,
              path != "/",
              readingPathValidator(path) else { return }
        preserveLegacyCanonicalChapterIfNeeded()
        let revision = nextReadingResumeRevision()

        lastReadPath = path
        lastReadMode = ReadingResumeMode.tree.rawValue
        let snapshot = ReadingResumeSnapshot(
            mode: .tree,
            path: path,
            pageIndex: nil,
            chapter: nil,
            chapterOffset: nil,
            chapterCharacterIndex: nil,
            chapterPageIndex: nil,
            revision: revision,
            updatedAt: date.timeIntervalSince1970
        )
        save(snapshot, forKey: Prefers.outlineResumeSnapshotKey)
    }

    /// An intermediate V2 build also wrote chapter progress into the canonical
    /// key. Preserve that value once before repurposing the key for outlines.
    private func preserveLegacyCanonicalChapterIfNeeded() {
        guard let legacySnapshot = snapshot(forKey: Prefers.outlineResumeSnapshotKey),
              legacySnapshot.mode == .chapter,
              legacySnapshot.updatedAt.isFinite,
              let target = ReadingResumeResolver.target(from: legacySnapshot),
              isValid(target) else { return }

        if let existing = snapshot(forKey: Prefers.chapterResumeSnapshotKey),
           existing.mode == .chapter,
           existing.updatedAt.isFinite,
           let existingTarget = ReadingResumeResolver.target(from: existing),
           isValid(existingTarget),
           !snapshot(existing, isOlderThan: legacySnapshot) {
            return
        }
        save(legacySnapshot, forKey: Prefers.chapterResumeSnapshotKey)
    }

    private func latestValidStoredSnapshot(
        keys: [String],
        modes: [ReadingResumeMode]
    ) -> ReadingResumeSnapshot? {
        return keys
            .compactMap(snapshot(forKey:))
            .filter { snapshot in
                guard modes.contains(snapshot.mode) else { return false }
                guard snapshot.updatedAt.isFinite,
                      let target = ReadingResumeResolver.target(from: snapshot),
                      isValid(target) else { return false }
                return true
            }
            .max { lhs, rhs in snapshot(lhs, isOlderThan: rhs) }
    }

    private func nextReadingResumeRevision() -> Int {
        let snapshotKeys = [
            Prefers.outlineResumeSnapshotKey,
            Prefers.chapterResumeSnapshotKey,
            Prefers.legacyPagedResumeSnapshotKey,
            Prefers.legacyTreeResumeSnapshotKey,
        ]
        let snapshotRevision = snapshotKeys
            .compactMap { snapshot(forKey: $0)?.revision }
            .filter { $0 >= 0 }
            .max() ?? 0
        let current = max(
            max(
                userDefaults.integer(forKey: Prefers.readingResumeRevisionKey),
                snapshotRevision
            ),
            0
        )
        let next = current < Int.max ? current + 1 : Int.max
        userDefaults.set(next, forKey: Prefers.readingResumeRevisionKey)
        return next
    }

    private func snapshot(
        _ lhs: ReadingResumeSnapshot,
        isOlderThan rhs: ReadingResumeSnapshot
    ) -> Bool {
        let lhsRevision = lhs.revision.flatMap { $0 >= 0 ? $0 : nil }
        let rhsRevision = rhs.revision.flatMap { $0 >= 0 ? $0 : nil }

        switch (lhsRevision, rhsRevision) {
        case let (lhs?, rhs?) where lhs != rhs:
            return lhs < rhs
        case (_?, nil):
            return false
        case (nil, _?):
            return true
        default:
            return lhs.updatedAt < rhs.updatedAt
        }
    }

    private func isValid(_ target: ReadingResumeTarget) -> Bool {
        switch target {
        case .chapter:
            return true
        case let .paged(path, _), let .tree(path):
            return readingPathValidator(path)
        }
    }

    private func snapshot(forKey key: String) -> ReadingResumeSnapshot? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReadingResumeSnapshot.self, from: data)
    }

    private func save(_ snapshot: ReadingResumeSnapshot, forKey key: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }

    // MARK: - Search History

    var searchHistory: [String] {
        get { userDefaults.stringArray(forKey: Prefers.searchHistoryKey) ?? [] }
        set { userDefaults.set(Array(newValue.prefix(10)), forKey: Prefers.searchHistoryKey) }
    }

    func addSearchQuery(_ query: String) {
        let trimmed = String(query.trimmingCharacters(in: .whitespaces).prefix(20))
        guard !trimmed.isEmpty else { return }
        var history = searchHistory
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        searchHistory = history
    }

    func clearSearchHistory() {
        searchHistory = []
    }

    var hasSeenSwipeGuide: Bool {
        get { userDefaults.bool(forKey: Prefers.hasSeenSwipeGuideKey) }
        set { userDefaults.set(newValue, forKey: Prefers.hasSeenSwipeGuideKey) }
    }

    var hasSeenDailyReminderPrompt: Bool {
        get { userDefaults.bool(forKey: Prefers.hasSeenDailyReminderPromptKey) }
        set { userDefaults.set(newValue, forKey: Prefers.hasSeenDailyReminderPromptKey) }
    }

    var hasSeenWidgetGuide: Bool {
        get { userDefaults.bool(forKey: Prefers.hasSeenWidgetGuideKey) }
        set { userDefaults.set(newValue, forKey: Prefers.hasSeenWidgetGuideKey) }
    }

    func persist() {
        // synchronize() is no longer needed in modern iOS but kept for compatibility
        userDefaults.synchronize()
    }
}
