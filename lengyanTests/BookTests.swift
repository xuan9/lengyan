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
            String(repeating: "一", count: count)
        }

        func renderScale(for count: Int) -> CGFloat? {
            let text = repeatedSutraText(count: count)
            let base = SutraCardRenderer.verseFontBase(forCharCount: text.count)
            let height = SutraCardRenderer.compactPortraitHeight(text: text, verseFontBase: base)
            return SutraCardRenderer.longImageRenderScale(characterCount: text.count, targetHeight: height)
        }

        let shortText = repeatedSutraText(count: 480)
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

        let maxText = repeatedSutraText(count: SutraCardRenderer.maxLongShareImageCharacterCount)
        let maxBase = SutraCardRenderer.verseFontBase(forCharCount: maxText.count)
        let maxHeight = SutraCardRenderer.compactPortraitHeight(text: maxText, verseFontBase: maxBase)
        XCTAssertLessThanOrEqual(maxHeight, SutraCardRenderer.maxLongShareImageHeight)
        XCTAssertEqual(renderScale(for: maxText.count), 1.0)

        XCTAssertNil(renderScale(for: SutraCardRenderer.maxLongShareImageCharacterCount + 1))
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
}
