import Foundation
import XCTest

@testable import lengyan

final class BehaviorContractTests: XCTestCase {
    func testAudioStartFixturesMatchRuntimePolicy() throws {
        let fixture: BehaviorFixture<AudioStartCase> = try loadFixture(
            "audio-start-decision.json"
        )
        XCTAssertEqual(fixture.behavior, "audio-start-decision")

        for testCase in fixture.cases {
            let decision = AudioPlaybackResumePolicy.startDecision(
                savedAssetID: testCase.input.savedArtifactID,
                requestedAssetID: testCase.input.requestedArtifactID,
                savedTime: testCase.input.savedTimeSeconds
            )
            switch decision {
            case .beginning:
                XCTAssertEqual(testCase.expected.startMode, "beginning", testCase.name)
                XCTAssertNil(testCase.expected.seekTimeSeconds, testCase.name)
            case let .resume(time):
                XCTAssertEqual(testCase.expected.startMode, "resume", testCase.name)
                XCTAssertEqual(testCase.expected.seekTimeSeconds, time, testCase.name)
            }
        }
    }

    func testShareFileNameFixturesMatchRuntimeRenderer() throws {
        let fixture: BehaviorFixture<ShareFileNameCase> = try loadFixture(
            "share-file-name.json"
        )
        XCTAssertEqual(fixture.behavior, "share-file-name")
        let originalLanguage = Book.shared.isSimplifiedChinese
        defer { Book.shared.isSimplifiedChinese = originalLanguage }

        for testCase in fixture.cases {
            Book.shared.isSimplifiedChinese = testCase.input.locale == "zh-Hans"
            let actual: String
            if testCase.input.kind == "text" {
                actual = SutraCardRenderer.shareTextFileName(
                    source: testCase.input.source,
                    uniqueSuffix: testCase.input.uniqueSuffix
                )
            } else if let pageNumber = testCase.input.pageNumber,
                      let pageCount = testCase.input.pageCount {
                actual = SutraCardRenderer.shareJPEGFileName(
                    source: testCase.input.source,
                    uniqueSuffix: testCase.input.uniqueSuffix,
                    pageNumber: pageNumber,
                    pageCount: pageCount
                )
            } else {
                actual = SutraCardRenderer.shareJPEGFileName(
                    source: testCase.input.source,
                    uniqueSuffix: testCase.input.uniqueSuffix
                )
            }
            XCTAssertEqual(actual, testCase.expected.fileName, testCase.name)
            if testCase.input.source == nil {
                XCTAssertTrue(actual.hasPrefix(testCase.input.defaultBaseName), testCase.name)
            }
        }
    }

    func testDeepLinkFixturesMatchRuntimeParser() throws {
        let fixture: BehaviorFixture<DeepLinkCase> = try loadFixture("deep-link.json")
        XCTAssertEqual(fixture.behavior, "deep-link")

        for testCase in fixture.cases {
            let result = URL(string: testCase.input.url).flatMap(LengyanDeepLinkParser.parse)
            XCTAssertEqual(result != nil, testCase.expected.accepted, testCase.name)
            XCTAssertEqual(result?.productID, testCase.expected.productID, testCase.name)
            XCTAssertEqual(result?.legacyPath, testCase.expected.legacyPath, testCase.name)
        }
    }

    func testSearchFixturesMatchRuntimePolicy() throws {
        let fixture: BehaviorFixture<SearchTextCase> = try loadFixture("search-text.json")
        XCTAssertEqual(fixture.behavior, "search-text")

        for testCase in fixture.cases {
            let matches = SearchTextPolicy.matches(
                text: testCase.input.text,
                query: testCase.input.query
            )
            XCTAssertEqual(
                SearchTextPolicy.matches(
                    text: testCase.input.text,
                    normalizedQuery: testCase.expected.normalizedQuery
                ),
                testCase.expected.matches,
                testCase.name
            )
            let snippet = matches
                ? SearchTextPolicy.snippet(
                    from: testCase.input.text,
                    query: testCase.input.query,
                    maxLength: testCase.input.maxLength
                )
                : nil
            XCTAssertEqual(
                SearchTextPolicy.normalized(testCase.input.text),
                testCase.expected.normalizedText,
                testCase.name
            )
            XCTAssertEqual(
                SearchTextPolicy.normalized(testCase.input.query),
                testCase.expected.normalizedQuery,
                testCase.name
            )
            XCTAssertEqual(matches, testCase.expected.matches, testCase.name)
            XCTAssertEqual(matches ? testCase.input.path : nil, testCase.expected.resultPath, testCase.name)
            XCTAssertEqual(snippet, testCase.expected.snippet, testCase.name)
        }
    }

    func testDailyVerseFixturesMatchRuntimePolicy() throws {
        let fixture: BehaviorFixture<DailyVerseSelectionCase> = try loadFixture(
            "daily-verse-selection.json"
        )
        XCTAssertEqual(fixture.behavior, "daily-verse-selection")
        let formatter = ISO8601DateFormatter()

        for testCase in fixture.cases {
            let date = try XCTUnwrap(formatter.date(from: testCase.input.instant), testCase.name)
            let timeZone = try XCTUnwrap(
                TimeZone(identifier: testCase.input.timeZone),
                testCase.name
            )
            XCTAssertEqual(
                DailyVerseSelectionPolicy.localDateKey(for: date, timeZone: timeZone),
                testCase.expected.localDate,
                testCase.name
            )
            XCTAssertEqual(
                DailyVerseSelectionPolicy.selectedID(
                    productID: testCase.input.productID,
                    contentVersion: testCase.input.contentVersion,
                    date: date,
                    timeZone: timeZone,
                    candidateIDs: testCase.input.candidateIDs,
                    excluding: testCase.input.excludedID
                ),
                testCase.expected.selectedID,
                testCase.name
            )
        }
    }

    func testDailyVerseProviderPreservesAnExistingStoredSchedule() throws {
        let suiteName = "BehaviorContractTests.DailyVerse.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let scheduleKey = "DailyVerseSchedule"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = DailyVerseProvider(
            widgetTimelineReloader: {},
            userDefaults: defaults
        )

        let formatter = ISO8601DateFormatter()
        let date = try XCTUnwrap(formatter.date(from: "2026-07-25T16:30:00Z"))
        let dateKey = DailyVerseSelectionPolicy.localDateKey(
            for: date,
            timeZone: .current
        )
        defaults.set([dateKey: "/A1/B1/C1"], forKey: scheduleKey)

        XCTAssertEqual(provider.getPath(for: date), "/A1/B1/C1")
        XCTAssertEqual(
            defaults.dictionary(forKey: scheduleKey) as? [String: String],
            [dateKey: "/A1/B1/C1"]
        )
    }

    func testDailyVerseRuntimeConfigurationMatchesProductContracts() throws {
        let product: ProductIdentity = try decodeJSON(
            at: repositoryRoot.appendingPathComponent("Products/lengyan/product.json")
        )
        let book: BookVersion = try decodeJSON(
            at: repositoryRoot.appendingPathComponent("Products/lengyan/book-manifest.json")
        )
        XCTAssertEqual(LengyanDailyVerseConfiguration.productID, product.productID)
        XCTAssertEqual(LengyanDailyVerseConfiguration.contentVersion, book.contentVersion)
    }

    func testReadingResumeFixturesMatchRuntimeResolver() throws {
        let fixture: BehaviorFixture<ReadingResumeCase> = try loadFixture(
            "reading-resume.json"
        )
        XCTAssertEqual(fixture.behavior, "reading-resume")

        for testCase in fixture.cases {
            let mode = try XCTUnwrap(ReadingResumeMode(rawValue: testCase.input.mode))
            let snapshot = ReadingResumeSnapshot(
                mode: mode,
                path: testCase.input.path,
                pageIndex: testCase.input.pageIndex,
                chapter: testCase.input.chapter,
                chapterOffset: testCase.input.chapterOffset,
                chapterCharacterIndex: nil,
                chapterPageIndex: nil,
                revision: 1,
                updatedAt: 1
            )
            XCTAssertEqual(
                resumeTargetContract(ReadingResumeResolver.target(from: snapshot)),
                testCase.expected.target,
                testCase.name
            )
        }
    }

    func testLegacyFavoritesFixturesMatchRuntimeMigration() throws {
        let fixture: BehaviorFixture<LegacyFavoritesCase> = try loadFixture(
            "legacy-favorites-migration.json"
        )
        XCTAssertEqual(fixture.behavior, "legacy-favorites-migration")

        for (index, testCase) in fixture.cases.enumerated() {
            for curatedPath in testCase.input.curatedLegacyPaths {
                XCTAssertTrue(DEFAULT_STARTS.contains(curatedPath), testCase.name)
            }
            let suiteName = "BehaviorContractTests.favorites.\(index).\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set(testCase.input.legacyLikes, forKey: "likes")
            if let storedUserLikes = testCase.input.storedUserLikes {
                defaults.set(storedUserLikes, forKey: "userLikes")
            }

            let prefers = Prefers(
                userDefaults: defaults,
                readingPathValidator: { _ in true }
            )
            XCTAssertEqual(prefers.userLikes, testCase.expected.userLikes, testCase.name)
            XCTAssertEqual(
                defaults.stringArray(forKey: "userLikes"),
                testCase.expected.userLikes,
                testCase.name
            )
            XCTAssertEqual(
                defaults.stringArray(forKey: "likes"),
                testCase.expected.userLikes,
                testCase.name
            )
        }
    }

    func testLegacyLocationFixturesMatchGeneratedMap() throws {
        let fixture: BehaviorFixture<LegacyLocationCase> = try loadFixture(
            "legacy-location-resolution.json"
        )
        let map: LegacyPathMap = try decodeJSON(
            at: repositoryRoot
                .appendingPathComponent("Products/lengyan/Content/legacy-path-map.json")
        )
        let locations = Dictionary(uniqueKeysWithValues: map.paths.map {
            ($0.legacyPath, $0)
        })

        for testCase in fixture.cases {
            XCTAssertEqual(testCase.input.productID, map.productID, testCase.name)
            let result: LegacyLocationExpected
            if testCase.input.legacyPath.isEmpty || testCase.input.legacyPath == "/" {
                result = LegacyLocationExpected(
                    status: "invalid",
                    sectionID: nil,
                    paragraphID: nil
                )
            } else if let location = locations[testCase.input.legacyPath] {
                result = LegacyLocationExpected(
                    status: "mapped",
                    sectionID: location.sectionID,
                    paragraphID: location.directParagraphIDs.first
                        ?? location.firstDescendantParagraphID
                )
            } else {
                result = LegacyLocationExpected(
                    status: "unresolved",
                    sectionID: nil,
                    paragraphID: nil
                )
            }
            XCTAssertEqual(result, testCase.expected, testCase.name)
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadFixture<Case: Decodable>(
        _ fileName: String
    ) throws -> BehaviorFixture<Case> {
        try decodeJSON(
            at: repositoryRoot
                .appendingPathComponent("Contracts/BehaviorFixtures")
                .appendingPathComponent(fileName)
        )
    }

    private func decodeJSON<Value: Decodable>(at url: URL) throws -> Value {
        try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    private func resumeTargetContract(
        _ target: ReadingResumeTarget?
    ) -> ReadingResumeExpected.Target? {
        guard let target else { return nil }
        switch target {
        case let .chapter(chapter, offset):
            return .init(
                mode: "chapter",
                path: nil,
                pageIndex: nil,
                chapter: chapter,
                chapterOffset: Double(offset)
            )
        case let .paged(path, pageIndex):
            return .init(
                mode: "paged",
                path: path,
                pageIndex: pageIndex,
                chapter: nil,
                chapterOffset: nil
            )
        case let .tree(path):
            return .init(
                mode: "tree",
                path: path,
                pageIndex: nil,
                chapter: nil,
                chapterOffset: nil
            )
        }
    }
}

private struct BehaviorFixture<Case: Decodable>: Decodable {
    let behavior: String
    let cases: [Case]
}

private struct AudioStartCase: Decodable {
    struct Input: Decodable {
        let savedArtifactID: String?
        let requestedArtifactID: String
        let savedTimeSeconds: Double
    }

    struct Expected: Decodable {
        let startMode: String
        let seekTimeSeconds: Double?
    }

    let name: String
    let input: Input
    let expected: Expected
}

private struct ShareFileNameCase: Decodable {
    struct Input: Decodable {
        let locale: String
        let defaultBaseName: String
        let source: String?
        let kind: String
        let uniqueSuffix: String?
        let pageNumber: Int?
        let pageCount: Int?
    }

    struct Expected: Decodable {
        let fileName: String
    }

    let name: String
    let input: Input
    let expected: Expected
}

private struct DeepLinkCase: Decodable {
    struct Input: Decodable {
        let url: String
    }

    struct Expected: Decodable {
        let accepted: Bool
        let productID: String?
        let legacyPath: String?
    }

    let name: String
    let input: Input
    let expected: Expected
}

private struct SearchTextCase: Decodable {
    struct Input: Decodable {
        let text: String
        let query: String
        let path: String
        let maxLength: Int
    }

    struct Expected: Decodable {
        let normalizedText: String
        let normalizedQuery: String
        let matches: Bool
        let resultPath: String?
        let snippet: String?
    }

    let name: String
    let input: Input
    let expected: Expected
}

private struct DailyVerseSelectionCase: Decodable {
    struct Input: Decodable {
        let productID: String
        let contentVersion: String
        let instant: String
        let timeZone: String
        let candidateIDs: [String]
        let excludedID: String?
    }

    struct Expected: Decodable {
        let localDate: String
        let selectedID: String
    }

    let name: String
    let input: Input
    let expected: Expected
}

private struct ReadingResumeCase: Decodable {
    struct Input: Decodable {
        let mode: String
        let path: String?
        let pageIndex: Int?
        let chapter: Int?
        let chapterOffset: Double?
    }

    let name: String
    let input: Input
    let expected: ReadingResumeExpected
}

private struct ReadingResumeExpected: Decodable {
    struct Target: Decodable, Equatable {
        let mode: String
        let path: String?
        let pageIndex: Int?
        let chapter: Int?
        let chapterOffset: Double?
    }

    let target: Target?
}

private struct LegacyFavoritesCase: Decodable {
    struct Input: Decodable {
        let legacyLikes: [String]
        let storedUserLikes: [String]?
        let curatedLegacyPaths: [String]
    }

    struct Expected: Decodable {
        let userLikes: [String]
    }

    let name: String
    let input: Input
    let expected: Expected
}

private struct LegacyLocationCase: Decodable {
    struct Input: Decodable {
        let productID: String
        let legacyPath: String
        let usage: String
    }

    let name: String
    let input: Input
    let expected: LegacyLocationExpected
}

private struct LegacyLocationExpected: Decodable, Equatable {
    let status: String
    let sectionID: String?
    let paragraphID: String?
}

private struct LegacyPathMap: Decodable {
    struct Location: Decodable {
        let legacyPath: String
        let sectionID: String
        let directParagraphIDs: [String]
        let firstDescendantParagraphID: String?
    }

    let productID: String
    let paths: [Location]
}

private struct ProductIdentity: Decodable {
    let productID: String
}

private struct BookVersion: Decodable {
    let contentVersion: String
}
