//
//  Book.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class Book: NSObject {
    static let shared:Book = Book()
    
    //data loaded from json
    var tree:[String:Any]? = nil
    var index:[[String:String]]? = nil
    var contents:[String:[[String:String]]]? = nil
    var media:[[String:Any]]? = nil
    private var allPaths:[String]? = nil

    //loading state
    var loaded = false
    //Chinsese lanaguage style: simplified or traditional, based on system locale, default simplified
    var isSimplifiedChinese = true

    //init language based on system locale
    override init(){
        for lan in NSLocale.preferredLanguages {
            if lan.hasPrefix("zh-") {
                if lan.hasPrefix("zh-Hant"){
                    isSimplifiedChinese = false
                }
                break
            }
        }
    }
    
    //MARK: Loading data from json files
    func loadDataSyncWithCompletionHandler(_ handler:@escaping ()->Void) {
        var path = "data/"
        if self.isSimplifiedChinese {
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
        
        self.loaded = true
    }
    
    func loadDataWithCompletionHandler(_ handler:@escaping ()->Void) {
        if self.loaded {
            handler()
            return
        }
        
        DispatchQueue.global(qos:DispatchQoS.QoSClass.userInteractive).async{
            if self.loaded {
                handler()
                return
            }
            self.loadDataSyncWithCompletionHandler(handler)
        }
    }
    
    //MARK: Path, item and relations in the tree
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
            let name = Book.shared.itemOfPath(path)["name"]
            return [path,name as! String]
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
        return nil
    }
    
    func isItemLeaf(_ index:Int) ->Bool?{
        let meta = Book.shared.index?[index]
        let path = meta?["path"] as String?
        if (path == nil){
            return nil
        } else {
            return Book.shared.contents?[path!] != nil
        }
    }
    
    //MARK: Making text for item name, title, sutra to show up
    func getTitleLine(_ item:[String:Any])->NSAttributedString{
        let prefix = "☸ " 
        let title:String = (item["name"] as? String ?? "")
        // (item["id"] as! String) + " " +
        let parent = Book.shared.parentOfItem(item)
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
        let parent = Book.shared.parentOfItem(item)
        let parentTitle = parent?["name"] as? String ?? ""
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
        let titleText = parentTitle.count > 15 ? " " + title : "\n" + title
        let attrString1 = NSMutableAttributedString(
            string: titleText,
            attributes: [NSAttributedStringKey.font: font1!,     NSAttributedStringKey.paragraphStyle : paragraphStyle2])
        
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
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.3
        label.isUserInteractionEnabled = true
        return label
    }
    
    func getItemName(_ name:String, withChapter:Int)->NSAttributedString{
        let chapterLabel = "  " + NSLocalizedString("chapter_\(withChapter  + 1)", comment: "chapter_name") + NSLocalizedString("start_qi", comment: "起")
        
        let noteFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)
        let itemFont = UIFont.systemFont(ofSize: noteFont.pointSize + 2, weight: UIFont.Weight.regular)
        
        let attrString = NSMutableAttributedString(
            string: name,
            attributes: [NSAttributedStringKey.font: itemFont])
        
        let attrString2 = NSMutableAttributedString(
            string: chapterLabel,
            attributes: [NSAttributedStringKey.font: noteFont,
                         NSAttributedStringKey.foregroundColor: UIColor.gray])
        
        attrString.append(attrString2)
        return attrString
    }

    func getSutraAttributeString(_ item:[String:Any], maxLength:Int = Int.max)->NSAttributedString{
        let text = getSutra(item, maxLength: maxLength)
        return self.getSutraAttributeString(text: text)
    }
    
    func getSutraAttributeString(text:String)->NSAttributedString{
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineHeightMultiple = 1.618
        pStyle.maximumLineHeight = 40.0
        pStyle.minimumLineHeight = 10.0
        
        pStyle.paragraphSpacing = 1
        pStyle.firstLineHeadIndent = 35
        
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
            let content = Book.shared.contents?[item["path"] as! String]
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
                    break
                }
            }
        }
        return sutraContents.joined(separator: "\n")
    }
    
    //MARK: Build chapters
    func listChapterStarts(){//debug only
        var starts:[String] = []
        for chapter in 0...9 {
        let endPath = CHAPTER_END_PATHS[chapter]
        let endIndex = KEY_PATHS.index(of: endPath)
        var startIndex:Int?
        if(chapter==0){
            startIndex = 0
        }else{
            let lastEndPath=CHAPTER_END_PATHS[chapter-1]
            let lastEndIndex=KEY_PATHS.index(of: lastEndPath)
            for i in lastEndIndex!...endIndex! {
                if !KEY_PATHS[i].starts(with:lastEndPath) {
                    startIndex = i
                    break
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
        let startPath = CHAPTER_START_PATHS[chapter]
        let endPath = CHAPTER_END_PATHS[chapter]
        let startIndex = KEY_PATHS.index(of: startPath)
        let endIndex = KEY_PATHS.index(of: endPath)

        var sutraContents = [String]()
        
        for j in startIndex!...endIndex! {
            let path = KEY_PATHS[j]
            if j < KEY_PATHS.count - 1 && KEY_PATHS[j+1].starts(with: path) {
                continue//skip hight level items
            }
            sutraContents.append(self.getSutra(self.itemOfPath(path)))
        }
        return sutraContents.joined(separator: "\n")
    }
    
    //MARK: Build pages from any path
    func getPreviousPagePath(_ path:String?)->String?{
        if path == nil { return nil }
        let indexInKeyPages = KEY_PATHS.index(of: path!)
        if indexInKeyPages != nil {//paging by key pages
            for j in 0 ... indexInKeyPages! {
                let i = indexInKeyPages! - j
                let p = KEY_PATHS[i]
                if !path!.starts(with: p) {
                    return p
                }
            }
            return nil
        } else { // paging by full index
            let paths = getAllPaths()
            let index = paths.index(of: path!)
            let belongingKeyPath = getBelongingKeyPagePath(path!)
            if belongingKeyPath == nil { return nil}
            
            if index != nil && index! > 0 {//paging by all items and key pages if found
                let youngBrotherPath = getYoungBrotherPath(path!)
                if youngBrotherPath != nil && youngBrotherPath!.hasPrefix(belongingKeyPath!) {
                    return youngBrotherPath
                }
                for j in 0 ... index! - 1 {
                    let i = index! - 1 - j
                    let p = paths[i]
                    
                    if p.starts(with: belongingKeyPath!) {//still under the same key path
                        //skip parents levels
                        if i + 1 <= paths.count - 1 && paths[i+1].starts(with:p) {
                            continue
                        }
                        
                        //skip lower levels if it's parent in scope
                        var parent:String = p, lastParent:String?
                        repeat{
                            parent = NSString(string:parent).deletingLastPathComponent
                            if parent.hasPrefix(belongingKeyPath!) && !path!.hasPrefix(parent){
                                lastParent = parent
                            } else {
                                if lastParent == nil {
                                    break
                                } else {
                                    return lastParent!
                                }
                            }
                        } while (true)
                        
                        return p
                    } else {//previous key page!
                        return getPreviousPagePath(belongingKeyPath!)
                    }
                    
                }
                return nil
            } else {
                return nil
            }
            
        }
    }
    
    func getBelongingKeyPagePath(_ path:String)->String?{
        var p = path
        repeat {
            let indexInKeyPages = KEY_PATHS.index(of: p)
            if indexInKeyPages != nil {
                return p
            } else{
                let parent = NSString(string:p).deletingLastPathComponent
                if (parent == p) {
                    break
                } else {
                    p = parent
                }
            }
        }while(true)
            
        NSLog("Error: Could not getBelongingKeyPagePath for path \(path)")
        return nil
    }
    
    func getNextPagePath(_ path:String?)->String?{
        if path == nil { return nil }

        let indexInKeyPages = KEY_PATHS.index(of: path!)
        if indexInKeyPages != nil {//paging by key pages
            for i in indexInKeyPages! ... KEY_PATHS.count-1 {
                let p = KEY_PATHS[i]
                if !p.starts(with: path!) {//skip last page children
                    //skip non-leaf directory
                    if i + 1 < KEY_PATHS.count - 1 && KEY_PATHS[i+1].starts(with:p) {
                        continue
                    }
                    return p
                }
            }
            return nil
        } else { // paging by full index and key pages
            let paths = Book.shared.getAllPaths()
            let index = paths.index(of: path!)
            let belongingKeyPath = getBelongingKeyPagePath(path!)
            if belongingKeyPath == nil { return nil}
            
            if index != nil && index! < paths.count - 1 {
                for i in index!+1 ... paths.count-1 {
                    let p = paths[i]
                    if p.starts(with: belongingKeyPath!) {//still under the same key path
                        if p.starts(with: path!) {//skip last page children
                            continue
                        } else {
//                            //skip non-leaf directory
//                            if i + 1 < paths.count - 1 && paths[i+1].starts(with:p) {
//                                continue
//                            }
                            return p
                        }
                    } else {//next key page!
                        return getNextPagePath(belongingKeyPath!)
                    }
                }
                return nil
            } else {
                return nil
            }
        }
    }
    
}
