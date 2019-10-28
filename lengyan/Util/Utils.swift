//
//  Utils.swift
//  lengyan
//
//  Created by Xuan on 16/7/10.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation

var startTime = Date()

func TICK(){ startTime =  Date() }

func TOCK(_ function: String = #function, file: String = #file, line: Int = #line){
    print("\(function) Time: \(-startTime.timeIntervalSinceNow)\nLine:\(line) File: \(file)")
}
