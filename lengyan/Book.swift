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
    "/A2/B1/C2/D1/E3/F2/G1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M3",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M4",
    "/A2/B1/C2/D1/E3/F2/G2",
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
    
    var tree:[String:Any]? = nil
    var contents:[String:[[String:String]]]? = nil
    var index:[[String:String]]? = nil
    var media:[[String:Any]]? = nil
    var loaded = false;
    func itemOfPath(_ path:String) -> [String:Any] {
        if path == "" || path == "/" || path == (self.tree!["path"] as! String){
            return self.tree!
        }
        var node = tree
        for id in path.components(separatedBy: "/") {
            if(id == "" || node!["children"] == nil ){continue}
            let children = node!["children"] as! NSArray as! [[String:Any]]
            node = children.filter({
                $0["id"] as! String == id
            }).first
        }
        return node!
    }
    
    func parentOfItem(_ item:[String:Any]) -> [String:Any]? {
        var path = item["path"] as! String
        if path == "" || path == "/" {
            return nil
        } else {
            path = (path as NSString).substring(to: path.lastIndexOf("/")!)
        }
        return self.itemOfPath(path)
    }
    
    func loadDataWithCompletionHandler(_ handler:@escaping (Void)->Void) {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async{
            if self.loaded {
                handler()
                return
            }
            
            let treeFileURL = Bundle.main.url(forResource: "data/lengyanjing-index-tree", withExtension: "json")
            
            let data = try? Foundation.Data(contentsOf: treeFileURL!)
            do {
                self.tree = try (JSONSerialization.jsonObject(with: data!, options: .allowFragments)) as? NSDictionary as? [String: Any]
            } catch _ {
                self.tree = [:]
            }
            
            let contentFile = Bundle.main.url(forResource: "data/lengyanjing-content", withExtension: "json")
            
            let contentData = try? Foundation.Data(contentsOf: contentFile!)
            do {
                self.contents = try (JSONSerialization.jsonObject(with: contentData!, options: .allowFragments)) as? NSDictionary
                    as? [String:[[String:String]]]
            } catch _ {
                self.contents  = [:]
            }
            
            let indexFile = Bundle.main.url(forResource: "data/lengyanjing-index", withExtension: "json")
            
            let indexData = try? Foundation.Data(contentsOf: indexFile!)
            do {
                let indexArray = try (JSONSerialization.jsonObject(with: indexData!, options: .allowFragments)) as? NSArray
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
            
            let mediaFile = Bundle.main.url(forResource: "data/lengyanjing-media", withExtension: "json")
            
            let mediaData = try? Foundation.Data(contentsOf: mediaFile!)
            do {
                self.media = try (JSONSerialization.jsonObject(with: mediaData!, options: .allowFragments)) as? NSArray
                    as? [[String:Any]]
            } catch _ {
                self.media  = []
            }
            
            self.loaded = true;
            handler()
        }
        
    }
    
    func getTitleLine(_ item:[String:Any])->NSAttributedString{
        let prefix = "☸ " 
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
        
        attrString.append(attrString2)
        attrString.append(attrString1)
        return attrString
    }
    
    func getTitle(_ item:[String:Any])->NSAttributedString{
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
        paragraphStyle2.alignment = .center
        
        let font1:UIFont? = UIFont(name: "Arial", size: 14.0)
        let attrString1 = NSMutableAttributedString(
            string: "\n" + title as String,
            attributes: [NSFontAttributeName: font1!,     NSParagraphStyleAttributeName : paragraphStyle2])
        
        attrString.append(attrString2)
        attrString.append(attrString1)
        return attrString
    }
    
    func getTitleView(_ item:[String:Any])->UILabel{
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 400, height: 44))
        label.backgroundColor = UIColor.clear
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.left
        label.attributedText = getTitle(item)
        label.isUserInteractionEnabled = true
        return label
    }
    
    func getSutraAttributeString(_ item:[String:Any], maxLength:Int = Int.max)->NSAttributedString{
        let text = getSutra(item, maxLength: maxLength)
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineHeightMultiple = 1.3
        pStyle.maximumLineHeight = 40.0
        pStyle.minimumLineHeight = 10.0
        
//        pStyle.lineSpacing = 20
        pStyle.paragraphSpacing = 1
        pStyle.firstLineHeadIndent = 30
        
        let pAttributes = [NSParagraphStyleAttributeName : pStyle,
                           NSFontAttributeName: UIFont.systemFont(ofSize: 17)]
        
        return NSAttributedString(string: text, attributes:pAttributes)
    }
    
    func getSutra(_ item:[String:Any])->String{
        return getSutra(item,maxLength: Int.max)
    }
    
    func getSutra(_ item:[String:Any], maxLength:Int)->String{
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
                                sutraContents.append((sutra as NSString).substring(with: NSRange(location: 0, length:  maxLength -  length - 3)) + "...")
                            }
                            break
                        }
                    }
                }
            }
        } else {
            var length = 0
            for i in children as! NSArray {
                let sutra = getSutra(i as! [String:Any], maxLength:maxLength - length )
                sutraContents.append(sutra)
                length = length + sutra.characters.count
                if length >= maxLength {
                    break;
                }
            }
        }
        return sutraContents.joined(separator: "\n")
    }
}
