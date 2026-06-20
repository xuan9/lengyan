//
//  SutraSnapshotTests.swift
//  lengyanUITests
//
//  App Store 截图自动化（配合 fastlane snapshot 使用）
//  运行：fastlane snapshot
//

import XCTest

@MainActor
class SutraSnapshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        // 注意：必须用 += 追加，不能覆盖（setupSnapshot 已设置 -AppleLanguages 等）
        app.launchArguments += ["--uitesting", "--snapshot-mode"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 一份完整截图序列：首页 / 听经 / 收藏 / 设置 / 经文阅读
    /// zh-Hans + zh-Hant 各 5 张，满足 App Store Connect 3-10 张要求
    func testAppStoreScreenshots() throws {
        // 等待首屏稳定
        Thread.sleep(forTimeInterval: 1.5)

        // 01 - 首页（阅读 Tab）
        snapshot("01_Home")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "TabBar should be present")

        // 02 - 听经 Tab
        let listeningTab = tabBar.buttons.element(boundBy: 1)
        if listeningTab.exists {
            listeningTab.tap()
            Thread.sleep(forTimeInterval: 1.8)
            snapshot("02_Listening")
        }

        // 03 - 收藏 Tab（切到「精选」子标签，避免空白）
        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        if favoritesTab.exists {
            favoritesTab.tap()
            Thread.sleep(forTimeInterval: 1.5)

            // 收藏页默认是「我的收藏」（新用户为空），点击「精选」展示编者精选内容
            // 「先看看精选 →」按钮出现在空状态；或顶部的「精选」segmented 按钮
            let curatedEntryCandidates = ["先看看精选 →", "先看看精选", "精选"]
            var didSwitchToCurated = false
            for label in curatedEntryCandidates {
                let btn = app.buttons[label]
                if btn.exists {
                    btn.tap()
                    Thread.sleep(forTimeInterval: 1.8)  // 等精选数据加载
                    didSwitchToCurated = true
                    break
                }
            }
            _ = didSwitchToCurated  // 即使没切成功也截图（兜底）

            snapshot("03_Favorites")
        }

        // 04 - 设置 Tab
        let settingsTab = tabBar.buttons.element(boundBy: 3)
        if settingsTab.exists {
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1.5)
            snapshot("04_Settings")
        }

        // 05 - 经文阅读（回到首页，进入卷一）
        let readingTab = tabBar.buttons.element(boundBy: 0)
        if readingTab.exists {
            readingTab.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // 尝试点入卷一/卷按钮
            let chapterCandidates = ["卷一", "卷1", "卷 一"]
            var didEnter = false
            for name in chapterCandidates {
                let btn = app.buttons[name]
                if btn.exists {
                    btn.tap()
                    Thread.sleep(forTimeInterval: 2.0)
                    didEnter = true
                    break
                }
            }
            if didEnter {
                snapshot("05_Reading")
            } else {
                // 兜底：再截一张首页精装版
                snapshot("05_HomeAlt")
            }
        }
    }
}
