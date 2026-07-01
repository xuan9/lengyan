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

// MARK: - Debug Logging
// 模块内 print 的 DEBUG 开关：Release 构建下所有 print 静默（no-op），
// 避免调试日志（含 VC 栈结构、内部状态）泄露到生产设备日志。
// 本模块（lengyan target）内的代码调用 print 时会优先命中此定义。
@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    Swift.print(items, separator: separator, terminator: terminator)
    #endif
}

@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    NSLog("%@", message())
    #endif
}
