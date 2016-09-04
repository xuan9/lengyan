//
//  Macros.swift
//  lengyan
//
//  Created by Xuan on 16/8/3.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation

var startTime = Date()

func TICK(){ startTime =  Date() }

func TOCK(_ function: String = #function, file: String = #file, line: Int = #line){
    print("\(function) Time: \(-startTime.timeIntervalSinceNow)\nLine:\(line) File: \(file)")
}
