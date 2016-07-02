//
//  Data.swift
//  lengyan
//
//  Created by Xuan on 16/6/26.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

protocol DataProtocal {
    var lastExpanded:[String]{get set}
    var likes:[String]{get}
    
    func like(path:String)
    func unlike(path:String)
}

class Data: NSObject, DataProtocal {
    static let shared = Data()
    var defaults:NSUserDefaults
    
    static let LastExpandedKey = "lastExpanded";
    static let likesKey = "likes";

    
    override init(){
        self.defaults = NSUserDefaults.standardUserDefaults()
    }
    
    var lastExpanded:[String]{
        get {
            print(defaults.stringArrayForKey(Data.LastExpandedKey))

            return defaults.stringArrayForKey(Data.LastExpandedKey) ?? [];
        }
        
        set (expanded){
            print(expanded)
            defaults.setObject(expanded, forKey: Data.LastExpandedKey)
            defaults.synchronize()
        }
    }
    
    var likes:[String]{
        get {
            return defaults.stringArrayForKey(Data.likesKey) ?? [];
        }
    }
    
    func like(path:String){
        let likes = NSMutableArray(array: self.likes);
        likes.addObject(path);
        defaults.setObject(likes, forKey: Data.likesKey)
    }
    
    func unlike(path:String){
        let likes = NSMutableArray(array: self.likes);
        likes.addObject(path);
        defaults.setObject(likes, forKey: Data.likesKey)
    }

}
