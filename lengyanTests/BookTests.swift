//
//  lengyanTests.swift
//  lengyanTests
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import XCTest
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
    
}
