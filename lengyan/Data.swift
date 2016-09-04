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
    
    func like(_ path:String)
    func unlike(_ path:String)
}

class Data: NSObject, DataProtocal {
    static let shared = Data()
    var defaults:UserDefaults
    
    static let LastExpandedKey = "lastExpanded";
    static let likesKey = "likes";
    internal var likesCache:[String]?;
    
    override init(){
        self.defaults = UserDefaults.standard
        if (likesCache == nil){
            likesCache =  defaults.stringArray(forKey: Data.likesKey) ?? [];
            print("likes:")
            print(likesCache)
        }
    }
    
    var lastExpanded:[String]{
        get {
            print(defaults.stringArray(forKey: Data.LastExpandedKey))

            return defaults.stringArray(forKey: Data.LastExpandedKey) ?? [];
        }
        
        set (expanded){
            print(expanded)
            defaults.set(expanded, forKey: Data.LastExpandedKey)
            defaults.synchronize()
        }
    }
    
    var likes:[String]{
        get {
            return likesCache!
        }
    }
    
    func like(_ path:String){
        likesCache?.append(path)
        defaults.set(likesCache, forKey: Data.likesKey)
    }
    
    func unlike(_ path:String){
        let index = likesCache?.index(of: path);
        if (index != nil){
            likesCache?.remove(at: index!);
        }
//        let likes = NSMutableSet(array: self.likes);
//        likes.removeObject(path);
//        defaults.setObject(likes.allObjects, forKey: Data.likesKey)
    }
    
    func isLike(_ path:String) -> Bool{
        return likesCache?.contains(path) ?? false
    }
    
    func persist(){
        defaults.synchronize()
    }

}
