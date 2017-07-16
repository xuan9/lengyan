//
//  Data.swift
//  lengyan
//
//  Created by Xuan on 16/6/26.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

let default_stars =
    [
        "/A2/B1/C2/D1/E2/F1/G1/H1/I1/J2",
        "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K2/L2/M2/N2",
        "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K2/L2/M3/N3",
        "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K3/L2/M4",
        "/A2/B1/C2/D1/E2/F1/G1/H1/I3",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M10/N4/O1",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M10/N4/O2",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M2/N2/O2",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M2/N3/O1",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M2/N4/O3",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2/M3/N1/O1",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2/M3/N1/O3/P2/Q1/R1",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2/M3/N1/O3/P2/Q1/R2/S1",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2/M3/N1/O3/P2/Q1/R2/S2",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2/M3/N1/O3/P2/Q1/R3/S1",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2/M3/N1/O3/P2/Q1/R3/S2",
        "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K3/L2/M3/N7/O5",
        "/A2/B1/C2/D1/E2/F2/G2/H2/I1/J1",
        "/A2/B1/C2/D1/E2/F2/G2/H2/I1/J2",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K1/L1",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2/L1/M3",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2/L2/M2/N4",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2/L2/M2/N5/O1/P1",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2/L2/M2/N5/O1/P2",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2/L2/M2/N5/O2/P1/Q1",
        "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2/L2/M2/N5/O2/P2/Q1",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I1/J2/K4/L1",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I1/J2/K4/L2",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I2/J2/K1/L1/M3",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I2/J2/K1/L2/M2",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I2/J2/K2/L2/M1",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I2/J2/K2/L2/M2/N1",
        "/A2/B1/C2/D1/E3/F1/G2/H2/I2/J2/K2/L2/M2/N2",
        "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K2/L2",
        "/A2/B1/C2/D1/E3/F1/G2/H4/I4",
        "/A2/B1/C2/D1/E3/F2/G1/H2/I2",
        "/A2/B1/C2/D1/E3/F2/G2/H2/I2/J1/K3/L1",
        "/A2/B1/C2/D1/E4/F2/G4",
        "/A2/B2/C1/D2/E2/F1",
        "/A2/B2/C1/D2/E2/F2/G1",
        "/A2/B2/C1/D2/E2/F2/G1/H2/I1",
        "/A2/B2/C1/D2/E2/F2/G1/H2/I2",
        "/A2/B2/C1/D2/E2/F2/G1/H2/I4",
        "/A2/B2/C1/D2/E2/F2/G4",
        "/A2/B2/C1/D2/E3",
        "/A2/B2/C2/D1/E3/F1",
        "/A2/B2/C2/D1/E3/F3",
        "/A2/B2/C2/D2/E2/F1/G1",
        "/A2/B2/C2/D2/E2/F1/G2" ];

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
    static let playFileKey = "playFile"
    static let playModeKey = "playMode"
    internal var likesCache:[String]?;
    
//    internal var itemOpened:String?;
//    internal var itemOpenedAt:Date;
    
    override init(){
        
        self.defaults = UserDefaults.standard
        if (likesCache == nil){
            likesCache =  defaults.stringArray(forKey: Data.likesKey) ?? default_stars;
            
            if likesCache?.count == 0 {
                
            }
            print("likes: \(likesCache)")
        }
    }
    
    var lastExpanded:[String]{
        get {
            print(defaults.stringArray(forKey: Data.LastExpandedKey) ?? "")

            return defaults.stringArray(forKey: Data.LastExpandedKey) ?? [];
        }
        
        set (expanded){
            print(expanded)
            defaults.set(expanded, forKey: Data.LastExpandedKey)
        }
    }
    
    var likes:[String]{
        get {
            return likesCache!
        }
    }
    
    
    func like(_ path:String){
        likesCache?.insert(path, at: 0);
        defaults.set(likesCache, forKey: Data.likesKey)
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
            return defaults.array(forKey: Data.playFileKey) as! [String]?
        }
        set(file) {
            defaults.set(file, forKey: Data.playFileKey)
        }
        
    }
    
    var lastPlayMode:Int?{
        get {
            return defaults.integer(forKey: Data.playModeKey)
        }
        set(mode) {
            defaults.set(mode, forKey: Data.playModeKey)
        }
        
    }
    
//    func logItemOpened(path:String){
//    }
//    
//    func logItemClosed(path:String){
//    }
    
    func persist(){
        defaults.synchronize()
    }
}
