//
//  Book.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

let KEY_PATHS = [
    "/A2/B1",
    "/A2/B1/C2/D1/E2",
    "/A2/B1/C2/D1/E2/F1",
    "/A2/B1/C2/D1/E2/F1/G1/H1",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K1",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K2",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K3",
    "/A2/B1/C2/D1/E2/F1/G1/H2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M3",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M4",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K3",
    "/A2/B1/C2/D1/E2/F1/G2",
    "/A2/B1/C2/D1/E2/F2",
    "/A2/B1/C2/D1/E2/F2/G2/H2/I1/J1",
    "/A2/B1/C2/D1/E2/F2/G2/H2/I1/J2",
    "/A2/B1/C2/D1/E3",
    "/A2/B1/C2/D1/E3/F1",
    "/A2/B1/C2/D1/E3/F1/G2/H1",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K1",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2",
    "/A2/B1/C2/D1/E3/F1/G2/H2",
    "/A2/B1/C2/D1/E3/F1/G2/H3",
    "/A2/B1/C2/D1/E3/F1/G2/H4",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L1",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L2",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L3",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L4",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K2",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I4",
    "/A2/B1/C2/D1/E3/F2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M3",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M4",
    "/A2/B1/C2/D1/E3/F2/G2/H1",
    "/A2/B1/C2/D1/E3/F2/G2/H2",
    "/A2/B1/C2/D1/E4",
    "/A2/B1/C2/D1/E4/F2/G3",
    "/A2/B1/C2/D1/E4/F2/G4",
    "/A2/B2",
    "/A2/B2/C1",
    "/A2/B2/C1/D2/E2/F1",
    "/A2/B2/C1/D2/E2/F2",
    "/A2/B2/C1/D2/E2/F2/G1",
    "/A2/B2/C1/D2/E2/F2/G2",
    "/A2/B2/C1/D2/E2/F2/G3",
    "/A2/B2/C1/D2/E2/F2/G4",
    "/A2/B2/C1/D2/E2/F2/G5",
    "/A2/B2/C1/D2/E2/F2/G6",
    "/A2/B2/C1/D2/E2/F2/G7",
    "/A2/B2/C1/D2/E3",
    "/A2/B2/C2",
    "/A2/B2/C2/D1",
    "/A2/B2/C2/D1/E3/F1",
    "/A2/B2/C2/D1/E3/F2",
    "/A2/B2/C2/D1/E3/F2/G1",
    "/A2/B2/C2/D1/E3/F2/G2",
    "/A2/B2/C2/D1/E3/F2/G3",
    "/A2/B2/C2/D1/E3/F2/G4",
    "/A2/B2/C2/D1/E3/F2/G5",
    "/A2/B2/C2/D1/E3/F3",
    "/A2/B2/C2/D2",
    "/A2/B2/C2/D2/E2/F1/G1",
    "/A2/B2/C2/D2/E2/F1/G2",
]

class Book: NSObject {
    static let data:Book = Book()
    
    var tree:[String:AnyObject]? = nil
    var contents:[String:[[String:String]]]? = nil
    var index:[[String:String]]? = nil
    var media:[[String:String]]? = nil
    var loaded = false;
    func itemOfPath(path:String) -> [String:AnyObject] {
        if path == "" || path == "/" || path == (self.tree!["path"] as! String){
            return self.tree!
        }
        var node = tree
        for id in path.componentsSeparatedByString("/") {
            if(id == "" || node!["children"] == nil ){continue}
            let children = node!["children"] as! NSArray as! [[String:AnyObject]]
            node = children.filter({
                $0["id"] as! String == id
            }).first
        }
        return node!
    }
    
    func parentOfItem(item:[String:AnyObject]) -> [String:AnyObject]? {
        var path = item["path"] as! String
        if path == "" || path == "/" {
            return nil
        } else {
            path = (path as NSString).substringToIndex(path.lastIndexOf("/")!)
        }
        return self.itemOfPath(path)
    }
    
    func loadDataWithCompletionHandler(handler:Void->Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)){
            if self.loaded {
                handler()
                return
            }
            
            let treeFileURL = NSBundle.mainBundle().URLForResource("data/lengyanjing-index-tree", withExtension: "json")
            
            let data = NSData(contentsOfURL: treeFileURL!)
            do {
                self.tree = try (NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)) as? NSDictionary as? [String: AnyObject]
            } catch _ {
                self.tree = [:]
            }
            
            let contentFile = NSBundle.mainBundle().URLForResource("data/lengyanjing-content", withExtension: "json")
            
            let contentData = NSData(contentsOfURL: contentFile!)
            do {
                self.contents = try (NSJSONSerialization.JSONObjectWithData(contentData!, options: .AllowFragments)) as? NSDictionary
                    as? [String:[[String:String]]]
            } catch _ {
                self.contents  = [:]
            }
            
            let indexFile = NSBundle.mainBundle().URLForResource("data/lengyanjing-index", withExtension: "json")
            
            let indexData = NSData(contentsOfURL: indexFile!)
            do {
                let indexArray = try (NSJSONSerialization.JSONObjectWithData(indexData!, options: .AllowFragments)) as? NSArray
                //--check if any wront type item
                //                print( indexArray?.filter({ (a) -> Bool in
                //                    let d = a as? [String:String]
                //                    if d == nil {
                //                        print(( a as? NSDictionary)!["path"])
                //                        return false
                //                    }
                //                    return true
                //                }).count)
                self.index = indexArray as? [[String:String]]
            } catch _ {
                self.index = []
            }
            
            let mediaFile = NSBundle.mainBundle().URLForResource("data/lengyanjing-media", withExtension: "json")
            
            let mediaData = NSData(contentsOfURL: mediaFile!)
            do {
                self.media = try (NSJSONSerialization.JSONObjectWithData(mediaData!, options: .AllowFragments)) as? NSArray
                    as? [[String:String]]
            } catch _ {
                self.media  = []
            }
            
            self.loaded = true;
            handler()
        }
        
    }
    
    func getTitleLine(item:[String:AnyObject])->NSAttributedString{
        let prefix = "• "
        let title:String = (item["name"] as? String ?? "")
        // (item["id"] as! String) + " " +
        let parent = Book.data.parentOfItem(item)
        let parentTitle = parent?["name"] as? String ?? ""
        //        let titleAttributes = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline), NSForegroundColorAttributeName: UIColor.purpleColor()]
        
        let font:UIFont? = UIFont(name: "Arial", size: 14.0)
        
        let attrString = NSMutableAttributedString(
            string: prefix + parentTitle as String,
            attributes: [NSFontAttributeName: font!])
        
        let font2:UIFont? = UIFont(name: "Arial", size: 10.0)
        let attrString2 = NSMutableAttributedString(
            string: (parent == nil ? "" : " 之 "),
            attributes: [NSFontAttributeName: font2!])
        
        let font1:UIFont? = UIFont(name: "Arial", size: 14.0)
        let attrString1 = NSMutableAttributedString(
            string: title as String,
            attributes: [NSFontAttributeName: font1!])
        
        attrString.appendAttributedString(attrString2)
        attrString.appendAttributedString(attrString1)
        return attrString
    }
    
    func getTitle(item:[String:AnyObject])->NSAttributedString{
        let title:String = (item["name"] as? String ?? "")
        // (item["id"] as! String) + " " +
        let parent = Book.data.parentOfItem(item)
        let parentTitle = parent?["name"] as? String ?? ""
        //        let titleAttributes = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline), NSForegroundColorAttributeName: UIColor.purpleColor()]
        
        let font:UIFont? = UIFont(name: "Arial", size: 12.0)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 5
        
        let attrString = NSMutableAttributedString(
            string: parentTitle as String,
            attributes: [NSFontAttributeName: font!,
                NSParagraphStyleAttributeName : paragraphStyle])
        
        let font2:UIFont? = UIFont(name: "Arial", size: 10.0)
        let attrString2 = NSMutableAttributedString(
            string: parent == nil ? "" : " 之",
            attributes: [NSFontAttributeName: font2!,     NSParagraphStyleAttributeName : paragraphStyle])
        
        let paragraphStyle2 = NSMutableParagraphStyle()
        paragraphStyle2.alignment = .Center
        
        let font1:UIFont? = UIFont(name: "Arial", size: 14.0)
        let attrString1 = NSMutableAttributedString(
            string: "\n" + title as String,
            attributes: [NSFontAttributeName: font1!,     NSParagraphStyleAttributeName : paragraphStyle2])
        
        attrString.appendAttributedString(attrString2)
        attrString.appendAttributedString(attrString1)
        return attrString
    }
    
    func getTitleView(item:[String:AnyObject])->UILabel{
        let label = UILabel(frame: CGRectMake(0, 0, 400, 44))
        label.backgroundColor = UIColor.clearColor()
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.Left
        label.attributedText = getTitle(item)
        label.userInteractionEnabled = true
        return label
    }
    
    func getSutraAttributeString(item:[String:AnyObject])->NSAttributedString{
        let text = getSutra(item, maxLength: Int.max)
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineSpacing = 10
        //pStyle.paragraphSpacing = 5
        pStyle.firstLineHeadIndent = 30
        
        let pAttributes = [NSParagraphStyleAttributeName : pStyle,
                           NSFontAttributeName: UIFont.systemFontOfSize(17)]
        
        return NSAttributedString(string: text, attributes:pAttributes)
    }
    
    func getSutra(item:[String:AnyObject])->String{
        return getSutra(item,maxLength: Int.max)
    }
    
    func getSutra(item:[String:AnyObject], maxLength:Int)->String{
        var sutraContents = [String]()
        let children = item["children"]
        if (children == nil) {
            let content = Book.data.contents?[item["path"] as! String]
            if content != nil {
                var length = 0
                for c in content! {
                    if c["type"] == "sutra" {
                        let sutra = c["content"]!
                        if length + sutra.characters.count <= maxLength {
                            sutraContents.append(sutra)
                            length = length + sutra.characters.count
                        } else {
                            if maxLength <= 3 {
                                sutraContents.append("...")
                            } else {
                                sutraContents.append((sutra as NSString).substringWithRange(NSRange(location: 0, length:  maxLength -  length - 3)) + "...")
                            }
                            break
                        }
                    }
                }
            }
        } else {
            var length = 0
            for i in children as! NSArray {
                let sutra = getSutra(i as! [String:AnyObject], maxLength:maxLength - length )
                sutraContents.append(sutra)
                length = length + sutra.characters.count
                if length >= maxLength {
                    break;
                }
            }
        }
        return sutraContents.joinWithSeparator("\n")
    }
}
