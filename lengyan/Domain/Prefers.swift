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

    static let shared = Prefers()

    private override init() {
        self.userDefaults = UserDefaults.standard
        self.likesCache = userDefaults.stringArray(forKey: Prefers.likesKey) ?? DEFAULT_STARTS
        super.init()
    }

    var likes: [String] {
        return likesCache
    }

    func like(_ path: String) {
        guard !likesCache.contains(path) else { return }
        likesCache.insert(path, at: 0)
        userDefaults.set(likesCache, forKey: Prefers.likesKey)
    }

    func unlike(_ path: String) {
        if let index = likesCache.firstIndex(of: path) {
            likesCache.remove(at: index)
            userDefaults.set(likesCache, forKey: Prefers.likesKey)
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

    func persist() {
        // synchronize() is no longer needed in modern iOS but kept for compatibility
        userDefaults.synchronize()
    }
}
