//
//  lengyanTests.swift
//  lengyanTests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import XCTest
import UIKit
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
        Book.shared.loadDataWithCompletionHandler { () in
            XCTAssertNotNil(Book.shared.tree)
            XCTAssertNotNil(Book.shared.index)
            XCTAssertNotNil(Book.shared.contents)
            XCTAssertNotNil(Book.shared.media)
            
            XCTAssertEqual(Book.shared.tree!["path"] as! String, "")
            XCTAssertEqual(Book.shared.index![0]["path"], "")
            XCTAssertEqual(Book.shared.contents!["/A1/B1/C1"]![0]["type"], "sutra")
            XCTAssertEqual(Book.shared.media![0]["extension"] as! String, "m4a")
        }
    }
    
    func testPaging(){
        Book.shared.loadDataWithCompletionHandler { () in
            XCTAssertEqual(Book.shared.getPreviousPagePath("/A2/B1/C2/D1/E2/F1/G1/H2/I1"), "/A2/B1/C2/D1/E2/F1/G1/H1/I3")
            XCTAssertEqual(Book.shared.getPreviousPagePath("/A2/B1/C2/D1/E2/F1/G1/H2/I1/J1"), "/A2/B1/C2/D1/E2/F1/G1/H1/I3")
            XCTAssertEqual(Book.shared.getNextPagePath("/A2/B1/C2/D1/E2/F1/G1/H1/I3"), "/A2/B1/C2/D1/E2/F1/G1/H2/I1" )
            XCTAssertEqual(Book.shared.getBelongingKeyPagePath("/A2/B1/C2/D1/E2/F1/G1/H1/I3/J2"), "/A2/B1/C2/D1/E2/F1/G1/H1/I3")
        }
    }
    
    func testAudioSeekMethod() {
        let observer = AudioPlayerObserver.shared
        observer.initializePlayerIfNeeded()
        observer.seek(to: 125.0)
        XCTAssertEqual(observer.currentTime, 125.0)
        observer.cleanup()
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
    
    func testAudioManagerTrackSwitching() {
        let manager = AudioManager.shared
        let observer = AudioPlayerObserver.shared
        
        // Mock media groups and download status
        let group = MediaGroup(name: "Test Group", files: ["file1", "file2", "file3"], names: ["Track 1", "Track 2", "Track 3"], fileExtension: "mp3")
        manager.mediaGroups = [group]
        manager.downloadStatus["file1"] = .downloaded
        manager.downloadStatus["file2"] = .downloaded
        manager.downloadStatus["file3"] = .downloaded
        
        observer.initializePlayerIfNeeded()
        observer.currentTrack = "Track 1"
        observer.lastPlayFile = ("Track 1", "file1", "mp3")
        
        // Test playNextTrack
        manager.playNextTrack()
        observer.lastPlayFile = ("Track 2", "file2", "mp3")
        XCTAssertEqual(observer.currentTrack, "Track 2")
        
        // Test playPreviousTrack
        manager.playPreviousTrack()
        observer.lastPlayFile = ("Track 1", "file1", "mp3")
        XCTAssertEqual(observer.currentTrack, "Track 1")
        
        // Test playPreviousTrack wrap-around
        manager.playPreviousTrack()
        observer.lastPlayFile = ("Track 3", "file3", "mp3")
        XCTAssertEqual(observer.currentTrack, "Track 3")
        
        observer.cleanup()
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
