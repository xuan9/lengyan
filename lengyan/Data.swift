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
    internal var likesCache:[String]?;
    
    override init(){
        self.defaults = NSUserDefaults.standardUserDefaults()
        if (likesCache == nil){
            likesCache =  defaults.stringArrayForKey(Data.likesKey) ?? [];
            print("likes:")
            print(likesCache)
        }
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
            return likesCache!
        }
    }
    
    func like(path:String){
        likesCache?.append(path)
        defaults.setObject(likesCache, forKey: Data.likesKey)
    }
    
    func unlike(path:String){
        let index = likesCache?.indexOf(path);
        if (index == nil){
            likesCache?.removeAtIndex(index!);
        }
//        let likes = NSMutableSet(array: self.likes);
//        likes.removeObject(path);
//        defaults.setObject(likes.allObjects, forKey: Data.likesKey)
    }
    
    func isLike(path:String) -> Bool{
        return likesCache?.contains(path) ?? false
    }
    
    func persist(){
        defaults.synchronize()
    }

}
