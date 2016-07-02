//
//  Book.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class Book: NSObject {
    static let data:Book = Book()
    
    var tree:[String:AnyObject]? = nil
    var contents:[String:[[String:String]]]? = nil
    var index:[[String:String]]? = nil
    
    func itemOfPath(path:String) -> [String:AnyObject] {
        if path == "" || path == "/" {
            return self.tree!
        }
        var node = tree;
        for id in path.componentsSeparatedByString("/") {
            if(id==""){continue}
            let children = node!["children"] as! NSArray as! [[String:AnyObject]]
            node = children.filter({
                $0["id"] as! String == id
            }).first
        }
        return node!;
    }
    
    func parentOfItem(item:[String:AnyObject]) -> [String:AnyObject]? {
        var path = item["path"] as! String
        if path == "" || path == "/" {
            return nil;
        } else {
            path = (path as NSString).substringToIndex(path.lastIndexOf("/")!)
        }
        return self.itemOfPath(path)
    }

    func loadDataWithCompletionHandler(handler:Void->Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let treeFileURL = NSBundle.mainBundle().URLForResource("data/lengyanjing-index-tree", withExtension: "json")
            
            let data = NSData(contentsOfURL: treeFileURL!);
            do {
                self.tree = try (NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)) as? NSDictionary as? [String: AnyObject]
            } catch _ {
                self.tree = [:];
            }
            

//            
            
            let contentFile = NSBundle.mainBundle().URLForResource("data/lengyanjing-content", withExtension: "json")
            
            let contentData = NSData(contentsOfURL: contentFile!);
            do {
                self.contents = try (NSJSONSerialization.JSONObjectWithData(contentData!, options: .AllowFragments)) as? NSDictionary
                    as? [String:[[String:String]]]
            } catch _ {
                self.contents  = [:]
            }
            
            
            let indexFile = NSBundle.mainBundle().URLForResource("data/lengyanjing-index", withExtension: "json")
            
            let indexData = NSData(contentsOfURL: indexFile!);
            do {
                let indexArray = try (NSJSONSerialization.JSONObjectWithData(indexData!, options: .AllowFragments)) as? NSArray
                //--check if any wront type item
//                print( indexArray?.filter({ (a) -> Bool in
//                    let d = a as? [String:String]
//                    if d == nil {
//                        print(( a as? NSDictionary)!["path"])
//                        return false;
//                    }
//                    return true;
//                }).count)
               self.index = indexArray as? [[String:String]]
            } catch _ {
                self.index = []
            }
            handler();
        }
        
    }
}
