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

}
