//
//  lengyanTests.swift
//  lengyanTests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import XCTest
import UIKit
import SwiftUI
import AVFoundation
import MediaPlayer
@testable import lengyan

class lengyanTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testBookLoading() {
        let expectation = expectation(description: "Book load completes")
        Book.shared.loadDataWithCompletionHandler { result in
            guard case .success = result else {
                XCTFail("Expected bundled corpus to load: \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertNotNil(Book.shared.tree)
            XCTAssertNotNil(Book.shared.index)
            XCTAssertNotNil(Book.shared.contents)
            XCTAssertNotNil(Book.shared.media)
            
            XCTAssertEqual(Book.shared.tree!["path"] as! String, "")
            XCTAssertEqual(Book.shared.index![0]["path"], "")
            XCTAssertEqual(Book.shared.contents!["/A1/B1/C1"]![0]["type"], "sutra")
            XCTAssertEqual(Book.shared.media![0]["extension"] as! String, "m4a")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testSynchronousBookLoadingInvokesCompletionAndMarksCompleteCorpusLoaded() {
        var didComplete = false

        let result = Book.shared.loadDataSyncWithCompletionHandler { result in
            didComplete = true
            guard case .success = result else {
                XCTFail("Expected bundled corpus to load: \(result)")
                return
            }
        }

        XCTAssertTrue(didComplete)
        guard case .success = result else {
            XCTFail("Expected successful synchronous load")
            return
        }
        XCTAssertTrue(Book.shared.loaded)
        XCTAssertFalse(Book.shared.tree?.isEmpty ?? true)
        XCTAssertFalse(Book.shared.index?.isEmpty ?? true)
        XCTAssertFalse(Book.shared.contents?.isEmpty ?? true)
        XCTAssertFalse(Book.shared.media?.isEmpty ?? true)
        XCTAssertFalse(Book.shared.chapterMap?.isEmpty ?? true)
    }

    func testBookLoadFailureCanRetryAfterResourcesBecomeAvailable() {
        let providerLock = NSLock()
        var resourcesAvailable = false
        let book = Book { resourceName, fileExtension in
            providerLock.lock()
            let available = resourcesAvailable
            providerLock.unlock()
            guard available else { return nil }
            return bundledBookResourceData(resourceName, fileExtension)
        }
        book.isSimplifiedChinese = true

        let firstResult = book.loadDataSyncWithCompletionHandler { _ in }
        guard case let .failure(.missingOrInvalidResources(resources)) = firstResult else {
            XCTFail("Expected a deterministic missing-resource failure")
            return
        }
        XCTAssertTrue(resources.contains("index tree"))
        XCTAssertNil(book.tree)

        providerLock.lock()
        resourcesAvailable = true
        providerLock.unlock()

        let retried = expectation(description: "Book retry completes")
        book.retryLoading { result in
            guard case .success = result else {
                XCTFail("Expected retry to publish the complete corpus: \(result)")
                retried.fulfill()
                return
            }
            XCTAssertTrue(book.loaded)
            XCTAssertNotNil(book.tree)
            XCTAssertNotNil(book.contents)
            retried.fulfill()
        }
        wait(for: [retried], timeout: 5)
    }

    func testBookRejectsCorruptRequiredResource() {
        let book = Book { resourceName, fileExtension in
            if resourceName.hasSuffix("lengyanjing-content") {
                return Foundation.Data("{".utf8)
            }
            return bundledBookResourceData(resourceName, fileExtension)
        }
        book.isSimplifiedChinese = true

        let result = book.loadDataSyncWithCompletionHandler { _ in }
        guard case let .failure(.missingOrInvalidResources(resources)) = result else {
            XCTFail("Expected corrupt content JSON to fail atomically")
            return
        }
        XCTAssertTrue(resources.contains("content"))
        XCTAssertFalse(book.loaded)
        XCTAssertNil(book.tree)
        XCTAssertNil(book.contents)
    }

    func testBookDegradesMalformedOptionalMediaWithoutBlockingReading() {
        let book = Book { resourceName, fileExtension in
            if resourceName.hasSuffix("lengyanjing-media") {
                return Foundation.Data("""
                [{"name":"invalid","extension":"m4a","files":["ly01"],"names":[]}]
                """.utf8)
            }
            return bundledBookResourceData(resourceName, fileExtension)
        }
        book.isSimplifiedChinese = true

        let result = book.loadDataSyncWithCompletionHandler { _ in }
        guard case .success = result else {
            XCTFail("Optional audio metadata must not disable the reading corpus")
            return
        }
        XCTAssertTrue(book.loaded)
        XCTAssertEqual(book.media?.count, 0)
        XCTAssertFalse(book.tree?.isEmpty ?? true)
        XCTAssertFalse(book.contents?.isEmpty ?? true)
    }

    func testConcurrentBookLoadersParseAndPublishOnce() {
        let providerLock = NSLock()
        var providerCallCount = 0
        let book = Book { resourceName, fileExtension in
            providerLock.lock()
            providerCallCount += 1
            providerLock.unlock()
            return bundledBookResourceData(resourceName, fileExtension)
        }
        book.isSimplifiedChinese = true

        let completed = expectation(description: "Concurrent Book loads complete")
        completed.expectedFulfillmentCount = 8
        for _ in 0..<8 {
            book.loadDataWithCompletionHandler { result in
                guard case .success = result else {
                    XCTFail("Expected every queued caller to share the successful load")
                    completed.fulfill()
                    return
                }
                completed.fulfill()
            }
        }
        wait(for: [completed], timeout: 15)

        providerLock.lock()
        let finalCallCount = providerCallCount
        providerLock.unlock()
        XCTAssertEqual(finalCallCount, 5, "The five corpus resources should be parsed once")
        XCTAssertTrue(book.loaded)
    }

    func testResumePathValidationRejectsRootAliasesAndMalformedPaths() {
        let result = Book.shared.loadDataSyncWithCompletionHandler { _ in }
        guard case .success = result else {
            XCTFail("Expected bundled corpus to load")
            return
        }

        XCTAssertTrue(Book.shared.isValidResumePath("/A1/B1/C1"))
        XCTAssertFalse(Book.shared.isValidResumePath(""))
        XCTAssertFalse(Book.shared.isValidResumePath("/"))
        XCTAssertFalse(Book.shared.isValidResumePath("/A1//B1/C1"))
        XCTAssertFalse(Book.shared.isValidResumePath("/A1/B1/C1/"))
        XCTAssertFalse(Book.shared.isValidResumePath("/missing/path"))
    }

    func testPagedReaderIndexIncludesEveryCorpusContentPath() throws {
        guard case .success = Book.shared.loadDataSyncWithCompletionHandler({ _ in }) else {
            XCTFail("Expected bundled corpus to load")
            return
        }
        let index = try XCTUnwrap(Book.shared.index)
        let contents = try XCTUnwrap(Book.shared.contents)
        let pagedPaths = index.indices.compactMap { indexPosition -> String? in
            guard Book.shared.isItemLeaf(indexPosition) == true else { return nil }
            return index[indexPosition]["path"]
        }

        XCTAssertEqual(pagedPaths.count, Set(pagedPaths).count)
        XCTAssertEqual(
            Set(pagedPaths),
            Set(contents.keys),
            "Horizontal page traversal must not skip any stored scripture section"
        )
        XCTAssertTrue(
            contents.values.flatMap { $0 }.allSatisfy {
                !($0["content"] ?? "").isEmpty
            }
        )
    }

    func testReadingStayTimerAccumulatesOnlyForegroundIntervals() {
        let baseline = Date(timeIntervalSince1970: 1_000)
        var timer = ReadingStayTimer(threshold: 10)

        timer.start(at: baseline)
        timer.pause(at: baseline.addingTimeInterval(8))
        XCTAssertFalse(timer.isValidReading(at: baseline.addingTimeInterval(100)))

        timer.start(at: baseline.addingTimeInterval(100))
        XCTAssertFalse(timer.isValidReading(at: baseline.addingTimeInterval(101.99)))
        XCTAssertTrue(timer.isValidReading(at: baseline.addingTimeInterval(102)))

        var passiveTimer = ReadingStayTimer()
        passiveTimer.start(at: baseline)
        XCTAssertFalse(passiveTimer.isValidReading(at: baseline.addingTimeInterval(2.99)))
        XCTAssertTrue(passiveTimer.isValidReading(at: baseline.addingTimeInterval(3)))
    }

    func testReadingCheckpointGateAutomaticallyCommitsAtPassiveThreshold() {
        let committed = expectation(description: "Passive reading is checkpointed")
        let gate = ReadingCheckpointGate(threshold: 0.05)

        gate.resume {
            committed.fulfill()
        }

        wait(for: [committed], timeout: 1)
        XCTAssertTrue(gate.isConfirmed)
    }

    func testReadingCheckpointGateExplicitActionCommitsImmediately() {
        let staleThreshold = expectation(description: "Cancelled threshold does not fire")
        staleThreshold.isInverted = true
        let gate = ReadingCheckpointGate(threshold: 0.05)
        var checkpointCount = 0

        gate.resume {
            staleThreshold.fulfill()
        }
        gate.commit {
            checkpointCount += 1
        }

        XCTAssertTrue(gate.isConfirmed)
        XCTAssertEqual(checkpointCount, 1)
        wait(for: [staleThreshold], timeout: 0.1)
    }

    func testReadingCheckpointGateExcludesPausedBackgroundTime() {
        let paused = expectation(description: "Gate pauses before threshold")
        let backgroundElapsed = expectation(description: "Background interval elapses")
        let committed = expectation(description: "Remaining foreground time commits")
        let staleThreshold = expectation(description: "Pre-pause threshold is cancelled")
        staleThreshold.isInverted = true
        let gate = ReadingCheckpointGate(threshold: 0.12)

        gate.resume {
            staleThreshold.fulfill()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            gate.pause {}
            paused.fulfill()
        }
        wait(for: [paused], timeout: 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            XCTAssertFalse(gate.isConfirmed)
            gate.resume {
                committed.fulfill()
            }
            backgroundElapsed.fulfill()
        }
        wait(for: [backgroundElapsed, committed], timeout: 1, enforceOrder: true)
        XCTAssertTrue(gate.isConfirmed)
        wait(for: [staleThreshold], timeout: 0.05)
    }

    func testFeedbackPayloadIsMinimal() {
        let payload = FeedbackService.makePayload(
            content: "页面无法翻页",
            productID: "lengyan",
            appVersion: "1.3"
        )

        XCTAssertEqual(payload, [
            "content": "页面无法翻页",
            "productID": "lengyan",
            "appVersion": "1.3",
        ])
        XCTAssertNil(payload["type"])
        XCTAssertNil(payload["device"])
        XCTAssertNil(payload["deviceFamily"])
        XCTAssertNil(payload["osVersion"])
        XCTAssertNil(payload["build"])
    }

    func testFeedbackProductIdentityIsExplicitAndContractShaped() {
        XCTAssertEqual(FeedbackService.currentProductID(), "lengyan")
        XCTAssertEqual(FeedbackService.normalizedProductID("lengyan"), "lengyan")
        XCTAssertEqual(FeedbackService.normalizedProductID("jingang-v2"), "jingang-v2")
        XCTAssertNil(FeedbackService.normalizedProductID("Lengyan"))
        XCTAssertNil(FeedbackService.normalizedProductID("lengyan--beta"))
        XCTAssertNil(FeedbackService.normalizedProductID(" lengyan"))
        XCTAssertNil(FeedbackService.normalizedProductID("lengyan\n"))
        XCTAssertNil(FeedbackService.normalizedProductID(String(repeating: "a", count: 65)))
    }

    func testFeedbackSubmissionRejectsInvalidProductBeforeTransport() {
        let completion = expectation(description: "Invalid product is rejected locally")

        FeedbackService.submit(
            FeedbackService.FeedbackRequest(
                productID: "lengyan--invalid",
                content: "不应发送"
            )
        ) { result in
            if case .failure(.invalidRequest) = result {
                // Expected.
            } else {
                XCTFail("Invalid product identity must fail before transport")
            }
            completion.fulfill()
        }

        wait(for: [completion], timeout: 0.1)
    }

    func testFeedbackLengthUsesTheSubmittedTrimmedContent() {
        let normalized = FeedbackService.normalizedContent(" \n反馈内容\t ")
        XCTAssertEqual(normalized, "反馈内容")
        XCTAssertEqual(normalized.count, 4)
    }

    func testFeedbackLengthGuidanceAppearsOnlyForFinalTwoHundredCharacters() {
        let maximum = FeedbackService.maximumContentLength

        XCTAssertEqual(
            FeedbackLengthState.resolve(contentLength: 0, maximum: maximum),
            .hidden
        )
        XCTAssertEqual(
            FeedbackLengthState.resolve(contentLength: maximum - 201, maximum: maximum),
            .hidden
        )
        XCTAssertEqual(
            FeedbackLengthState.resolve(contentLength: maximum - 200, maximum: maximum),
            .remaining(200)
        )
        XCTAssertEqual(
            FeedbackLengthState.resolve(contentLength: maximum - 1, maximum: maximum),
            .remaining(1)
        )
        XCTAssertEqual(
            FeedbackLengthState.resolve(contentLength: maximum, maximum: maximum),
            .limitReached
        )
        XCTAssertEqual(
            FeedbackLengthState.resolve(contentLength: maximum + 23, maximum: maximum),
            .overLimit(23)
        )

        XCTAssertEqual(
            FeedbackLengthState.accessibilityAnnouncementLevel(
                contentLength: maximum - 201,
                maximum: maximum
            ),
            0
        )
        XCTAssertEqual(
            FeedbackLengthState.accessibilityAnnouncementLevel(
                contentLength: maximum - 200,
                maximum: maximum
            ),
            1
        )
        XCTAssertEqual(
            FeedbackLengthState.accessibilityAnnouncementLevel(
                contentLength: maximum - 100,
                maximum: maximum
            ),
            1
        )
        XCTAssertEqual(
            FeedbackLengthState.accessibilityAnnouncementLevel(
                contentLength: maximum,
                maximum: maximum
            ),
            2
        )
        XCTAssertEqual(
            FeedbackLengthState.accessibilityAnnouncementLevel(
                contentLength: maximum + 1,
                maximum: maximum
            ),
            3
        )
    }

    func testLegacyFeedbackDraftIsConsumedAndRemoved() {
        let suiteName = "FeedbackDraftTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("尚未发送的反馈", forKey: "feedbackDraft")

        XCTAssertEqual(
            FeedbackService.consumeLegacyDraft(from: defaults),
            "尚未发送的反馈"
        )
        XCTAssertNil(defaults.object(forKey: "feedbackDraft"))
        XCTAssertEqual(FeedbackService.consumeLegacyDraft(from: defaults), "")
    }

    func testFeedbackReferenceValidation() {
        let validReference = "0123456789abcdef0123456789abcdef"
        XCTAssertEqual(
            FeedbackService.normalizedReference("  \(validReference)\n"),
            validReference
        )
        XCTAssertNil(FeedbackService.normalizedReference("LY-abcd_1234"))
        XCTAssertNil(FeedbackService.normalizedReference(validReference.uppercased()))
        XCTAssertNil(FeedbackService.normalizedReference(String(validReference.dropLast())))
        XCTAssertEqual(
            FeedbackService.displayReference(validReference),
            "0123456789abcdef\n0123456789abcdef"
        )
        XCTAssertNil(FeedbackService.displayReference("not-a-reference"))
    }

    func testFeedbackSubmissionResultDistinguishesLimitFailures() {
        if case .failure(.contentTooLong) = FeedbackService.submissionResult(
            statusCode: 413,
            data: nil
        ) {
            // Expected.
        } else {
            XCTFail("HTTP 413 should produce a content-length error")
        }

        if case .failure(.rateLimited) = FeedbackService.submissionResult(
            statusCode: 429,
            data: nil
        ) {
            // Expected.
        } else {
            XCTFail("HTTP 429 should produce a rate-limit error")
        }
    }

    func testFeedbackSubmissionResultRequiresAValidSuccessReference() {
        let reference = "0123456789abcdef0123456789abcdef"
        let validResponse = Foundation.Data(
            "{\"ok\":true,\"reference\":\"\(reference)\"}".utf8
        )

        guard case let .success(returnedReference) = FeedbackService.submissionResult(
            statusCode: 200,
            data: validResponse
        ) else {
            XCTFail("A valid Worker success response should be accepted")
            return
        }
        XCTAssertEqual(returnedReference, reference)

        let invalidResponse = Foundation.Data(
            "{\"ok\":true,\"reference\":\"not-a-reference\"}".utf8
        )
        if case .failure(.serverRejected) = FeedbackService.submissionResult(
            statusCode: 200,
            data: invalidResponse
        ) {
            // Expected.
        } else {
            XCTFail("A malformed success response must fail closed")
        }
    }

    func testNightReadingThemeRemainsUnavailable() {
        let defaults = UserDefaults.standard
        let key = "selectedTheme"
        let previousStoredValue = defaults.object(forKey: key)
        let previousTheme = SutraDesignTokens.shared.currentTheme
        defer {
            SutraDesignTokens.shared.setTheme(previousTheme)
            if let previousStoredValue {
                defaults.set(previousStoredValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        XCTAssertEqual(
            SutraDesignTokens.enabledTheme(.dark).rawValue,
            SutraTheme.sepia.rawValue
        )
        XCTAssertEqual(
            SutraDesignTokens.enabledTheme(.light).rawValue,
            SutraTheme.light.rawValue
        )

        defaults.set(SutraTheme.dark.rawValue, forKey: key)
        SutraDesignTokens.shared.loadSavedTheme()
        XCTAssertEqual(SutraDesignTokens.shared.currentTheme.rawValue, SutraTheme.sepia.rawValue)
        XCTAssertEqual(defaults.string(forKey: key), SutraTheme.sepia.rawValue)

        SutraDesignTokens.shared.setTheme(.dark)
        XCTAssertEqual(SutraDesignTokens.shared.currentTheme.rawValue, SutraTheme.sepia.rawValue)
    }

    func testThemeChangeImmediatelyRestylesExistingRootTabBar() {
        let completed = expectation(description: "Visible tab bar adopts the selected theme")

        DispatchQueue.main.async {
            guard
                let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                let tabBarController = appDelegate.window?.rootViewController as? UITabBarController
            else {
                XCTFail("Expected the app's root tab bar controller")
                completed.fulfill()
                return
            }

            let tokens = SutraDesignTokens.shared
            let previousTheme = tokens.currentTheme
            let targetTheme: SutraTheme = previousTheme == .light ? .sepia : .light
            defer {
                tokens.setTheme(previousTheme)
                completed.fulfill()
            }

            tokens.setTheme(targetTheme)

            let tabBar = tabBarController.tabBar
            let expectedBackground = tokens.color(for: .tabBar)
            XCTAssertTrue(
                tabBar.standardAppearance.backgroundColor?.isEqual(expectedBackground) == true
            )
            XCTAssertTrue(
                tabBar.scrollEdgeAppearance?.backgroundColor?.isEqual(expectedBackground) == true
            )
            XCTAssertTrue(tabBar.backgroundColor?.isEqual(expectedBackground) == true)
            XCTAssertTrue(tabBar.tintColor?.isEqual(tokens.color(for: .primary)) == true)
            XCTAssertTrue(
                tabBar.unselectedItemTintColor?.isEqual(tokens.color(for: .textSecondary)) == true
            )
        }

        wait(for: [completed], timeout: 3)
    }

    func testWidgetTypographyUsesAvailableMediumAndLargeSpaceForShortVerses() {
        let shortVerseLength = 52
        let mediumSize = CGSize(width: 338, height: 158)
        let largeSize = CGSize(width: 338, height: 354)

        XCTAssertEqual(
            WidgetVerseLayout.mediumFontSize(
                text: String(repeating: "见", count: shortVerseLength),
                containerSize: mediumSize
            ),
            20
        )
        XCTAssertEqual(
            WidgetVerseLayout.largeFontSize(
                text: String(repeating: "见", count: shortVerseLength),
                containerSize: largeSize,
                hasSource: true
            ),
            24
        )

        let longMediumSize = WidgetVerseLayout.mediumFontSize(
            text: String(repeating: "见", count: 120),
            containerSize: mediumSize
        )
        XCTAssertLessThan(longMediumSize, 20)
        XCTAssertGreaterThanOrEqual(
            longMediumSize,
            WidgetVerseLayout.mediumMinimumFontSize
        )
    }

    func testWidgetTypographyCapsLongPassagesBeforeCrossingReadableFloor() {
        let compactMedium = CGSize(width: 292, height: 141)
        let compactLarge = CGSize(width: 292, height: 311)
        let roomyLarge = CGSize(width: 362, height: 379)

        let passage = String(repeating: "见", count: 300)
        let compactMediumText = WidgetVerseLayout.mediumDisplayText(
            String(passage.prefix(120)),
            containerSize: compactMedium
        )
        let compactLargeText = WidgetVerseLayout.largeDisplayText(
            passage,
            containerSize: compactLarge,
            hasSource: true
        )
        let roomyLargeText = WidgetVerseLayout.largeDisplayText(
            passage,
            containerSize: roomyLarge,
            hasSource: true
        )

        XCTAssertGreaterThanOrEqual(compactMediumText.count, 70)
        XCTAssertLessThan(compactMediumText.count, 120)
        XCTAssertGreaterThan(compactLargeText.count, compactMediumText.count)
        XCTAssertLessThanOrEqual(compactLargeText.count, 300)
        XCTAssertGreaterThan(roomyLargeText.count, compactLargeText.count)
        XCTAssertLessThanOrEqual(roomyLargeText.count, 300)
    }

    func testWidgetTypographyFitsEveryProviderLengthAcrossSystemFrameRange() {
        let mediumFrames = [
            CGSize(width: 292, height: 141),
            CGSize(width: 338, height: 158),
            CGSize(width: 362, height: 169),
            CGSize(width: 380, height: 178),
        ]
        let largeFrames = [
            CGSize(width: 292, height: 311),
            CGSize(width: 338, height: 354),
            CGSize(width: 362, height: 379),
            CGSize(width: 380, height: 380),
        ]
        let sizeCategories: [(swiftUI: ContentSizeCategory, uiKit: UIContentSizeCategory)] = [
            (.extraSmall, .extraSmall),
            (.large, .large),
            (.extraExtraExtraLarge, .extraExtraExtraLarge),
            (.accessibilityExtraExtraExtraLarge, .accessibilityExtraExtraExtraLarge),
        ]

        for frame in mediumFrames {
            for category in sizeCategories {
                let available = WidgetVerseLayout.mediumAvailableSize(frame)

                for sourceLength in 1...300 {
                    let candidate = String(
                        repeating: "见",
                        count: min(sourceLength, 120)
                    )
                    let displayedText = WidgetVerseLayout.mediumDisplayText(
                        candidate,
                        containerSize: frame,
                        sizeCategory: category.swiftUI
                    )
                    let fontSize = WidgetVerseLayout.mediumFontSize(
                        text: displayedText,
                        containerSize: frame,
                        sizeCategory: category.swiftUI
                    )
                    let measuredHeight = measuredWidgetTextHeight(
                        text: displayedText,
                        fontSize: fontSize,
                        width: available.width,
                        lineSpacing: WidgetVerseLayout.mediumLineSpacing,
                        contentSizeCategory: category.uiKit
                    )

                    XCTAssertGreaterThanOrEqual(
                        fontSize,
                        WidgetVerseLayout.mediumMinimumFontSize
                    )
                    XCTAssertLessThanOrEqual(
                        fontSize,
                        WidgetVerseLayout.mediumMaximumFontSize
                    )
                    XCTAssertLessThanOrEqual(
                        measuredHeight,
                        available.height + 1,
                        "Medium length \(sourceLength), category \(category.swiftUI), does not fit \(frame) at \(fontSize)pt"
                    )
                }
            }
        }

        for frame in largeFrames {
            for hasSource in [false, true] {
                for category in sizeCategories {
                    let available = WidgetVerseLayout.largeAvailableSize(
                        frame,
                        hasSource: hasSource
                    )
                    for sourceLength in 1...300 {
                        let candidate = String(repeating: "见", count: sourceLength)
                        let displayedText = WidgetVerseLayout.largeDisplayText(
                            candidate,
                            containerSize: frame,
                            hasSource: hasSource,
                            sizeCategory: category.swiftUI
                        )
                        let fontSize = WidgetVerseLayout.largeFontSize(
                            text: displayedText,
                            containerSize: frame,
                            hasSource: hasSource,
                            sizeCategory: category.swiftUI
                        )
                        let measuredHeight = measuredWidgetTextHeight(
                            text: displayedText,
                            fontSize: fontSize,
                            width: available.width,
                            lineSpacing: WidgetVerseLayout.largeLineSpacing,
                            contentSizeCategory: category.uiKit
                        )

                        XCTAssertGreaterThanOrEqual(
                            fontSize,
                            WidgetVerseLayout.largeMinimumFontSize
                        )
                        XCTAssertLessThanOrEqual(
                            fontSize,
                            WidgetVerseLayout.largeMaximumFontSize
                        )
                        XCTAssertLessThanOrEqual(
                            measuredHeight,
                            available.height + 1,
                            "Large length \(sourceLength), source \(hasSource), category \(category.swiftUI), does not fit \(frame) at \(fontSize)pt"
                        )
                    }
                }
            }
        }
    }

    @MainActor
    func testWidgetShortAndLongVerseLayoutsRenderInSystemFamilyFrames() {
        let shortText = "是故阿难！汝今当知，见明之时，见非是明；见暗之时，见非是暗；见空之时，见非是空；见塞之时，见非是塞。"
        let longText = Array(repeating: shortText, count: 6).joined()
        let shortEntry = DailyVerseEntry(
            date: Date(),
            text: shortText,
            fullText: shortText,
            source: "卷一 · 先定离缘第一义",
            path: "/A2/B1",
            theme: "sepia"
        )
        let longEntry = DailyVerseEntry(
            date: Date(),
            text: shortText,
            fullText: longText,
            source: "卷一 · 先定离缘第一义",
            path: "/A2/B1",
            theme: "sepia"
        )

        let renderCases: [(String, CGSize, AnyView)] = [
            (
                "Widget-Small-Compact",
                CGSize(width: 141, height: 141),
                AnyView(SmallVerseView(entry: shortEntry))
            ),
            (
                "Widget-Medium-Compact-Short",
                CGSize(width: 292, height: 141),
                AnyView(MediumVerseView(entry: shortEntry))
            ),
            (
                "Widget-Medium-Compact-Long",
                CGSize(width: 292, height: 141),
                AnyView(MediumVerseView(entry: longEntry))
            ),
            (
                "Widget-Medium-Short",
                CGSize(width: 338, height: 158),
                AnyView(MediumVerseView(entry: shortEntry))
            ),
            (
                "Widget-Large-Compact-Short",
                CGSize(width: 292, height: 311),
                AnyView(LargeVerseView(entry: shortEntry))
            ),
            (
                "Widget-Large-Compact-Long",
                CGSize(width: 292, height: 311),
                AnyView(LargeVerseView(entry: longEntry))
            ),
            (
                "Widget-Large-Short",
                CGSize(width: 338, height: 354),
                AnyView(LargeVerseView(entry: shortEntry))
            ),
            (
                "Widget-Large-Long",
                CGSize(width: 338, height: 354),
                AnyView(LargeVerseView(entry: longEntry))
            ),
        ]

        for (name, size, view) in renderCases {
            let image = renderWidget(view, size: size)
            XCTAssertEqual(image.size, size)
            XCTAssertGreaterThan(
                image.pngData()?.count ?? 0,
                3_000,
                "\(name) should contain rendered text, not an empty surface"
            )
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    private func renderWidget(_ content: AnyView, size: CGSize) -> UIImage {
        WidgetTokens.resolveTheme(from: "sepia")
        let rootView = content
            .frame(width: size.width, height: size.height)
            .background(WidgetTokens.background)
            .environment(\.sizeCategory, .large)

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: rootView)
            renderer.proposedSize = ProposedViewSize(size)
            renderer.scale = 2
            if let image = renderer.uiImage {
                return image
            }
        }

        let controller = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }

    private func measuredWidgetTextHeight(
        text: String,
        fontSize: CGFloat,
        width: CGFloat,
        lineSpacing: CGFloat,
        contentSizeCategory: UIContentSizeCategory
    ) -> CGFloat {
        let baseFont = UIFont(name: "STKaiti", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        let traits = UITraitCollection(
            preferredContentSizeCategory: contentSizeCategory
        )
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: baseFont,
            compatibleWith: traits
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing
        return ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraph,
                ],
                context: nil
            ).height
        )
    }

    func testAudioTrackRowsAdaptContinuouslyWithoutChangingPhoneOrLandscape() {
        XCTAssertEqual(
            SutraAdaptiveLayout.audioTrackRowHeight(
                containerSize: CGSize(width: 834, height: 1_119),
                deviceIdiom: .pad
            ),
            62
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.audioTrackRowHeight(
                containerSize: CGSize(width: 1_194, height: 759),
                deviceIdiom: .pad
            ),
            52
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.audioTrackRowHeight(
                containerSize: CGSize(width: 900, height: 1_040),
                deviceIdiom: .pad
            ),
            57
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.audioTrackRowHeight(
                containerSize: CGSize(width: 1_024, height: 1_316),
                deviceIdiom: .pad
            ),
            68
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.audioTrackRowHeight(
                containerSize: CGSize(width: 390, height: 763),
                deviceIdiom: .phone
            ),
            52
        )
    }

    func testAdaptiveReadingWidthsDistinguishLargeIPadPortraitAndLandscape() {
        XCTAssertEqual(
            SutraAdaptiveLayout.homeHorizontalInsets(
                containerSize: CGSize(width: 1_024, height: 1_366)
            ),
            128
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.homeHorizontalInsets(
                containerSize: CGSize(width: 820, height: 1_180)
            ),
            26
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.homeHorizontalInsets(
                containerSize: CGSize(width: 1_366, height: 1_024)
            ),
            203
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.readingHorizontalInsets(
                containerWidth: 1_024,
                containerHeight: 1_366
            ),
            172
        )
        XCTAssertEqual(
            SutraAdaptiveLayout.readingHorizontalInsets(
                containerWidth: 1_366,
                containerHeight: 1_024
            ),
            203
        )

        let splitIPadActions = SutraAdaptiveLayout.homeTwoRowActionWidths(
            availableWidth: 500,
            columnGap: 16,
            preferredTrailingWidth: 88
        )
        XCTAssertEqual(splitIPadActions.primary, 396)
        XCTAssertEqual(splitIPadActions.trailing, 88)
        XCTAssertGreaterThan(splitIPadActions.primary, splitIPadActions.trailing)
        XCTAssertEqual(splitIPadActions.primary + 16 + splitIPadActions.trailing, 500)

        let iPhoneActions = SutraAdaptiveLayout.homeTwoRowActionWidths(
            availableWidth: 342,
            columnGap: 16,
            preferredTrailingWidth: 72
        )
        XCTAssertEqual(iPhoneActions.primary, 254)
        XCTAssertEqual(iPhoneActions.trailing, 72)
        XCTAssertGreaterThan(iPhoneActions.primary, iPhoneActions.trailing)
        XCTAssertEqual(iPhoneActions.primary + 16 + iPhoneActions.trailing, 342)

        let singleRowActions = SutraAdaptiveLayout.homeSingleRowPrimaryWidths(
            availableWidth: 700,
            reservedWidth: 200,
            preferredListeningWidth: 160
        )
        XCTAssertEqual(singleRowActions.resume, 340)
        XCTAssertEqual(singleRowActions.listening, 160)
        XCTAssertGreaterThan(singleRowActions.resume, singleRowActions.listening)

        let widerSingleRowActions = SutraAdaptiveLayout.homeSingleRowPrimaryWidths(
            availableWidth: 748,
            reservedWidth: 200,
            preferredListeningWidth: 160
        )
        XCTAssertEqual(widerSingleRowActions.resume, 388)
        XCTAssertEqual(widerSingleRowActions.listening, 160)
        XCTAssertEqual(
            widerSingleRowActions.resume - singleRowActions.resume,
            48
        )

        let longResumeDistribution = SutraAdaptiveLayout.homeSingleRowContentDistribution(
            maximumResumeWidth: 340,
            initialListeningWidth: 160,
            preferredResumeWidth: 500,
            preferredListeningWidth: 160
        )
        XCTAssertEqual(longResumeDistribution.resume, 340)
        XCTAssertEqual(longResumeDistribution.listening, 160)
        XCTAssertEqual(longResumeDistribution.gap, 8)

        let shortResumeDistribution = SutraAdaptiveLayout.homeSingleRowContentDistribution(
            maximumResumeWidth: 340,
            initialListeningWidth: 160,
            preferredResumeWidth: 196,
            preferredListeningWidth: 160
        )
        XCTAssertEqual(shortResumeDistribution.resume, 196)
        XCTAssertEqual(shortResumeDistribution.listening, 160)
        XCTAssertEqual(shortResumeDistribution.gap, 56)
        XCTAssertEqual(
            shortResumeDistribution.resume
                + shortResumeDistribution.listening
                + shortResumeDistribution.gap * 3,
            longResumeDistribution.resume
                + longResumeDistribution.listening
                + longResumeDistribution.gap * 3
        )

        let shortResumeLongListening = SutraAdaptiveLayout.homeSingleRowContentDistribution(
            maximumResumeWidth: 340,
            initialListeningWidth: 160,
            preferredResumeWidth: 196,
            preferredListeningWidth: 250
        )
        XCTAssertEqual(shortResumeLongListening.resume, 196)
        XCTAssertEqual(shortResumeLongListening.listening, 250)
        XCTAssertEqual(shortResumeLongListening.gap, 26)
        XCTAssertEqual(
            shortResumeLongListening.resume
                + shortResumeLongListening.listening
                + shortResumeLongListening.gap * 3,
            longResumeDistribution.resume
                + longResumeDistribution.listening
                + longResumeDistribution.gap * 3
        )

        let longListeningActions = SutraAdaptiveLayout.homeSingleRowPrimaryWidths(
            availableWidth: 700,
            reservedWidth: 200,
            preferredListeningWidth: 400
        )
        XCTAssertEqual(longListeningActions.resume, 275)
        XCTAssertEqual(longListeningActions.listening, 225)

        XCTAssertEqual(
            SutraAdaptiveLayout.homeOpeningVerseHeight(
                fontLineHeight: 22,
                lineSpacing: 6,
                minimumHeight: 44
            ),
            50
        )
        XCTAssertNotNil(UIImage(systemName: "scroll"))
    }

    func testOpeningVerseLocalizationsPreserveTwoLines() throws {
        for localization in ["Base", "zh-Hans", "zh-Hant"] {
            let path = try XCTUnwrap(
                Bundle.main.path(forResource: localization, ofType: "lproj"),
                "Missing \(localization) localization"
            )
            let bundle = try XCTUnwrap(Bundle(path: path))
            let verse = bundle.localizedString(
                forKey: "kai_jing_ji",
                value: nil,
                table: nil
            )
            XCTAssertEqual(
                verse.components(separatedBy: "\n").count,
                2,
                "\(localization) opening verse should render as two deliberate lines"
            )
        }
    }
    
    func testPaging(){
        let expectation = expectation(description: "Book load completes")
        Book.shared.loadDataWithCompletionHandler { result in
            guard case .success = result else {
                XCTFail("Expected bundled corpus to load: \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(Book.shared.getPreviousPagePath("/A2/B1/C2/D1/E2/F1/G1/H2/I1"), "/A2/B1/C2/D1/E2/F1/G1/H1/I3")
            XCTAssertEqual(Book.shared.getPreviousPagePath("/A2/B1/C2/D1/E2/F1/G1/H2/I1/J1"), "/A2/B1/C2/D1/E2/F1/G1/H1/I3")
            XCTAssertEqual(Book.shared.getNextPagePath("/A2/B1/C2/D1/E2/F1/G1/H1/I3"), "/A2/B1/C2/D1/E2/F1/G1/H2/I1" )
            XCTAssertEqual(Book.shared.getBelongingKeyPagePath("/A2/B1/C2/D1/E2/F1/G1/H1/I3/J2"), "/A2/B1/C2/D1/E2/F1/G1/H1/I3")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testAudioSeekMethod() {
        let observer = AudioPlayerObserver.shared
        observer.initializePlayerIfNeeded()
        observer.seek(to: 125.0)
        XCTAssertEqual(observer.currentTime, 125.0)
        observer.cleanup()
    }

    func testColdPlaybackResumesOnlyTheSavedAsset() {
        XCTAssertEqual(
            AudioPlaybackResumePolicy.startDecision(
                savedAssetID: "ly03",
                requestedAssetID: "ly03",
                savedTime: 125
            ),
            .resume(at: 125)
        )
        XCTAssertEqual(
            AudioPlaybackResumePolicy.startDecision(
                savedAssetID: "ly03",
                requestedAssetID: "ly04",
                savedTime: 125
            ),
            .beginning
        )
        XCTAssertEqual(
            AudioPlaybackResumePolicy.startDecision(
                savedAssetID: "ly03",
                requestedAssetID: "ly03",
                savedTime: 0
            ),
            .beginning
        )
    }

    func testColdPlaybackSeekIgnoresInitialZeroProgressCallback() {
        XCTAssertNil(
            AudioPeriodicProgressPolicy.visibleTime(
                playerTime: 0,
                isSeeking: true
            )
        )
        XCTAssertEqual(
            AudioPeriodicProgressPolicy.visibleTime(
                playerTime: 125,
                isSeeking: false
            ),
            125
        )
    }
    
    func testAudioInterruption() {
        let observer = AudioPlayerObserver.shared
        observer.initializePlayerIfNeeded()
        observer.isPlaying = true
        
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        
        let expectation = self.expectation(description: "Wait for main queue")
        DispatchQueue.main.async {
            XCTAssertFalse(observer.isPlaying)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        observer.cleanup()
    }
    
    func testLockScreenNowPlayingInfo() {
        let observer = AudioPlayerObserver.shared
        observer.initializePlayerIfNeeded()
        observer.currentTrack = "测试佛经"
        observer.currentTime = 50.0
        observer.totalTime = 300.0
        observer.isPlaying = true
        
        observer.updateNowPlayingInfo()
        
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(info)
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "测试佛经")
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 50.0)
        XCTAssertEqual(info?[MPMediaItemPropertyPlaybackDuration] as? Double, 300.0)
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
        XCTAssertNotNil(info?[MPMediaItemPropertyArtwork])
        
        observer.cleanup()
    }
    
    func testAudioCatalogTrackOrderAndWraparound() {
        XCTAssertEqual(
            AudioAssetCatalog.orderedIDs,
            ["ly01", "ly02", "ly03", "ly04", "ly05", "ly06", "ly07", "ly08", "ly09", "ly10", "lyz1"]
        )
        XCTAssertEqual(AudioAssetCatalog.next(after: "ly01")?.id, "ly02")
        XCTAssertEqual(AudioAssetCatalog.next(after: "ly10")?.id, "lyz1")
        XCTAssertEqual(AudioAssetCatalog.next(after: "lyz1")?.id, "ly01")
    }

    func testShareLongImagePolicyMatchesCharacterAndHeightLimits() {
        func repeatedSutraText(count: Int) -> String {
            sutraText(characterCount: count)
        }

        func renderScale(for count: Int) -> CGFloat? {
            let text = repeatedSutraText(count: count)
            let base = SutraCardRenderer.verseFontBase(forCharCount: text.count)
            let height = SutraCardRenderer.compactPortraitHeight(text: text, verseFontBase: base)
            return SutraCardRenderer.longImageRenderScale(characterCount: text.count, targetHeight: height)
        }

        let shortText = repeatedSutraText(count: 80)
        let shortBase = SutraCardRenderer.verseFontBase(forCharCount: shortText.count)
        let shortHeight = SutraCardRenderer.compactPortraitHeight(text: shortText, verseFontBase: shortBase)
        XCTAssertLessThanOrEqual(shortText.count, SutraCardRenderer.highResolutionLongImageCharacterCount)
        XCTAssertLessThanOrEqual(shortHeight, SutraCardRenderer.highResolutionLongImageHeight)
        XCTAssertEqual(renderScale(for: shortText.count), 2.0)

        let mediumText = repeatedSutraText(count: 1500)
        let mediumBase = SutraCardRenderer.verseFontBase(forCharCount: mediumText.count)
        let mediumHeight = SutraCardRenderer.compactPortraitHeight(text: mediumText, verseFontBase: mediumBase)
        XCTAssertLessThanOrEqual(mediumText.count, SutraCardRenderer.maxLongShareImageCharacterCount)
        XCTAssertLessThanOrEqual(mediumHeight, SutraCardRenderer.maxLongShareImageHeight)
        XCTAssertEqual(renderScale(for: mediumText.count), 1.0)

        let readableBase = SutraCardRenderer.readableShareFontBase()
        let compactMaxText = repeatedSutraText(count: 3000)
        let compactMaxBase = SutraCardRenderer.verseFontBase(forCharCount: compactMaxText.count)
        XCTAssertGreaterThanOrEqual(compactMaxBase, readableBase)

        let maxText = repeatedSutraText(count: SutraCardRenderer.maxLongShareImageCharacterCount)
        let maxBase = SutraCardRenderer.verseFontBase(forCharCount: maxText.count)
        let maxHeight = SutraCardRenderer.compactPortraitHeight(text: maxText, verseFontBase: maxBase)
        XCTAssertLessThanOrEqual(maxHeight, SutraCardRenderer.maxLongShareImageHeight)
        XCTAssertEqual(renderScale(for: maxText.count), 1.0)

        XCTAssertNil(renderScale(for: SutraCardRenderer.maxLongShareImageCharacterCount + 1))
        XCTAssertNil(SutraCardRenderer.longCardRenderPlan(text: repeatedSutraText(count: 9000), source: "《楞嚴經》"))
        XCTAssertNotNil(SutraCardRenderer.paginatedCardPlan(text: repeatedSutraText(count: 9000), source: "《楞嚴經》"))
    }

    func testShareOversizedTextUsesPaginationBeforeFullHeightMeasurement() {
        let oversizedText = sutraText(characterCount: 20_000)
        XCTAssertNil(SutraCardRenderer.longCardRenderPlan(text: oversizedText, source: "《楞嚴經》"))

        guard let paginationPlan = SutraCardRenderer.paginatedCardPlan(text: oversizedText, source: "《楞嚴經》") else {
            XCTFail("Expected oversized share text to use paginated image plan")
            return
        }
        XCTAssertEqual(paginationPlan.pageCount, 7)
        XCTAssertEqual(paginationPlan.firstPagePlan.text.count, SutraCardRenderer.paginatedShareImageCharacterCount)
        XCTAssertTrue(paginationPlan.firstPagePlan.source.contains("1/7"))
    }

    func testShareExtremeTextFallsBackToTextOnly() {
        let extremeText = sutraText(characterCount: SutraCardRenderer.maxPaginatedShareImageCharacterCount + 1)
        XCTAssertNil(SutraCardRenderer.longCardRenderPlan(text: extremeText, source: "《楞嚴經》"))
        XCTAssertNil(SutraCardRenderer.paginatedCardPlan(text: extremeText, source: "《楞嚴經》"))
    }

    @MainActor
    func testSharePaginatedImagesAreWrittenAsNumberedJPEGFiles() throws {
        let text = sutraText(characterCount: 9000)
        let plan = try XCTUnwrap(SutraCardRenderer.paginatedCardPlan(text: text, source: "《楞嚴經》"))
        XCTAssertEqual(plan.pageCount, 3)

        let urls = SutraCardRenderer.writePaginatedJPEGFiles(plan: plan)
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }

        XCTAssertEqual(urls.count, 3)
        XCTAssertTrue(urls[0].lastPathComponent.contains("分享"))
        XCTAssertTrue(urls[0].lastPathComponent.contains("01-03"))
        XCTAssertTrue(urls[1].lastPathComponent.contains("02-03"))
        XCTAssertTrue(urls[2].lastPathComponent.contains("03-03"))
        XCTAssertEqual(urls[0].pathExtension.lowercased(), "jpg")

        let firstData = try Data(contentsOf: urls[0])
        XCTAssertEqual(firstData.first, 0xFF)
        XCTAssertEqual(firstData.dropFirst().first, 0xD8)
    }

    func testShareImageIsWrittenAsJPEGFile() {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 8, y: 8, width: 16, height: 16))
        }

        guard let url = SutraCardRenderer.writeShareJPEG(image: image) else {
            XCTFail("Expected JPEG file URL")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension.lowercased(), "jpg")
        let data = try? Data(contentsOf: url)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.first, 0xFF)
        XCTAssertEqual(data?.dropFirst().first, 0xD8)
    }

    func testShareJPEGFileNameIsReadable() {
        let fileName = SutraCardRenderer.shareJPEGFileName(
            source: "《楞嚴經》",
            uniqueSuffix: "ABC123"
        )

        XCTAssertTrue(fileName.hasPrefix("楞嚴經-"))
        XCTAssertTrue(fileName == "楞嚴經-分享图-ABC123.jpg" || fileName == "楞嚴經-分享圖-ABC123.jpg")
        XCTAssertFalse(fileName.contains("lengyan-share"))
        XCTAssertFalse(fileName.contains("《"))
        XCTAssertFalse(fileName.contains("》"))
        XCTAssertFalse(fileName.range(of: #"\d{8}-\d{6}"#, options: .regularExpression) != nil)
    }

    func testShareTextIsWrittenAsReadableTextFile() {
        let text = "如是我聞\n一時佛在室羅筏城"

        guard let url = SutraCardRenderer.writeShareTextFile(text: text, source: "《楞嚴經》") else {
            XCTFail("Expected text file URL")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension.lowercased(), "txt")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("楞嚴經-"))
        XCTAssertFalse(url.lastPathComponent.lowercased().hasPrefix("text"))

        let savedText = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(savedText, text)
    }

    @MainActor
    func testShareLongImageRendersAndCompressesAsJPEG() {
        let text = String(repeating: "一切眾生從無始來，", count: 100)

        guard let plan = SutraCardRenderer.longCardRenderPlan(text: text, source: "《楞嚴經》") else {
            XCTFail("Expected render plan for medium long share text")
            return
        }
        XCTAssertEqual(plan.renderScale, 1.0)

        guard let image = SutraCardRenderer.renderLongCard(plan: plan),
              let cgImage = image.cgImage else {
            XCTFail("Expected rendered long share image")
            return
        }

        guard let url = SutraCardRenderer.writeShareJPEG(image: image) else {
            XCTFail("Expected JPEG file URL")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegData = try? Data(contentsOf: url)
        let rawBitmapBytes = cgImage.width * cgImage.height * 4
        XCTAssertNotNil(jpegData)
        XCTAssertLessThan(jpegData?.count ?? rawBitmapBytes, rawBitmapBytes / 2)
    }

    @MainActor
    func testShareLongImageStressMetricsForLongerText() throws {
        let counts = [120, 520, 1000, 1800, 2500, 3000, SutraCardRenderer.maxLongShareImageCharacterCount]
        var metrics: [String] = []

        for count in counts {
            let text = sutraText(characterCount: count)
            let plan = try XCTUnwrap(SutraCardRenderer.longCardRenderPlan(text: text, source: "《楞嚴經》"))
            XCTAssertLessThanOrEqual(plan.height, SutraCardRenderer.maxLongShareImageHeight)

            let expectedContentHeight = SutraCardRenderer.verseBlockHeight(text: text, base: plan.verseFontBase, width: plan.width)
                + SutraCardRenderer.compactPortraitChromeHeight(width: plan.width)
            if expectedContentHeight > plan.width * 0.72 {
                XCTAssertEqual(plan.height, expectedContentHeight, accuracy: 1.0)
            }

            guard let image = SutraCardRenderer.renderLongCard(plan: plan) else {
                let renderHeight = SutraCardRenderer.compactPortraitHeight(text: text, verseFontBase: plan.verseFontBase, width: plan.width)
                XCTFail("\(count) chars should render a nonblank share image; plan height \(plan.height), render height \(renderHeight), scale \(plan.renderScale)")
                continue
            }
            let cgImage = try XCTUnwrap(image.cgImage)
            let imageScale = CGFloat(cgImage.width) / plan.width
            XCTAssertEqual(imageScale, plan.renderScale, accuracy: 0.01)

            guard let insets = verticalDarkContentInsets(in: image, pointSize: CGSize(width: plan.width, height: plan.height)) else {
                XCTFail("\(count) chars should contain dark text pixels; image \(cgImage.width)x\(cgImage.height) px")
                continue
            }
            XCTAssertLessThanOrEqual(insets.top, 180, "\(count) chars should not start with a large blank area")
            XCTAssertLessThanOrEqual(insets.bottom, 220, "\(count) chars should not end with a large blank area")

            let url = try XCTUnwrap(SutraCardRenderer.writeShareJPEG(image: image, source: "《楞嚴經》"))
            let jpegData = try Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
            let rawBitmapBytes = cgImage.width * cgImage.height * 4
            XCTAssertLessThan(jpegData.count, rawBitmapBytes / 2)
            XCTAssertLessThan(jpegData.count, 15 * 1024 * 1024)

            metrics.append("\(count) chars: \(cgImage.width)x\(cgImage.height) px, scale \(String(format: "%.1f", imageScale)), \(String(format: "%.2f", Double(jpegData.count) / 1_048_576.0)) MB, top \(Int(insets.top))pt, bottom \(Int(insets.bottom))pt")
        }

        XCTContext.runActivity(named: "Long share metrics") { activity in
            let attachment = XCTAttachment(string: metrics.joined(separator: "\n"))
            attachment.name = "LONG_SHARE_METRICS"
            activity.add(attachment)
        }
    }

    @MainActor
    func testPureReaderKeepsVisibleCharacterWhenWidthChanges() throws {
        guard case .success = Book.shared.loadDataSyncWithCompletionHandler({ _ in }) else {
            XCTFail("Expected bundled corpus to load")
            return
        }
        let path = "/A2/B1/C2/D1/E3/F2/G2/H2/I2/J1/K3/L1"
        XCTAssertTrue(Book.shared.isValidReadingPath(path))

        let reader = SutraPurePageContentViewController()
        reader.path = path
        reader.loadViewIfNeeded()
        let window = host(reader, size: CGSize(width: 390, height: 800))
        defer { window.isHidden = true }

        let textView = try XCTUnwrap(reader.sutraView)
        let minimumY = -textView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            textView.contentSize.height
                - textView.bounds.height
                + textView.adjustedContentInset.bottom
        )
        XCTAssertGreaterThan(maximumY - minimumY, 200)
        textView.setContentOffset(
            CGPoint(x: 0, y: minimumY + min(240, (maximumY - minimumY) * 0.25)),
            animated: false
        )
        let characterBeforeResize = try XCTUnwrap(firstVisibleCharacter(in: textView))

        layout(reader, in: window, size: CGSize(width: 700, height: 650))

        let firstLineAfterResize = try XCTUnwrap(
            firstVisibleLineCharacterRange(in: textView)
        )
        XCTAssertTrue(
            NSLocationInRange(characterBeforeResize, firstLineAfterResize),
            "Width reflow should keep the previous anchor in the first visible line"
        )
    }

    @MainActor
    func testPagedReaderKeepsRowPositionWhenWidthChanges() throws {
        guard case .success = Book.shared.loadDataSyncWithCompletionHandler({ _ in }) else {
            XCTFail("Expected bundled corpus to load")
            return
        }
        let path = "/A2/B1/C2/D1/E3/F2/G2/H2/I2/J1/K3/L1"
        let pageIndex = try XCTUnwrap(
            Book.shared.index?.firstIndex(where: { $0["path"] == path })
        )

        let reader = SutraPageContentViewController()
        reader.pageIndex = pageIndex
        reader.loadViewIfNeeded()
        let window = host(reader, size: CGSize(width: 390, height: 800))
        defer { window.isHidden = true }

        let tableView = reader.tableView!
        let minimumY = -tableView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            tableView.contentSize.height
                - tableView.bounds.height
                + tableView.adjustedContentInset.bottom
        )
        XCTAssertGreaterThan(maximumY - minimumY, 200)
        tableView.setContentOffset(
            CGPoint(x: 0, y: minimumY + min(240, (maximumY - minimumY) * 0.2)),
            animated: false
        )
        let positionBeforeResize = try XCTUnwrap(visibleTablePosition(in: tableView))

        layout(reader, in: window, size: CGSize(width: 700, height: 650))

        let positionAfterResize = try XCTUnwrap(visibleTablePosition(in: tableView))
        XCTAssertEqual(positionAfterResize.row, positionBeforeResize.row)
        XCTAssertEqual(
            positionAfterResize.fraction,
            positionBeforeResize.fraction,
            accuracy: 0.03,
            "Width reflow should retain the same position within the visible paragraph"
        )
    }

    @MainActor
    func testPagedReaderCellHeightContainsEntireParagraph() throws {
        guard case .success = Book.shared.loadDataSyncWithCompletionHandler({ _ in }) else {
            XCTFail("Expected bundled corpus to load")
            return
        }
        let path = "/A2/B1/C2/D1/E3/F2/G2/H2/I2/J1/K3/L1"
        let pageIndex = try XCTUnwrap(
            Book.shared.index?.firstIndex(where: { $0["path"] == path })
        )

        let reader = SutraPageContentViewController()
        reader.pageIndex = pageIndex
        reader.loadViewIfNeeded()
        let window = host(reader, size: CGSize(width: 1_024, height: 1_366))
        defer { window.isHidden = true }

        let indexPath = IndexPath(row: 0, section: 0)
        reader.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        reader.tableView.layoutIfNeeded()
        let cell = try XCTUnwrap(
            reader.tableView.cellForRow(at: indexPath) as? SutraTableViewCell
        )
        cell.layoutIfNeeded()

        let textView = try XCTUnwrap(cell.textView)
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        let requiredTextHeight = ceil(
            textView.layoutManager.usedRect(for: textView.textContainer).height
                + textView.textContainerInset.top
                + textView.textContainerInset.bottom
        )
        XCTAssertGreaterThan(requiredTextHeight, 500)
        XCTAssertGreaterThanOrEqual(
            textView.bounds.height + 1,
            requiredTextHeight,
            "A self-sizing page row must not clip the final wrapped lines"
        )

        layout(reader, in: window, size: CGSize(width: 540, height: 1_024))
        reader.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        reader.tableView.layoutIfNeeded()
        let narrowedCell = try XCTUnwrap(
            reader.tableView.cellForRow(at: indexPath) as? SutraTableViewCell
        )
        narrowedCell.layoutIfNeeded()
        let narrowedTextView = try XCTUnwrap(narrowedCell.textView)
        narrowedTextView.layoutManager.ensureLayout(for: narrowedTextView.textContainer)
        let narrowedRequiredHeight = ceil(
            narrowedTextView.layoutManager.usedRect(for: narrowedTextView.textContainer).height
                + narrowedTextView.textContainerInset.top
                + narrowedTextView.textContainerInset.bottom
        )
        XCTAssertGreaterThan(
            narrowedRequiredHeight,
            requiredTextHeight,
            "Narrowing the reading column should increase the wrapped text height"
        )
        XCTAssertGreaterThanOrEqual(
            narrowedTextView.bounds.height + 1,
            narrowedRequiredHeight,
            "A page narrowed by iPad multitasking must grow instead of clipping its final lines"
        )
    }

    @MainActor
    func testPagedReaderCellMeasuresUsingFinalReadingWidth() throws {
        guard case .success = Book.shared.loadDataSyncWithCompletionHandler({ _ in }) else {
            XCTFail("Expected bundled corpus to load")
            return
        }
        let path = "/A2/B1/C2/D1/E3/F2/G2/H2/I2/J1/K3/L1"
        let content = try XCTUnwrap(Book.shared.contents?[path]?.first?["content"])
        XCTAssertGreaterThan(content.count, 1_000)

        let cell = SutraTableViewCell(style: .default, reuseIdentifier: nil)
        cell.configureWithZenStyle(content: content, type: "sutra")

        let targetWidth: CGFloat = 1_024
        let measuredSize = cell.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        cell.frame = CGRect(x: 0, y: 0, width: targetWidth, height: measuredSize.height)
        cell.setNeedsLayout()
        cell.layoutIfNeeded()

        let textView = try XCTUnwrap(cell.textView)
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        let requiredTextHeight = ceil(
            textView.layoutManager.usedRect(for: textView.textContainer).height
                + textView.textContainerInset.top
                + textView.textContainerInset.bottom
        )
        XCTAssertGreaterThan(requiredTextHeight, 500)
        XCTAssertGreaterThanOrEqual(
            measuredSize.height + 1,
            requiredTextHeight,
            "Initial self-sizing must use the final centered reading-column width"
        )
    }

    @MainActor
    func testChapterReaderPagesCoverEveryCharacterWithoutClipping() throws {
        let rawText = String(
            repeating: "如是我聞，一時佛在舍衛國祇樹給孤獨園。",
            count: 600
        )
        let attributedText = Book.shared.getSutraAttributeString(text: rawText)
        let reader = ReaderViewController(
            title: "卷一",
            content: attributedText,
            chapter: 0
        )
        let window = host(reader, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        let pages = descendantTextViews(in: reader.view).sorted {
            $0.frame.minX < $1.frame.minX
        }
        XCTAssertGreaterThan(pages.count, 2)

        var nextCharacterLocation = 0
        for textView in pages {
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            layoutManager.ensureLayout(for: textContainer)
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            XCTAssertEqual(
                characterRange.location,
                nextCharacterLocation,
                "Adjacent volume pages must not omit scripture characters"
            )
            nextCharacterLocation = NSMaxRange(characterRange)

            let usedRect = layoutManager.usedRect(for: textContainer)
            let availableWidth = textView.bounds.width
                - textView.textContainerInset.left
                - textView.textContainerInset.right
            let availableHeight = textView.bounds.height
                - textView.textContainerInset.top
                - textView.textContainerInset.bottom
            XCTAssertLessThanOrEqual(
                usedRect.maxX,
                availableWidth + 1,
                "A volume page must not draw its final columns outside the visible text area"
            )
            XCTAssertLessThanOrEqual(
                usedRect.maxY,
                availableHeight + 1,
                "A volume page must not draw its final line outside the visible text area"
            )
        }

        XCTAssertEqual(
            nextCharacterLocation,
            attributedText.length,
            "The final volume page must include the final scripture character"
        )
    }

    @MainActor
    private func host(_ controller: UIViewController, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        layout(controller, in: window, size: size)
        return window
    }

    @MainActor
    private func layout(
        _ controller: UIViewController,
        in window: UIWindow,
        size: CGSize
    ) {
        window.frame = CGRect(origin: .zero, size: size)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    @MainActor
    private func firstVisibleCharacter(in textView: UITextView) -> Int? {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        guard layoutManager.numberOfGlyphs > 0 else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let visibleTextY = textView.contentOffset.y
            + textView.adjustedContentInset.top
            - textView.textContainerInset.top
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: CGRect(
                x: 0,
                y: visibleTextY,
                width: max(textContainer.size.width, 1),
                height: max(textView.bounds.height, 1)
            ),
            in: textContainer
        )
        guard glyphRange.location != NSNotFound else { return nil }
        return layoutManager.characterIndexForGlyph(at: glyphRange.location)
    }

    @MainActor
    private func firstVisibleLineCharacterRange(in textView: UITextView) -> NSRange? {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        guard layoutManager.numberOfGlyphs > 0 else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let visibleTextY = textView.contentOffset.y
            + textView.adjustedContentInset.top
            - textView.textContainerInset.top
        let visibleGlyphs = layoutManager.glyphRange(
            forBoundingRect: CGRect(
                x: 0,
                y: visibleTextY,
                width: max(textContainer.size.width, 1),
                height: max(textView.bounds.height, 1)
            ),
            in: textContainer
        )
        guard visibleGlyphs.location != NSNotFound else { return nil }
        let glyph = min(visibleGlyphs.location, layoutManager.numberOfGlyphs - 1)
        var lineGlyphRange = NSRange()
        layoutManager.lineFragmentRect(
            forGlyphAt: glyph,
            effectiveRange: &lineGlyphRange
        )
        return layoutManager.characterRange(
            forGlyphRange: lineGlyphRange,
            actualGlyphRange: nil
        )
    }

    @MainActor
    private func visibleTablePosition(
        in tableView: UITableView
    ) -> (row: Int, fraction: CGFloat)? {
        let visibleY = tableView.contentOffset.y + tableView.adjustedContentInset.top
        let point = CGPoint(x: tableView.bounds.midX, y: visibleY + 1)
        guard let indexPath = tableView.indexPathForRow(at: point)
                ?? tableView.indexPathsForVisibleRows?.first else { return nil }
        let rowRect = tableView.rectForRow(at: indexPath)
        guard rowRect.height > 0 else { return (indexPath.row, 0) }
        return (
            indexPath.row,
            min(max((visibleY - rowRect.minY) / rowRect.height, 0), 1)
        )
    }

    @MainActor
    private func descendantTextViews(in view: UIView) -> [UITextView] {
        var result = view.subviews.compactMap { $0 as? UITextView }
        for subview in view.subviews {
            result.append(contentsOf: descendantTextViews(in: subview))
        }
        return result
    }

    private func sutraText(characterCount: Int) -> String {
        let seed = "一切眾生從無始來，生死相續，皆由不知常住真心，性淨明體，用諸妄想，此想不真，故有輪轉。"
        var text = ""
        while text.count < characterCount {
            text += seed
        }
        return String(text.prefix(characterCount))
    }

    private func verticalDarkContentInsets(in image: UIImage, pointSize: CGSize) -> (top: CGFloat, bottom: CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }

        let sampleWidth = 96
        let sampleHeight = max(1, Int(ceil(pointSize.height)))
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        func rowHasDarkContent(_ row: Int) -> Bool {
            let rowStart = row * sampleWidth * 4
            for column in 0..<sampleWidth {
                let offset = rowStart + column * 4
                let alpha = pixels[offset + 3]
                guard alpha > 24 else { continue }

                let red = Double(pixels[offset])
                let green = Double(pixels[offset + 1])
                let blue = Double(pixels[offset + 2])
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                if luminance < 175 {
                    return true
                }
            }
            return false
        }

        guard let topRow = (0..<sampleHeight).first(where: rowHasDarkContent),
              let bottomRow = (0..<sampleHeight).reversed().first(where: rowHasDarkContent) else {
            return nil
        }

        return (CGFloat(topRow), CGFloat(sampleHeight - 1 - bottomRow))
    }
}

private func bundledBookResourceData(
    _ resourceName: String,
    _ fileExtension: String
) -> Foundation.Data? {
    guard let url = Bundle.main.url(
        forResource: resourceName,
        withExtension: fileExtension
    ) else { return nil }
    return try? Foundation.Data(contentsOf: url)
}
