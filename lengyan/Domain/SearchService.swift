//
//  SearchService.swift
//  lengyan
//
//  全文搜索：科判标题 + 经文正文，双域合一
//

import Foundation

/// 合并结果：同一 path 的科判+经文命中合并为一条
struct MergedSearchResult: Identifiable {
    let id = UUID()
    let path: String
    let chapterName: String
    let outlineMatch: String?       // 科判命中片段
    let sutraMatch: String?         // 经文片段（命中或补充上下文）
    let sutraHit: Bool              // 经文是否真正命中关键词
    var hasOutline: Bool { outlineMatch != nil }
    var hasSutra: Bool { sutraMatch != nil }
}

class SearchService {

    static let shared = SearchService()
    private init() {}

    /// 合并搜索：同一 path 的科判+经文合并为 MergedSearchResult
    func mergedSearch(query: String) -> [MergedSearchResult] {
        guard !query.isEmpty, Book.shared.loaded else { return [] }

        var outlineByPath: [String: String] = [:]
        var sutraByPath: [String: String] = [:]

        // 域 1：科判标题
        if let index = Book.shared.index {
            for item in index {
                guard let name = item["name"], let path = item["path"] else { continue }
                if name.contains(query) {
                    outlineByPath[path] = snippet(from: name, query: query, maxLen: 50)
                }
            }
        }

        // 域 2：经文正文
        if let contents = Book.shared.contents {
            for (path, sections) in contents {
                for section in sections {
                    guard section["type"] == "sutra", let text = section["content"] else { continue }
                    if text.contains(query) {
                        sutraByPath[path] = snippet(from: text, query: query, maxLen: 50)
                        break
                    }
                }
            }
        }

        // 合并所有 path
        var allPaths = Set(outlineByPath.keys)
        allPaths.formUnion(sutraByPath.keys)

        let results = allPaths.map { path -> MergedSearchResult in
            let hit = sutraByPath[path]
            let sutraMatch = hit ?? firstSutraSnippet(for: path, maxLen: 50)
            return MergedSearchResult(
                path: path,
                chapterName: parentName(for: path),
                outlineMatch: outlineByPath[path],
                sutraMatch: sutraMatch,
                sutraHit: hit != nil
            )
        }

        // 按经文自然顺序排列（path 字典序 = 从经首到经尾）
        return results.sorted { $0.path < $1.path }
    }

    // MARK: - Helpers

    /// 获取某 path 下第一段经文的开头片段（用于纯科判命中时补充经文上下文）
    private func firstSutraSnippet(for path: String, maxLen: Int) -> String? {
        guard let sections = Book.shared.contents?[path] else { return nil }
        for section in sections {
            guard section["type"] == "sutra", let text = section["content"] else { continue }
            let cleaned = text.replacingOccurrences(of: "\n", with: " ")
            let snippet = String(cleaned.prefix(maxLen))
            return snippet.isEmpty ? nil : snippet + "..."
        }
        return nil
    }

    /// 截取匹配关键词周围的文本片段
    private func snippet(from text: String, query: String, maxLen: Int) -> String {
        guard let range = text.range(of: query) else {
            return String(text.prefix(maxLen))
        }
        let start = text.index(range.lowerBound, offsetBy: -maxLen/3, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: maxLen * 2/3, limitedBy: text.endIndex) ?? text.endIndex
        let snippet = String(text[start..<end])
        let cleaned = snippet.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > maxLen {
            return String(cleaned.prefix(maxLen)) + "..."
        }
        return cleaned
    }

    /// 获取父级科判名称作为出处
    private func parentName(for path: String) -> String {
        let item = Book.shared.itemOfPath(path)
        if let name = item["name"] as? String, !name.isEmpty {
            // 尝试获取父级
            if let parent = Book.shared.parentOfItem(item),
               let parentName = parent["name"] as? String, !parentName.isEmpty {
                return parentName
            }
            return name
        }
        return ""
    }
}
