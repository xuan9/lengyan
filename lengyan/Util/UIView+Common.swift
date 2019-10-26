//
//  Extensions.swift
//  lengyan
//
//  Created by Xuan on 2017/8/13.
//  Copyright © 2017年 xuan. All rights reserved.
//

import Foundation

extension UIView {
    
    /// Adds constraints to this `UIView` instances `superview` object to make sure this always has the same size as the superview.
    /// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
    func bindFrameToSuperviewBounds(paddingHorizontal:Int,paddingVertical:Int) {
        guard let superview = self.superview else {
            print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
            return
        }
        
        self.translatesAutoresizingMaskIntoConstraints = false
        superview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(paddingHorizontal)-[subview]-\(paddingHorizontal)-|", options: .directionLeadingToTrailing, metrics: nil, views: ["subview": self]))
        superview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(paddingVertical)-[subview]-\(paddingVertical)-|", options: .directionLeadingToTrailing, metrics: nil, views: ["subview": self]))
    }
}
