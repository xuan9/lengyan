//
//  lengyanUITests.swift
//  lengyanUITests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import XCTest

class lengyanUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testChapterReading() {
        let app = XCUIApplication()
        app.tables.buttons["卷一"].tap()
        
        let textView = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .textView).element
        textView.swipeLeft()
        textView.swipeUp()
        textView.swipeDown()
        textView.swipeLeft()
        textView.swipeRight()
        textView.tap()
        textView.swipeDown()
        app.navigationBars["卷二"].buttons[" ❬  "].tap()
    }
    
    func testIndexReading() {
        let app = XCUIApplication()
        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["序分  卷一起"]/*[[".cells.staticTexts[\"序分  卷一起\"]",".staticTexts[\"序分  卷一起\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.navigationBars["大佛顶如来密因修证了义诸菩萨万行首楞严经 之 序分"].buttons["ic view list 18pt"].tap()
        let staticText = tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["广列听众"]/*[[".cells.staticTexts[\"广列听众\"]",".staticTexts[\"广列听众\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        staticText.tap()
        staticText.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["王臣设供"]/*[[".cells.staticTexts[\"王臣设供\"]",".staticTexts[\"王臣设供\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
    }
    
}
