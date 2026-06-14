//
//  lengyanTests.swift
//  lengyanTests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import XCTest
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
}
