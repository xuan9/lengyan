import XCTest
@testable import lengyan

final class ReadingResumeStateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var prefers: Prefers!

    override func setUp() {
        super.setUp()
        suiteName = "ReadingResumeStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        prefers = Prefers(userDefaults: defaults, readingPathValidator: { _ in true })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        prefers = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNoStoredProgressHasNoResumeTargets() {
        XCTAssertNil(prefers.chapterResumeTarget)
        XCTAssertNil(prefers.outlineResumeTarget)
        XCTAssertFalse(prefers.hasValidReadingProgress)
    }

    func testLegacyChapterAndOutlineProgressResolveIndependently() {
        defaults.set(3, forKey: "lastReadChapter") // Stored as chapter + 1.
        defaults.set(640, forKey: "lastReadChapterOffset")
        defaults.set("/legacy/tree/path", forKey: "lastReadPath")
        defaults.set("tree", forKey: "lastReadMode")

        XCTAssertEqual(
            prefers.chapterResumeTarget,
            .chapter(chapter: 2, offset: 640)
        )
        XCTAssertEqual(
            prefers.outlineResumeTarget,
            .tree(path: "/legacy/tree/path")
        )
    }

    func testLegacyEmptyAndRootPathsAreNotResumeTargets() {
        defaults.set("/", forKey: "lastReadPath")
        defaults.set("tree", forKey: "lastReadMode")
        XCTAssertNil(prefers.outlineResumeTarget)

        defaults.set("", forKey: "lastReadPath")
        XCTAssertNil(prefers.outlineResumeTarget)
        XCTAssertFalse(prefers.hasValidReadingProgress)
    }

    func testRecordedChapterUsesOnlyChapterSnapshot() throws {
        let recordedAt = Date(timeIntervalSince1970: 1_721_234_567)

        prefers.recordChapterReading(
            chapter: 4,
            offset: 512.25,
            characterIndex: 1_024,
            pageIndex: 3,
            at: recordedAt
        )

        XCTAssertEqual(
            prefers.chapterResumeTarget,
            .chapter(chapter: 4, offset: 512.25)
        )
        XCTAssertEqual(prefers.chapterResumeCharacterIndex(for: 4), 1_024)
        XCTAssertEqual(prefers.lastReadChapter, 4)
        XCTAssertEqual(prefers.lastReadChapterOffset, 512.25)

        let data = try XCTUnwrap(defaults.data(forKey: "chapterResumeSnapshotV2"))
        let snapshot = try JSONDecoder().decode(ReadingResumeSnapshot.self, from: data)
        XCTAssertEqual(snapshot.mode, .chapter)
        XCTAssertEqual(snapshot.chapterPageIndex, 3)
        XCTAssertEqual(snapshot.updatedAt, recordedAt.timeIntervalSince1970)
        XCTAssertNil(defaults.data(forKey: "readingResumeSnapshotV2"))
        XCTAssertNil(defaults.data(forKey: "pagedResumeSnapshotV2"))
        XCTAssertNil(defaults.data(forKey: "treeResumeSnapshotV2"))
    }

    func testOutlineStylesShareOneSnapshotAndPreserveChapterProgress() throws {
        prefers.recordChapterReading(chapter: 2, offset: 640, characterIndex: 900)
        let chapterData = try XCTUnwrap(defaults.data(forKey: "chapterResumeSnapshotV2"))

        prefers.recordPagedReading(path: "/paged/path", pageIndex: 7)

        var outlineData = try XCTUnwrap(defaults.data(forKey: "readingResumeSnapshotV2"))
        var outlineSnapshot = try JSONDecoder().decode(ReadingResumeSnapshot.self, from: outlineData)
        XCTAssertEqual(outlineSnapshot.mode, .paged)
        XCTAssertEqual(prefers.outlineResumeTarget, .paged(path: "/paged/path", pageIndex: 7))
        XCTAssertEqual(prefers.chapterResumeTarget, .chapter(chapter: 2, offset: 640))
        XCTAssertEqual(defaults.data(forKey: "chapterResumeSnapshotV2"), chapterData)

        prefers.recordTreeReading(path: "/tree/path")

        outlineData = try XCTUnwrap(defaults.data(forKey: "readingResumeSnapshotV2"))
        outlineSnapshot = try JSONDecoder().decode(ReadingResumeSnapshot.self, from: outlineData)
        XCTAssertEqual(outlineSnapshot.mode, .tree)
        XCTAssertEqual(prefers.outlineResumeTarget, .tree(path: "/tree/path"))
        XCTAssertEqual(prefers.chapterResumeTarget, .chapter(chapter: 2, offset: 640))
        XCTAssertNil(defaults.data(forKey: "pagedResumeSnapshotV2"))
        XCTAssertNil(defaults.data(forKey: "treeResumeSnapshotV2"))
    }

    func testInvalidOutlineRecordCannotReplaceValidProgress() throws {
        let validatingPrefers = Prefers(
            userDefaults: defaults,
            readingPathValidator: { $0 == "/valid/path" }
        )
        validatingPrefers.recordPagedReading(path: "/valid/path", pageIndex: 4)
        let savedData = try XCTUnwrap(defaults.data(forKey: "readingResumeSnapshotV2"))

        validatingPrefers.recordTreeReading(path: "/stale/path")
        validatingPrefers.recordTreeReading(path: "/")

        XCTAssertEqual(
            validatingPrefers.outlineResumeTarget,
            .paged(path: "/valid/path", pageIndex: 4)
        )
        XCTAssertEqual(defaults.data(forKey: "readingResumeSnapshotV2"), savedData)
        XCTAssertEqual(validatingPrefers.lastReadPath, "/valid/path")
    }

    func testOutlineSnapshotPersistsAcrossPrefersInstances() {
        prefers.recordPagedReading(path: "/persisted/paged/path", pageIndex: 17)

        let reloaded = Prefers(userDefaults: defaults, readingPathValidator: { _ in true })
        XCTAssertEqual(
            reloaded.outlineResumeTarget,
            .paged(path: "/persisted/paged/path", pageIndex: 17)
        )
    }

    func testExpandedOutlinePathsPersistAcrossRestartAndCollapse() {
        prefers.recordOutlineNodeExpanded(path: "/A1/B1")
        prefers.recordOutlineNodeExpanded(path: "/A1/B1/C1")

        var reloaded = Prefers(
            userDefaults: defaults,
            readingPathValidator: { _ in true }
        )
        XCTAssertEqual(
            reloaded.expandedOutlinePaths,
            ["/A1/B1", "/A1/B1/C1"]
        )

        reloaded.recordOutlineNodeCollapsed(path: "/A1/B1")
        reloaded = Prefers(
            userDefaults: defaults,
            readingPathValidator: { _ in true }
        )
        XCTAssertEqual(reloaded.expandedOutlinePaths, ["/A1/B1/C1"])
    }

    func testExpandedOutlinePathsIgnoreRootEmptyAndDuplicateRecords() {
        prefers.recordOutlineNodeExpanded(path: "")
        prefers.recordOutlineNodeExpanded(path: "/")
        prefers.recordOutlineNodeExpanded(path: "/A1/B1")
        prefers.recordOutlineNodeExpanded(path: "/A1/B1")

        XCTAssertEqual(prefers.expandedOutlinePaths, ["/A1/B1"])
        XCTAssertEqual(
            defaults.stringArray(forKey: "expandedOutlinePaths"),
            ["/A1/B1"]
        )
    }

    func testLegacyScalarChangesDoNotMergeBackIntoExistingV2State() {
        prefers.recordPagedReading(path: "/v2/path", pageIndex: 7)

        defaults.set("/changed/by/older/build", forKey: "lastReadPath")
        defaults.set(99, forKey: "lastReadPage")
        defaults.set("tree", forKey: "lastReadMode")

        XCTAssertEqual(
            prefers.outlineResumeTarget,
            .paged(path: "/v2/path", pageIndex: 7)
        )
    }

    func testLegacyV2ChannelsMigrateWithoutLosingEitherPosition() throws {
        let legacyCanonicalChapter = makeSnapshot(
            mode: .chapter,
            chapter: 6,
            chapterOffset: 448,
            chapterCharacterIndex: 700,
            revision: 30,
            updatedAt: 300
        )
        let legacyPaged = makeSnapshot(
            mode: .paged,
            path: "/older/paged/path",
            pageIndex: 8,
            revision: 10,
            updatedAt: 500
        )
        let legacyTree = makeSnapshot(
            mode: .tree,
            path: "/newer/tree/path",
            revision: 20,
            updatedAt: 100
        )
        try store(legacyCanonicalChapter, forKey: "readingResumeSnapshotV2")
        try store(legacyPaged, forKey: "pagedResumeSnapshotV2")
        try store(legacyTree, forKey: "treeResumeSnapshotV2")

        XCTAssertEqual(prefers.chapterResumeTarget, .chapter(chapter: 6, offset: 448))
        XCTAssertEqual(prefers.chapterResumeCharacterIndex(for: 6), 700)
        XCTAssertEqual(prefers.outlineResumeTarget, .tree(path: "/newer/tree/path"))

        // Repurposing the canonical key for an outline first migrates its old
        // chapter value into the dedicated chapter slot.
        prefers.recordPagedReading(path: "/current/paged/path", pageIndex: 12)
        XCTAssertEqual(prefers.chapterResumeTarget, .chapter(chapter: 6, offset: 448))
        XCTAssertEqual(
            prefers.outlineResumeTarget,
            .paged(path: "/current/paged/path", pageIndex: 12)
        )
        let chapterData = try XCTUnwrap(defaults.data(forKey: "chapterResumeSnapshotV2"))
        let migratedChapter = try JSONDecoder().decode(ReadingResumeSnapshot.self, from: chapterData)
        XCTAssertEqual(migratedChapter, legacyCanonicalChapter)
        let outlineData = try XCTUnwrap(defaults.data(forKey: "readingResumeSnapshotV2"))
        let currentOutline = try JSONDecoder().decode(ReadingResumeSnapshot.self, from: outlineData)
        XCTAssertEqual(currentOutline.revision, 31)
    }

    func testLegacyPerModeMigrationUsesRevisionBeforeWallClock() throws {
        try store(
            makeSnapshot(
                mode: .tree,
                path: "/older/tree/path",
                revision: 40,
                updatedAt: 500
            ),
            forKey: "treeResumeSnapshotV2"
        )
        try store(
            makeSnapshot(
                mode: .paged,
                path: "/newer/paged/path",
                pageIndex: 12,
                revision: 41,
                updatedAt: 100
            ),
            forKey: "pagedResumeSnapshotV2"
        )

        XCTAssertEqual(
            prefers.outlineResumeTarget,
            .paged(path: "/newer/paged/path", pageIndex: 12)
        )
    }

    func testLegacyPerModeMigrationUsesTimestampWhenRevisionIsAbsent() throws {
        try store(
            makeSnapshot(
                mode: .paged,
                path: "/older/paged/path",
                pageIndex: 3,
                updatedAt: 100
            ),
            forKey: "pagedResumeSnapshotV2"
        )
        try store(
            makeSnapshot(
                mode: .tree,
                path: "/newer/tree/path",
                updatedAt: 200
            ),
            forKey: "treeResumeSnapshotV2"
        )

        XCTAssertEqual(prefers.outlineResumeTarget, .tree(path: "/newer/tree/path"))
    }

    func testInvalidHighestRevisionSnapshotIsSkipped() throws {
        try store(
            makeSnapshot(
                mode: .paged,
                path: "/valid/path",
                pageIndex: 4,
                revision: 10,
                updatedAt: 100
            ),
            forKey: "pagedResumeSnapshotV2"
        )
        try store(
            makeSnapshot(
                mode: .tree,
                path: "/invalid/path",
                revision: 100,
                updatedAt: 200
            ),
            forKey: "treeResumeSnapshotV2"
        )
        let validatingPrefers = Prefers(
            userDefaults: defaults,
            readingPathValidator: { $0 == "/valid/path" }
        )

        XCTAssertEqual(
            validatingPrefers.outlineResumeTarget,
            .paged(path: "/valid/path", pageIndex: 4)
        )
    }

    func testOlderCanonicalChapterCannotOverwriteNewerDedicatedChapter() throws {
        let olderCanonical = makeSnapshot(
            mode: .chapter,
            chapter: 6,
            chapterOffset: 448,
            revision: 20,
            updatedAt: 200
        )
        let newerDedicated = makeSnapshot(
            mode: .chapter,
            chapter: 2,
            chapterOffset: 640,
            revision: 30,
            updatedAt: 100
        )
        try store(olderCanonical, forKey: "readingResumeSnapshotV2")
        try store(newerDedicated, forKey: "chapterResumeSnapshotV2")

        prefers.recordPagedReading(path: "/current/paged/path", pageIndex: 12)

        XCTAssertEqual(prefers.chapterResumeTarget, .chapter(chapter: 2, offset: 640))
        let chapterData = try XCTUnwrap(defaults.data(forKey: "chapterResumeSnapshotV2"))
        let retainedChapter = try JSONDecoder().decode(ReadingResumeSnapshot.self, from: chapterData)
        XCTAssertEqual(retainedChapter, newerDedicated)
    }

    func testCorruptOutlineSnapshotFallsBackToLegacyPerModeSnapshot() throws {
        defaults.set(Data("not-json".utf8), forKey: "readingResumeSnapshotV2")
        try store(
            makeSnapshot(
                mode: .tree,
                path: "/recoverable/tree/path",
                revision: 9,
                updatedAt: 300
            ),
            forKey: "treeResumeSnapshotV2"
        )

        XCTAssertEqual(
            prefers.outlineResumeTarget,
            .tree(path: "/recoverable/tree/path")
        )
    }

    func testStoredRootSnapshotIsRejectedEvenWithPermissiveValidator() throws {
        try store(
            makeSnapshot(
                mode: .paged,
                path: "/",
                pageIndex: 0,
                revision: 1,
                updatedAt: 100
            ),
            forKey: "readingResumeSnapshotV2"
        )
        defaults.set("/", forKey: "lastReadPath")

        XCTAssertNil(prefers.outlineResumeTarget)
    }

    func testInvalidLegacyPathDoesNotHideValidChapterProgress() {
        defaults.set(2, forKey: "lastReadChapter")
        defaults.set(320, forKey: "lastReadChapterOffset")
        defaults.set("/invalid/path", forKey: "lastReadPath")
        defaults.set("tree", forKey: "lastReadMode")
        let validatingPrefers = Prefers(
            userDefaults: defaults,
            readingPathValidator: { $0 == "/valid/path" }
        )

        XCTAssertEqual(
            validatingPrefers.chapterResumeTarget,
            .chapter(chapter: 1, offset: 320)
        )
        XCTAssertNil(validatingPrefers.outlineResumeTarget)
        XCTAssertTrue(validatingPrefers.hasValidReadingProgress)
    }

    func testOlderChapterSnapshotWithoutNewOptionalFieldsStillDecodes() {
        let legacySnapshot = Data("""
        {
          "mode": "chapter",
          "chapter": 2,
          "chapterOffset": 320,
          "updatedAt": 100
        }
        """.utf8)
        defaults.set(legacySnapshot, forKey: "chapterResumeSnapshotV2")

        XCTAssertEqual(
            prefers.chapterResumeTarget,
            .chapter(chapter: 2, offset: 320)
        )
        XCTAssertNil(prefers.chapterResumeCharacterIndex(for: 2))
    }

    func testChapterOffsetIsClampedToAUsableValue() {
        prefers.recordChapterReading(chapter: 1, offset: -CGFloat.infinity)

        XCTAssertEqual(
            prefers.chapterResumeTarget,
            .chapter(chapter: 1, offset: 0)
        )
    }

    func testChapterOffsetIsSnappedToNearestPageAndClamped() {
        XCTAssertEqual(
            ReadingResumeResolver.snappedChapterOffset(
                375,
                pageWidth: 320,
                maximumOffset: 960
            ),
            320
        )
        XCTAssertEqual(
            ReadingResumeResolver.snappedChapterOffset(
                900,
                pageWidth: 320,
                maximumOffset: 960
            ),
            960
        )
        XCTAssertEqual(
            ReadingResumeResolver.snappedChapterOffset(
                10_000,
                pageWidth: 320,
                maximumOffset: 960
            ),
            960
        )
        XCTAssertEqual(
            ReadingResumeResolver.snappedChapterOffset(
                -200,
                pageWidth: 320,
                maximumOffset: 960
            ),
            0
        )
    }

    func testChapterOffsetNormalizationRejectsInvalidGeometry() {
        XCTAssertEqual(
            ReadingResumeResolver.snappedChapterOffset(
                .nan,
                pageWidth: 320,
                maximumOffset: 960
            ),
            0
        )
        XCTAssertEqual(
            ReadingResumeResolver.snappedChapterOffset(
                320,
                pageWidth: 0,
                maximumOffset: 960
            ),
            0
        )
    }

    private func makeSnapshot(
        mode: ReadingResumeMode,
        path: String? = nil,
        pageIndex: Int? = nil,
        chapter: Int? = nil,
        chapterOffset: Double? = nil,
        chapterCharacterIndex: Int? = nil,
        chapterPageIndex: Int? = nil,
        revision: Int? = nil,
        updatedAt: TimeInterval
    ) -> ReadingResumeSnapshot {
        ReadingResumeSnapshot(
            mode: mode,
            path: path,
            pageIndex: pageIndex,
            chapter: chapter,
            chapterOffset: chapterOffset,
            chapterCharacterIndex: chapterCharacterIndex,
            chapterPageIndex: chapterPageIndex,
            revision: revision,
            updatedAt: updatedAt
        )
    }

    private func store(_ snapshot: ReadingResumeSnapshot, forKey key: String) throws {
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key)
    }
}
