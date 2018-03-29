//
//  Book.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

let KEY_PATHS = [
    "/A1",
    "/A2",
    "/A2/B1",
    "/A2/B1/C1",
    "/A2/B1/C2",
    "/A2/B1/C2/D1",
    "/A2/B1/C2/D1/E1",
    "/A2/B1/C2/D1/E2",
    "/A2/B1/C2/D1/E2/F1",
    "/A2/B1/C2/D1/E2/F1/G1",
    "/A2/B1/C2/D1/E2/F1/G1/H1",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I1",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K1",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K2",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K3",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J2",
    "/A2/B1/C2/D1/E2/F1/G1/H1/I3",
    "/A2/B1/C2/D1/E2/F1/G1/H2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M3",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M4",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M5",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M6",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M7",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M8",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M9",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M10",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M1",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M3",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M4",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K3",
    "/A2/B1/C2/D1/E2/F1/G2",
    "/A2/B1/C2/D1/E2/F2",
    "/A2/B1/C2/D1/E2/F2/G1",
    "/A2/B1/C2/D1/E2/F2/G2",
    "/A2/B1/C2/D1/E2/F2/G2/H1",
    "/A2/B1/C2/D1/E2/F2/G2/H2",
    "/A2/B1/C2/D1/E2/F2/G2/H2/I1",
    "/A2/B1/C2/D1/E2/F2/G2/H2/I1/J1",
    "/A2/B1/C2/D1/E2/F2/G2/H2/I1/J2",
    "/A2/B1/C2/D1/E2/F2/G2/H2/I2",
    "/A2/B1/C2/D1/E3",
    "/A2/B1/C2/D1/E3/F1",
    "/A2/B1/C2/D1/E3/F1/G1",
    "/A2/B1/C2/D1/E3/F1/G2",
    "/A2/B1/C2/D1/E3/F1/G2/H1",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I1",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J1",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K1",
    "/A2/B1/C2/D1/E3/F1/G2/H1/I2/J2/K2",
    "/A2/B1/C2/D1/E3/F1/G2/H2",
    "/A2/B1/C2/D1/E3/F1/G2/H2/I1",
    "/A2/B1/C2/D1/E3/F1/G2/H2/I2",
    "/A2/B1/C2/D1/E3/F1/G2/H3",
    "/A2/B1/C2/D1/E3/F1/G2/H4",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I1",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I2",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J1",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L1",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L2",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L3",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L4",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K2",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J3",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I4",
    "/A2/B1/C2/D1/E3/F2",
    "/A2/B1/C2/D1/E3/F2/G1",
    "/A2/B1/C2/D1/E3/F2/G1/H1",
    "/A2/B1/C2/D1/E3/F2/G1/H2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M1",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M3",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M4",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L3",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K2",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J2",
    "/A2/B1/C2/D1/E3/F2/G2",
    "/A2/B1/C2/D1/E3/F2/G2/H1",
    "/A2/B1/C2/D1/E3/F2/G2/H2",
    "/A2/B1/C2/D1/E4",
    "/A2/B1/C2/D1/E4/F1",
    "/A2/B1/C2/D1/E4/F2",
    "/A2/B1/C2/D1/E4/F2/G1",
    "/A2/B1/C2/D1/E4/F2/G2",
    "/A2/B1/C2/D1/E4/F2/G3",
    "/A2/B1/C2/D1/E4/F2/G4",
    "/A2/B2",
    "/A2/B2/C1",
    "/A2/B2/C1/D1",
    "/A2/B2/C1/D2",
    "/A2/B2/C1/D2/E1",
    "/A2/B2/C1/D2/E2",
    "/A2/B2/C1/D2/E2/F1",
    "/A2/B2/C1/D2/E2/F2",
    "/A2/B2/C1/D2/E2/F2/G1",
    "/A2/B2/C1/D2/E2/F2/G2",
    "/A2/B2/C1/D2/E2/F2/G3",
    "/A2/B2/C1/D2/E2/F2/G4",
    "/A2/B2/C1/D2/E2/F2/G5",
    "/A2/B2/C1/D2/E2/F2/G6",
    "/A2/B2/C1/D2/E2/F2/G6/H1",
    "/A2/B2/C1/D2/E2/F2/G6/H1/I1",
    "/A2/B2/C1/D2/E2/F2/G6/H1/I2",
    "/A2/B2/C1/D2/E2/F2/G6/H2",
    "/A2/B2/C1/D2/E2/F2/G7",
    "/A2/B2/C1/D2/E3",
    "/A2/B2/C2",
    "/A2/B2/C2/D1",
    "/A2/B2/C2/D1/E1",
    "/A2/B2/C2/D1/E2",
    "/A2/B2/C2/D1/E3",
    "/A2/B2/C2/D1/E3/F1",
    "/A2/B2/C2/D1/E3/F2",
    "/A2/B2/C2/D1/E3/F2/G1",
    "/A2/B2/C2/D1/E3/F2/G2",
    "/A2/B2/C2/D1/E3/F2/G3",
    "/A2/B2/C2/D1/E3/F2/G4",
    "/A2/B2/C2/D1/E3/F2/G5",
    "/A2/B2/C2/D1/E3/F3",
    "/A2/B2/C2/D2",
    "/A3"
];
let CHAPTER_START_PATHS =
[
"/A1",
"/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M3",
"/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M2",
"/A2/B1/C2/D1/E2/F2",
"/A2/B1/C2/D1/E3/F1/G2/H2/I2",
"/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K2",
"/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L3",
"/A2/B1/C2/D1/E4/F2/G4",
"/A2/B2/C1/D2/E2/F2/G6/H1/I2",
"/A2/B2/C2/D1/E3/F2/G4"
]
let CHAPTER_END_PATHS=[
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K1/L1/M2",
    "/A2/B1/C2/D1/E2/F1/G1/H2/I2/J2/K2/L2/M1",
    "/A2/B1/C2/D1/E2/F1/G2",
    "/A2/B1/C2/D1/E3/F1/G2/H2/I1",
    "/A2/B1/C2/D1/E3/F1/G2/H4/I3/J2/K1/L4",
    "/A2/B1/C2/D1/E3/F2/G1/H2/I3/J1/K1/L2/M4",
    "/A2/B1/C2/D1/E4/F2/G3",
    "/A2/B2/C1/D2/E2/F2/G6/H1/I1",
    "/A2/B2/C2/D1/E3/F2/G3",
    "/A3"]

class Book: NSObject {
    static let data:Book = Book()
    
    var tree:[String:Any]? = nil
    var contents:[String:[[String:String]]]? = nil
    var index:[[String:String]]? = nil
    var media:[[String:Any]]? = nil
    var loaded = false;
    var isSimplified = true;
    var allPaths:[String]? = nil;
    
    override init() {
        for lan in NSLocale.preferredLanguages {
            if lan.hasPrefix("zh-") {
                if lan.hasPrefix("zh-Hant"){
                    isSimplified = false
                }
                break;
            }
        }
    }
    
//    func getKeyPages()->[String]{
//        if self.keyPages != nil { return keyPages!;}
//        var pages:[String] = [];
//        for(i,path) in KEY_PATHS.enumerated() {
//            if(i < KEY_PATHS.count - 1){
//                if KEY_PATHS[i+1].starts(with: path) {
//                    continue;
//                }
//            }
//            pages.append(path)
//        }
//        self.keyPages = pages;
//        return pages;
//    }
    
    func getAllPaths()->[String]{
        if self.allPaths == nil {
            self.allPaths = self.index?.map({ (item) -> String in
              return item["path"]!
            });
        }
        return self.allPaths!;
    }
    
    func getKeyItems() ->[[String]]{
        return KEY_PATHS.map { (path) -> [String] in
            let name = Book.data.itemOfPath(path)["name"];
            return [path,name as! String];
        }
    }
    func itemOfPath(_ path:String ) -> [String:Any] {
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
    func getYoungBrotherPath(_ path: String) -> String?{
        if let seq = Int(NSString(string:path).lastPathComponent.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
            if seq > 1 {
                return String(path.prefix(path.count - String(seq).count)) +  String(seq - 1)
            }
        }
        return nil;
    }
    func isItemLeaf(_ index:Int) ->Bool?{
        let meta = Book.data.index?[index];
        let path = meta?["path"] as String?;
        if (path == nil){
            return nil
        } else {
            return Book.data.contents?[path!] != nil;
        }
    }
    
    func loadDataSyncWithCompletionHandler(_ handler:@escaping ()->Void) {
      var path = "data/"
        if self.isSimplified {
            path = "data/simplified/"
        }
        let treeFileURL = Bundle.main.url(forResource: path + "lengyanjing-index-tree", withExtension: "json")
        
        let data = try? Foundation.Data(contentsOf: treeFileURL!)
        do {
            self.tree = try (JSONSerialization.jsonObject(with: data!, options: .allowFragments)) as? NSDictionary as? [String: Any]
        } catch _ {
            self.tree = [:]
        }
        
        let contentFile = Bundle.main.url(forResource:  path + "lengyanjing-content", withExtension: "json")
        
        let contentData = try? Foundation.Data(contentsOf: contentFile!)
        do {
            self.contents = try (JSONSerialization.jsonObject(with: contentData!, options: .allowFragments)) as? NSDictionary
                as? [String:[[String:String]]]
        } catch _ {
            self.contents  = [:]
        }
        
        let indexFile = Bundle.main.url(forResource:  path + "lengyanjing-index", withExtension: "json")
        
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
        
        let mediaFile = Bundle.main.url(forResource:  path + "lengyanjing-media", withExtension: "json")
        
        let mediaData = try? Foundation.Data(contentsOf: mediaFile!)
        do {
            self.media = try (JSONSerialization.jsonObject(with: mediaData!, options: .allowFragments)) as? NSArray
                as? [[String:Any]]
        } catch _ {
            self.media  = []
        }
        
        self.loaded = true;
        //        listChapterStarts();
    }
    
    func loadDataWithCompletionHandler(_ handler:@escaping ()->Void) {
        if self.loaded {
            handler()
            return
        };
        
        DispatchQueue.global(qos:DispatchQoS.QoSClass.userInteractive).async{
            if self.loaded {
                handler()
                return
            }
            self.loadDataSyncWithCompletionHandler(handler)
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
            attributes: [NSAttributedStringKey.font: font!])
        
        let font2:UIFont? = UIFont(name: "Arial", size: 10.0)
        let attrString2 = NSMutableAttributedString(
            string: (parent == nil ? "" : " 之 "),
            attributes: [NSAttributedStringKey.font: font2!])
        
        let font1:UIFont? = UIFont(name: "Arial", size: 14.0)
        let attrString1 = NSMutableAttributedString(
            string: title as String,
            attributes: [NSAttributedStringKey.font: font1!])
        
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
            attributes: [NSAttributedStringKey.font: font!,
                         NSAttributedStringKey.paragraphStyle : paragraphStyle])
        
        let font2:UIFont? = UIFont(name: "Arial", size: 10.0)
        let attrString2 = NSMutableAttributedString(
            string: parent == nil ? "" : " 之",
            attributes: [NSAttributedStringKey.font: font2!,     NSAttributedStringKey.paragraphStyle : paragraphStyle])
        
        let paragraphStyle2 = NSMutableParagraphStyle()
        paragraphStyle2.alignment = .center
        
        let font1:UIFont? = UIFont(name: "Arial", size: 14.0)
        let titleText = parentTitle.count > 15 ? " " + title : "\n" + title;
        let attrString1 = NSMutableAttributedString(
            string: titleText,
            attributes: [NSAttributedStringKey.font: font1!,     NSAttributedStringKey.paragraphStyle : paragraphStyle2])
        
        attrString.append(attrString2)
        attrString.append(attrString1)
        return attrString
    }
    
    func getItemName(_ name:String, withChapter:Int)->NSAttributedString{
        let chapterLabel = "  " + NSLocalizedString("chapter_\(withChapter  + 1)", comment: "chapter_name") + NSLocalizedString("start_qi", comment: "起");
        
        let noteFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote);
        let labelFont = UIFont.systemFont(ofSize: noteFont.pointSize - 4, weight:  UIFont.Weight.light) ;
        let itemFont = UIFont.systemFont(ofSize: noteFont.pointSize + 2, weight: UIFont.Weight.regular);
        
        let attrString = NSMutableAttributedString(
            string: name,
            attributes: [NSAttributedStringKey.font: itemFont]);
        
        let attrString2 = NSMutableAttributedString(
            string: chapterLabel,
            attributes: [NSAttributedStringKey.font: noteFont,
                         NSAttributedStringKey.foregroundColor: UIColor.gray]);
        
        attrString.append(attrString2)
        return attrString
    }
    
    func getTitleView(_ item:[String:Any])->UILabel{
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 400, height: 44))
        label.backgroundColor = UIColor.clear
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.left
        label.attributedText = getTitle(item)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.3;
        label.isUserInteractionEnabled = true
        return label
    }
    
    func getSutraAttributeString(_ item:[String:Any], maxLength:Int = Int.max)->NSAttributedString{
        let text = getSutra(item, maxLength: maxLength)
        return self.getSutraAttributeString(text: text);
    }
    
    
    func getSutraAttributeString(text:String)->NSAttributedString{
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineHeightMultiple = 1.3
        pStyle.maximumLineHeight = 40.0
        pStyle.minimumLineHeight = 10.0
        
        //        pStyle.lineSpacing = 20
        pStyle.paragraphSpacing = 1
        pStyle.firstLineHeadIndent = 40
        
        let font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        
        let pAttributes = [NSAttributedStringKey.paragraphStyle : pStyle,
                           NSAttributedStringKey.font: font]
        
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
                        if length + sutra.count + 3 <= maxLength {
                            sutraContents.append(sutra)
                            length = length + sutra.count
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
                length = length + sutra.count
                if length >= maxLength {
                    break;
                }
            }
        }
        return sutraContents.joined(separator: "\n")
    }
    func listChapterStarts(){
        var starts:[String] = []
        for chapter in 0...9 {
        let endPath = CHAPTER_END_PATHS[chapter];
        let endIndex = KEY_PATHS.index(of: endPath);
        var startIndex:Int?;
        if(chapter==0){
            startIndex = 0;
        }else{
            let lastEndPath=CHAPTER_END_PATHS[chapter-1];
            let lastEndIndex=KEY_PATHS.index(of: lastEndPath);
            for i in lastEndIndex!...endIndex! {
                if !KEY_PATHS[i].starts(with:lastEndPath) {
                    startIndex = i;
                    break;
                }
            }
            }
            starts.append(KEY_PATHS[startIndex!])
        }
        let data = try! JSONSerialization.data(withJSONObject: starts, options: .prettyPrinted)
        let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        print (string! as String)
    }
    func getChapterSutra(chapter:Int)->String{
        let startPath = CHAPTER_START_PATHS[chapter];
        let endPath = CHAPTER_END_PATHS[chapter];
        let startIndex=KEY_PATHS.index(of: startPath);
        let endIndex=KEY_PATHS.index(of: endPath);

        var sutraContents = [String]()
        
        for j in startIndex!...endIndex! {
            let path = KEY_PATHS[j];
            if j < KEY_PATHS.count - 1 && KEY_PATHS[j+1].starts(with: path) {
                continue;//skip hight level items
            }
            sutraContents.append(self.getSutra(self.itemOfPath(path)));
        }
        return sutraContents.joined(separator: "\n")
    }
    
    func getPreviousPagePath(_ path:String?)->String?{
        if path == nil { return nil }
        let indexInKeyPages = KEY_PATHS.index(of: path!)
        if indexInKeyPages != nil {//paging by key pages
            for j in 0 ... indexInKeyPages! {
                let i = indexInKeyPages! - j
                let p = KEY_PATHS[i];
                if !path!.starts(with: p) {
                    return p;
                }
            }
            return nil;
        } else { // paging by full index
            let paths = getAllPaths();
            let index = paths.index(of: path!)
            let belongingKeyPath = getBelongingKeyPagePath(path!)
            if belongingKeyPath == nil { return nil}
            
            if index != nil && index! > 0 {//paging by all items and key pages if found
                let youngBrotherPath = getYoungBrotherPath(path!)
                if youngBrotherPath != nil && youngBrotherPath!.hasPrefix(belongingKeyPath!) {
                    return youngBrotherPath;
                }
                for j in 0 ... index! - 1 {
                    let i = index! - 1 - j
                    let p = paths[i];
                    
                    if p.starts(with: belongingKeyPath!) {//still under the same key path
                        //skip parents levels
                        if i + 1 <= paths.count - 1 && paths[i+1].starts(with:p) {
                            continue;
                        }
                        
                        //skip lower levels if it's parent in scope
                        var parent:String = p, lastParent:String?
                        repeat{
                            parent = NSString(string:parent).deletingLastPathComponent
                            if parent.hasPrefix(belongingKeyPath!) && !path!.hasPrefix(parent){
                                lastParent = parent;
                            } else {
                                if lastParent == nil {
                                    break;
                                } else {
                                    return lastParent!;
                                }
                            }
                        } while (true)
                        
                        return p;
                    } else {//previous key page!
                        return getPreviousPagePath(belongingKeyPath!);
                    }
                    
                }
                return nil;
            } else {
                return nil;
            }
            
        }
    }
    func getBelongingKeyPagePath(_ path:String)->String?{
        var p = path;
        repeat {
            let indexInKeyPages = KEY_PATHS.index(of: p)
            if indexInKeyPages != nil {
                return p;
            } else{
                let parent = NSString(string:p).deletingLastPathComponent
                if (parent == p) {
                    break;
                } else {
                    p = parent;
                }
            }
        }while(true);
            
        NSLog("Error: Could not getBelongingKeyPagePath for path \(path)");
        return nil;
    }
    
    func getNextPagePath(_ path:String?)->String?{
        if path == nil { return nil }

        let indexInKeyPages = KEY_PATHS.index(of: path!)
        if indexInKeyPages != nil {//paging by key pages
            for i in indexInKeyPages! ... KEY_PATHS.count-1 {
                let p = KEY_PATHS[i];
                if !p.starts(with: path!) {//skip last page children
                    //skip non-leaf directory
                    if i + 1 < KEY_PATHS.count - 1 && KEY_PATHS[i+1].starts(with:p) {
                        continue;
                    }
                    return p;
                }
            }
            return nil;
        } else { // paging by full index and key pages
            let paths = Book.data.getAllPaths();
            let index = paths.index(of: path!)
            let belongingKeyPath = getBelongingKeyPagePath(path!)
            if belongingKeyPath == nil { return nil}
            
            if index != nil && index! < paths.count - 1 {
                for i in index!+1 ... paths.count-1 {
                    let p = paths[i];
                    if p.starts(with: belongingKeyPath!) {//still under the same key path
                        if p.starts(with: path!) {//skip last page children
                            continue;
                        } else {
//                            //skip non-leaf directory
//                            if i + 1 < paths.count - 1 && paths[i+1].starts(with:p) {
//                                continue;
//                            }
                            return p;
                        }
                    } else {//next key page!
                        return getNextPagePath(belongingKeyPath!);
                    }
                   
                }
                return nil;
            } else {
                return nil;
            }
            
        }
    }
    

}
