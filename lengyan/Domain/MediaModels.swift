//
//  MediaModels.swift
//  lengyan
//
//  音频媒体数据模型
//

import Foundation

// MARK: - Media Data Model

struct MediaGroup: Identifiable {
    let id = UUID()
    let name: String
    let files: [String]
    let names: [String]
    let fileExtension: String
}

struct MediaItem: Identifiable {
    let id = UUID()
    let name: String
    let file: String
    let fileExtension: String
    let groupName: String
    let status: MediaStatus
    let progress: Double

    enum MediaStatus {
        case notDownloaded
        case downloading
        case downloaded
        case error
    }
}

// MARK: - Play Mode Enum

enum PlayMode: Int, CaseIterable {
    case repeatAll = -1
    case repeatOne = 999
    case playOnce = 1
    case playTwice = 2
    case play3Times = 3
    case play4Times = 4
    case play5Times = 5
    case play6Times = 6

    var displayName: String {
        switch self {
        case .repeatAll: return L10n.str("play_mode_repeat")
        case .repeatOne: return L10n.str("play_mode_repeat_one")
        case .playOnce: return String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), 1)
        case .playTwice: return String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), 2)
        case .play3Times: return String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), 3)
        case .play4Times: return String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), 4)
        case .play5Times: return String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), 5)
        case .play6Times: return String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), 6)
        }
    }

    var iconName: String {
        switch self {
        case .repeatAll: return "ic_repeat"
        case .repeatOne: return "ic_repeat_one"
        case .playOnce: return "ic_looks_1"
        case .playTwice: return "ic_looks_2"
        case .play3Times: return "ic_looks_3"
        case .play4Times: return "ic_looks_4"
        case .play5Times: return "ic_looks_5"
        case .play6Times: return "ic_looks_6"
        }
    }
}
