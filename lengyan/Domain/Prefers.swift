//
//  Data.swift
//  lengyan
//
//  Created by Xuan on 16/6/26.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

protocol PrefersProtocol {
    var likes:[String]{get}
    var lastPlayFile:[String]?{get set}
    var lastPlayMode:Int?{get set}
    
    func like(_ path:String)
    func unlike(_ path:String)
    
    func persist()
}

class Prefers: NSObject, PrefersProtocol {
    internal var defaults:UserDefaults
    internal var likesCache:[String]?;

    internal static let likesKey = "likes";
    internal static let playFileKey = "playFile"
    internal static let playModeKey = "playMode"
    
    static let shared = Prefers()
    
    override init(){
        self.defaults = UserDefaults.standard
        if (likesCache == nil){
            likesCache =  defaults.stringArray(forKey: Prefers.likesKey) ?? DEFAULT_STARTS;
        }
    }
    
    var likes:[String]{
        get {
            return likesCache!
        }
    }
    
    func like(_ path:String){
        likesCache?.insert(path, at: 0);
        defaults.set(likesCache, forKey: Prefers.likesKey)
    }
    
    func unlike(_ path:String){
        let index = likesCache?.index(of: path);
        if (index != nil){
            likesCache?.remove(at: index!);
        }
    }
    
    func isLike(_ path:String) -> Bool{
        return likesCache?.contains(path) ?? false
    }
    
    var lastPlayFile:[String]?{
        get {
            return defaults.array(forKey: Prefers.playFileKey) as! [String]?
        }
        set(file) {
            defaults.set(file, forKey: Prefers.playFileKey)
        }
    }
    
    var lastPlayMode:Int?{
        get {
            return defaults.integer(forKey: Prefers.playModeKey)
        }
        set(mode) {
            defaults.set(mode, forKey: Prefers.playModeKey)
        }   
    }
    
    func persist(){
        defaults.synchronize()
    }
}
