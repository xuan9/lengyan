//
//  SearchService.swift
//  lengyan
//
//  全文搜索：科判标题 + 经文正文，双域合一
//

import Foundation

enum SearchResultType {
    case outline   // 科判标题命中
    case content   // 经文正文命中
}

struct SearchResult: Identifiable {
    let id = UUID()
    let path: String
    let chapterName: String
    let matchedText: String
    let type: SearchResultType
}

class SearchService {

    static let shared = SearchService()
    private init() {}

    /// 搜索科判标题 + 经文正文，科判结果优先
    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty, Book.shared.loaded else { return [] }

        var outlineResults: [SearchResult] = []
        var contentResults: [SearchResult] = []

        // 域 1：科判标题
        if let index = Book.shared.index {
            for item in index {
                guard let name = item["name"], let path = item["path"] else { continue }
                if name.contains(query) {
                    let snippet = snippet(from: name, query: query, maxLen: 50)
                    outlineResults.append(SearchResult(
                        path: path,
                        chapterName: parentName(for: path),
                        matchedText: snippet,
                        type: .outline
                    ))
                }
            }
        }

        // 域 2：经文正文
        if let contents = Book.shared.contents {
            for (path, sections) in contents {
                for section in sections {
                    guard section["type"] == "sutra", let text = section["content"] else { continue }
                    if text.contains(query) {
                        // 同一个 path 只取第一个命中的段落
                        let snippet = snippet(from: text, query: query, maxLen: 50)
                        contentResults.append(SearchResult(
                            path: path,
                            chapterName: parentName(for: path),
                            matchedText: snippet,
                            type: .content
                        ))
                        break
                    }
                }
            }
        }

        // 科判优先，正文在后；各域内最多 25 条，总计 50
        let maxPerCategory = 25
        return Array(outlineResults.prefix(maxPerCategory)) + Array(contentResults.prefix(maxPerCategory))
    }

    // MARK: - Helpers

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
