//
//  Macros.swift
//  lengyan
//
//  Created by Xuan on 16/8/3.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation

var startTime = NSDate()

func TICK(){ startTime =  NSDate() }

func TOCK(function: String = #function, file: String = #file, line: Int = #line){
    print("\(function) Time: \(-startTime.timeIntervalSinceNow)\nLine:\(line) File: \(file)")
}