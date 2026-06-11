//
//  String+Common.swift
//  lengyan
//
//  Created by Xuan on 16/6/27.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation

extension String
{
    
    func lastIndexOf(_ s: String) -> Int? {
        if let r: Range<Index> = self.range(of: s, options: .backwards) {
            return self.distance(from: self.startIndex, to: r.lowerBound)
        }
        
        return nil;
    }

    var simplified: String {
        return self.applyingTransform(StringTransform("Hans-Hant"), reverse: true) ?? self
    }

    var traditional: String {
        return self.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? self
    }

}
