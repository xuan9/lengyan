//
//  WidgetDataSyncTests.swift
//  lengyanTests
//
//  Created by Xuan on 26/6/7.
//  Copyright © 2026年 xuan. All rights reserved.
//

import XCTest
@testable import lengyan

class WidgetDataSyncTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure book data is loaded for testing DailyVerseProvider
        let expectation = self.expectation(description: "Book data loaded")
        Book.shared.loadDataWithCompletionHandler { result in
            guard case .success = result else {
                XCTFail("Expected bundled corpus to load: \(result)")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSharedVerseDataEncodingDecoding() {
        let testData = SharedVerseData(
            text: "一切众生从无始来",
            fullText: "一切众生从无始来，生死相续，皆由不知常住真心性净明体，用诸妄想，此想不真，故有轮转。",
            source: "卷一 · 七处征心",
            path: "/A2/B1/C2/D1/E2/F1/G1/H1/I1/J2",
            dateString: "2026-06-07",
            theme: "sepia"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode([testData])
            let decoded = try decoder.decode([SharedVerseData].self, from: data)
            XCTAssertEqual(decoded.count, 1)
            XCTAssertEqual(decoded[0].text, testData.text)
            XCTAssertEqual(decoded[0].fullText, testData.fullText)
            XCTAssertEqual(decoded[0].source, testData.source)
            XCTAssertEqual(decoded[0].path, testData.path)
            XCTAssertEqual(decoded[0].dateString, testData.dateString)
            XCTAssertEqual(decoded[0].theme, testData.theme)
        } catch {
            XCTFail("Encoding or decoding failed: \(error)")
        }
    }
    
    func testDailyVerseProviderGeneratesValidData() {
        let provider = DailyVerseProvider.shared
        
        guard let verse = provider.todayVerse() else {
            XCTFail("DailyVerseProvider failed to generate today's verse")
            return
        }
        
        XCTAssertFalse(verse.text.isEmpty, "Short verse text should not be empty")
        XCTAssertFalse(verse.fullText.isEmpty, "Full text should not be empty")
        XCTAssertFalse(verse.source.isEmpty, "Source attribution should not be empty")
        XCTAssertFalse(verse.path.isEmpty, "Sutra path should not be empty")
        
        // Check that text is shorter than or equal to 55 characters
        XCTAssertLessThanOrEqual(verse.text.count, 55, "Short verse should be 55 characters or less")
        
        // Check semantic truncation characteristics
        if verse.text.count < verse.fullText.count {
            // If truncated, it should end with ellipsis "..." or a clean sentence finisher
            let isCleanFinisher = ["。", "！", "？", "!", "?"].contains { verse.text.hasSuffix($0) }
            XCTAssertTrue(verse.text.hasSuffix("...") || isCleanFinisher, "Truncated short verse should end with ellipsis or clean finisher")
            XCTAssertFalse(verse.text.hasSuffix("，"), "Truncated short verse should not end with a comma")
            XCTAssertFalse(verse.text.hasSuffix("、"), "Truncated short verse should not end with an enumeration comma")
        } else {
            // If not truncated, it should end with a clean sentence finisher
            let endings = ["。", "！", "？", "!", "?", "..."]
            let endsCorrectly = endings.contains { verse.text.hasSuffix($0) }
            XCTAssertTrue(endsCorrectly || verse.text.count < 10, "Non-truncated verse should end with a clean finisher or be very short")
        }
    }
    
    func testWidgetDataSyncWriteAndRead() {
        let provider = DailyVerseProvider.shared
        
        // Execute sync
        provider.syncWidgetData()
        
        // Read back today's synced data
        let today = Date()
        let loadedData = SharedVerseData.load(for: today)
        
        XCTAssertNotNil(loadedData, "Synced widget data should be readable from the App Group suite")
        
        if let data = loadedData {
            XCTAssertFalse(data.text.isEmpty)
            XCTAssertNotNil(data.fullText)
            XCTAssertFalse(data.source.isEmpty)
            XCTAssertFalse(data.path.isEmpty)
            XCTAssertEqual(data.theme, SutraDesignTokens.shared.currentTheme.rawValue)
        }
    }

    func testWidgetDataSyncProvidesSixtyDayOfflineHorizon() {
        let provider = DailyVerseProvider.shared
        provider.syncWidgetData()

        let verses = SharedVerseData.loadAll()

        XCTAssertEqual(verses.count, DailyVerseProvider.widgetScheduleDays)
        XCTAssertEqual(Set(verses.map(\.dateString)).count, DailyVerseProvider.widgetScheduleDays)

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = verses.compactMap { formatter.date(from: $0.dateString) }
        XCTAssertEqual(dates.count, DailyVerseProvider.widgetScheduleDays)
        for (current, next) in zip(dates, dates.dropFirst()) {
            XCTAssertEqual(calendar.dateComponents([.day], from: current, to: next).day, 1)
        }
    }

    func testRepeatedWidgetDataSyncSkipsUnchangedWriteAndRefresh() throws {
        guard let defaults = UserDefaults(suiteName: SharedVerseData.appGroupID) else {
            XCTFail("Expected Widget App Group defaults to be available")
            return
        }

        let sharedProvider = DailyVerseProvider.shared
        // The test host also performs its normal asynchronous launch sync.
        // Drain that serial queue before creating a controlled empty state.
        _ = sharedProvider.syncWidgetData()

        var reloadCount = 0
        let scheduleSuiteName = "WidgetDataSyncTests.DailyVerse.\(UUID().uuidString)"
        let scheduleDefaults = try XCTUnwrap(UserDefaults(suiteName: scheduleSuiteName))
        let provider = DailyVerseProvider(
            widgetTimelineReloader: { reloadCount += 1 },
            userDefaults: scheduleDefaults
        )

        let originalData = defaults.data(forKey: SharedVerseData.defaultsKey)
        defer {
            scheduleDefaults.removePersistentDomain(forName: scheduleSuiteName)
            if let originalData {
                defaults.set(originalData, forKey: SharedVerseData.defaultsKey)
            } else {
                defaults.removeObject(forKey: SharedVerseData.defaultsKey)
            }
        }

        defaults.removeObject(forKey: SharedVerseData.defaultsKey)

        XCTAssertTrue(provider.syncWidgetData(), "The first sync should write and request one refresh")
        XCTAssertEqual(reloadCount, 1)
        let firstPayload = defaults.data(forKey: SharedVerseData.defaultsKey)
        XCTAssertNotNil(firstPayload)

        XCTAssertFalse(provider.syncWidgetData(), "An identical sync must not request another refresh")
        XCTAssertEqual(reloadCount, 1)
        XCTAssertEqual(defaults.data(forKey: SharedVerseData.defaultsKey), firstPayload)
    }
}

final class WidgetGuidePlatformTests: XCTestCase {
    func testLockScreenWidgetAvailabilityMatchesPhoneAndPadIntroductions() {
        XCTAssertFalse(WidgetGuidePlatform.supportsLockScreenWidget(
            systemMajorVersion: 15,
            isPad: false
        ))
        XCTAssertTrue(WidgetGuidePlatform.supportsLockScreenWidget(
            systemMajorVersion: 16,
            isPad: false
        ))
        XCTAssertFalse(WidgetGuidePlatform.supportsLockScreenWidget(
            systemMajorVersion: 16,
            isPad: true
        ))
        XCTAssertTrue(WidgetGuidePlatform.supportsLockScreenWidget(
            systemMajorVersion: 17,
            isPad: true
        ))
    }

    func testWidgetGuideStartsWithTheMostUsefulMissingPlacement() {
        XCTAssertEqual(
            WidgetGuidePlatform.preferredPlacement(
                installation: nil,
                supportsLockScreen: true
            ),
            .lockScreen
        )
        XCTAssertEqual(
            WidgetGuidePlatform.preferredPlacement(
                installation: WidgetInstallationState(
                    hasStandardFamily: false,
                    hasLockScreenAccessory: true
                ),
                supportsLockScreen: true
            ),
            .homeScreen
        )
        XCTAssertEqual(
            WidgetGuidePlatform.preferredPlacement(
                installation: .empty,
                supportsLockScreen: false
            ),
            .homeScreen
        )
    }

    func testStandardFamilyDetectionStillRecommendsTheRectangularAccessory() {
        let standardFamilyOnly = WidgetInstallationState(
            hasStandardFamily: true,
            hasLockScreenAccessory: false
        )
        XCTAssertTrue(standardFamilyOnly.isInstalled)
        XCTAssertEqual(
            WidgetGuidePlatform.preferredPlacement(
                installation: standardFamilyOnly,
                supportsLockScreen: true
            ),
            .lockScreen
        )

        let bothFamilies = WidgetInstallationState(
            hasStandardFamily: true,
            hasLockScreenAccessory: true
        )
        XCTAssertTrue(bothFamilies.isInstalled)
        XCTAssertEqual(
            WidgetGuidePlatform.preferredPlacement(
                installation: bothFamilies,
                supportsLockScreen: true
            ),
            .lockScreen
        )
    }
}
