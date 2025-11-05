//
//  BookLoader.swift
//  Lengyan
//
//  Loads sutra data from JSON files
//  Modern async/await implementation
//

import Foundation

/// Loads sutra data from bundled JSON files
public final class BookLoader {
    private let bundle: Bundle

    public init(bundle: Bundle = Bundle.main) {
        self.bundle = bundle
    }

    /// Load all sutras from JSON files
    /// - Returns: Array of Sutra entities
    /// - Throws: Data loading errors
    public func loadAllSutras() async throws -> [Sutra] {
        let (indexData, contentData, treeData) = try await (
            loadJSON(named: "lengyanjing-index"),
            loadJSON(named: "lengyanjing-content"),
            loadJSON(named: "lengyanjing-index-tree")
        )

        let sutras = try parseSutras(from: indexData, contentData: contentData, treeData: treeData)
        return sutras
    }

    /// Load JSON data from bundle
    private func loadJSON(named: String) async throws -> Data {
        guard let url = bundle.url(forResource: named, withExtension: "json") else {
            throw DataError.resourceNotFound(named)
        }

        return try Data(contentsOf: url)
    }

    /// Parse sutras from loaded JSON data
    private func parseSutras(
        from indexData: Data,
        contentData: Data,
        treeData: Data
    ) throws -> [Sutra] {
        let decoder = JSONDecoder()

        let indexArray = try decoder.decode([[String: AnyCodable]].self, from: indexData)

        // Convert to Sutra entities
        let sutras: [Sutra] = indexArray.compactMap { dict in
            guard let path = dict["path"]?.value as? String,
                  let name = dict["name"]?.value as? String else {
                return nil
            }

            let typeRawValue = dict["type"]?.value as? String ?? "content"
            let type = SutraType(rawValue: typeRawValue) ?? .content

            // Try to find content for this path
            let content = dict["content"]?.value as? String

            // Extract chapter number if present
            let chapter = extractChapter(from: path)

            return Sutra(
                path: path,
                name: name,
                type: type,
                content: content,
                chapter: chapter
            )
        }

        return sutras
    }

    /// Extract chapter number from path
    /// e.g., "/A1/B2/C3" -> chapter = 1
    private func extractChapter(from path: String) -> Int? {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let firstComponent = components.first else {
            return nil
        }

        // Extract number from "A1" -> 1
        let numberString = firstComponent.dropFirst()
        return Int(numberString)
    }
}

// MARK: - Data Error Types

extension BookLoader {
    public enum DataError: Error, LocalizedError {
        case resourceNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name):
                return "Resource '\(name).json' not found in bundle"
            }
        }
    }
}

// MARK: - AnyCodable Helper

private struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self.init(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self.init(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.init(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self.init(boolValue)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.init(dictValue.mapValues { $0.value })
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.init(arrayValue.map { $0.value })
        } else {
            self.init(NSNull())
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value as? String)
    }
}
