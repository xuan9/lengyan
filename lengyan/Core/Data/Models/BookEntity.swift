//
//  BookEntity.swift
//  Lengyan
//
//  Refactored architecture - Core data models
//  Following Clean Architecture principles
//

import Foundation

/// Core data model representing a complete sutra entity
public struct Sutra: Codable, Hashable, Identifiable {
    public let id: String
    public let path: String
    public let name: String
    public let type: SutraType
    public let children: [Sutra]?
    public let content: String?
    public let chapter: Int?
    public let mediaInfo: MediaInfo?

    public init(
        id: String = UUID().uuidString,
        path: String,
        name: String,
        type: SutraType,
        children: [Sutra]? = nil,
        content: String? = nil,
        chapter: Int? = nil,
        mediaInfo: MediaInfo? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.type = type
        self.children = children
        self.content = content
        self.chapter = chapter
        self.mediaInfo = mediaInfo
    }

    /// Returns true if this sutra has child elements
    public var hasChildren: Bool {
        return children?.isEmpty == false
    }

    /// Returns true if this sutra has content
    public var hasContent: Bool {
        return content?.isEmpty == false
    }
}

/// Type of sutra element
public enum SutraType: String, Codable, CaseIterable {
    case root = "/"
    case chapter = "chapter"
    case section = "section"
    case content = "content"
}

/// Information about associated media (audio)
public struct MediaInfo: Codable, Hashable {
    public let fileName: String?
    public let duration: TimeInterval?
    public let trackNumber: Int?

    public init(
        fileName: String? = nil,
        duration: TimeInterval? = nil,
        trackNumber: Int? = nil
    ) {
        self.fileName = fileName
        self.duration = duration
        self.trackNumber = trackNumber
    }
}

/// Represents a tree node in the sutra hierarchy
public struct SutraNode: Hashable, Identifiable {
    public let id = UUID()
    public let sutra: Sutra
    public var children: [SutraNode]

    public init(sutra: Sutra, children: [SutraNode] = []) {
        self.sutra = sutra
        self.children = children
    }

    /// Build tree structure from flat list
    public static func buildTree(from sutras: [Sutra]) -> [SutraNode] {
        var rootNodes: [SutraNode] = []
        var nodeDictionary: [String: SutraNode] = [:]

        // First pass: create all nodes
        for sutra in sutras {
            let node = SutraNode(sutra: sutra)
            nodeDictionary[sutra.path] = node
        }

        // Second pass: build hierarchy
        for sutra in sutras {
            if let node = nodeDictionary[sutra.path] {
                // Find parent
                let pathComponents = sutra.path.components(separatedBy: "/").filter { !$0.isEmpty }
                if pathComponents.count > 1 {
                    let parentPath = "/" + pathComponents[0..<pathComponents.count - 1].joined(separator: "/")
                    if let parent = nodeDictionary[parentPath] {
                        parent.children.append(node)
                    } else {
                        rootNodes.append(node)
                    }
                } else {
                    rootNodes.append(node)
                }
            }
        }

        return rootNodes
    }
}

/// Book index for fast lookups
public struct SutraIndex {
    private var index: [String: Sutra] = [:]

    public init(sutras: [Sutra]) {
        for sutra in sutras {
            index[sutra.path] = sutra
        }
    }

    /// Find sutra by path
    public func sutra(atPath path: String) -> Sutra? {
        return index[path]
    }

    /// Get all paths
    public var allPaths: [String] {
        return index.keys.sorted()
    }

    /// Count of indexed sutras
    public var count: Int {
        return index.count
    }
}
