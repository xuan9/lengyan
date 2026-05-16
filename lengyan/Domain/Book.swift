//
//  Book.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit
import SwiftUI

class SutraTitleContainerView: UIView {
    override var intrinsicContentSize: CGSize {
        // 要求水平方向尽可能宽，垂直方向自适应，从而强制利用所有可用空间
        return CGSize(width: UILayoutFittingExpandedSize.width, height: UIViewNoIntrinsicMetric)
    }
}

class Book: NSObject {
    static let shared:Book = Book()
    
    //data loaded from json
    var tree:[String:Any]? = nil
    var index:[[String:String]]? = nil
    var contents:[String:[[String:String]]]? = nil
    var media:[[String:Any]]? = nil
    var chapterMap: [String: [String]]? = nil
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
        
        let chapterMapFile = Bundle.main.url(forResource: "data/lengyanjing-chapter-map", withExtension: "json")
        let chapterMapData = try? Foundation.Data(contentsOf: chapterMapFile!)
        do {
            self.chapterMap = try (JSONSerialization.jsonObject(with: chapterMapData!, options: .allowFragments)) as? [String: [String]]
        } catch _ {
            self.chapterMap = [:]
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
    @MainActor
    func getTitleLine(_ item:[String:Any])->NSAttributedString{
        let prefix = "☸ "
        let title:String = (item["name"] as? String ?? "")
        let parent = Book.shared.parentOfItem(item)
        let parentTitle = parent?["name"] as? String ?? ""
        // Use unified SutraTypography design system for proper Chinese font rendering
        // Parent title uses index item style
        let parentFont = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
        let attrString = NSMutableAttributedString(
            string: prefix + parentTitle as String,
            attributes: [NSAttributedStringKey.font: parentFont])

        // Divider "之" uses smaller caption style
        let dividerFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
        let attrString2 = NSMutableAttributedString(
            string: (parent == nil ? "" : " 之 "),
            attributes: [NSAttributedStringKey.font: dividerFont])

        // Title uses navigation title style but with lighter weight and more letter spacing for elegance
        let titleFont = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular)
        let attrString1 = NSMutableAttributedString(
            string: title as String,
            attributes: [NSAttributedStringKey.font: titleFont, NSAttributedStringKey.kern: 2.0])

        attrString.append(attrString2)
        attrString.append(attrString1)
        return attrString
    }
    
    @MainActor
    func getTitle(_ item:[String:Any])->NSAttributedString{
        let title:String = (item["name"] as? String ?? "")
        let parent = Book.shared.parentOfItem(item)
        let parentTitle = parent?["name"] as? String ?? ""
        // Use unified SutraTypography design system for proper Chinese font rendering
        let font = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 5

        let attrString = NSMutableAttributedString(
            string: parentTitle as String,
            attributes: [NSAttributedStringKey.font: font,
                         NSAttributedStringKey.paragraphStyle : paragraphStyle])

        // Divider "之" uses caption style
        let dividerFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
        let attrString2 = NSMutableAttributedString(
            string: parent == nil ? "" : " 之",
            attributes: [NSAttributedStringKey.font: dividerFont, NSAttributedStringKey.paragraphStyle : paragraphStyle])

        let paragraphStyle2 = NSMutableParagraphStyle()
        paragraphStyle2.alignment = .center
        paragraphStyle2.paragraphSpacingBefore = 2 // 稍微缩短主副标距离，防止两行文字顶破导航栏上下边缘

        // Title uses navigation title style - lighter, airier
        let titleFont = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular)
        let titleText = parentTitle.count > 15 ? " " + title : "\n" + title
        let attrString1 = NSMutableAttributedString(
            string: titleText,
            attributes: [
                NSAttributedStringKey.font: titleFont,
                NSAttributedStringKey.paragraphStyle : paragraphStyle2,
                NSAttributedStringKey.kern: 3.0 // 典雅宽绰的字间距
            ])

        attrString.append(attrString2)
        attrString.append(attrString1)
        return attrString
    }
    
    @MainActor
    func getTitleView(_ item:[String:Any])->UIView{
        let title:String = (item["name"] as? String ?? "")
        let parent = Book.shared.parentOfItem(item)
        let parentTitle = parent?["name"] as? String ?? ""
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 2
        
        if parent != nil && !parentTitle.isEmpty {
            let parentLabel = UILabel()
            parentLabel.font = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
            parentLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
            parentLabel.textAlignment = .center
            parentLabel.lineBreakMode = .byTruncatingTail // 强制单行截掉长尾
            parentLabel.adjustsFontSizeToFitWidth = true
            parentLabel.minimumScaleFactor = 0.7 // 允许在截断前适度缩小文字
            
            let pText = parentTitle + " 之"
            let pAttr = NSMutableAttributedString(string: pText)
            pAttr.addAttribute(NSAttributedStringKey.kern, value: 1.0, range: NSRange(location: 0, length: pAttr.length))
            
            // 将辅助介词“之”单独缩小及减淡颜色
            let zhiRange = (pText as NSString).range(of: " 之")
            if zhiRange.location != NSNotFound {
                let zhiFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .light).withSize(10)
                pAttr.addAttribute(NSAttributedStringKey.font, value: zhiFont, range: zhiRange)
                // 采用与主标题相同的主色，仅依靠字号大小差异来区分，保证绝对的可读性
                pAttr.addAttribute(NSAttributedStringKey.foregroundColor, value: SutraDesignTokens.shared.color(for: .textPrimary), range: zhiRange)
            }
            
            parentLabel.attributedText = pAttr
            
            stackView.addArrangedSubview(parentLabel)
        }
        
        let titleLabel = UILabel()
        let isTwoLines = parent != nil && !parentTitle.isEmpty
        // 无论单行还是双行，正标题最大字号统一限制在 24pt
        let baseFont = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular)
        titleLabel.font = baseFont.withSize(24)
        
        titleLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail // 强制单行截掉长尾避免三行坍塌
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5 // 允许更大程度缩放
        
        // 核心修复：固定的字间距(kern: 3.0)在字体缩小时不会按比例缩小。
        // 对于长标题，字间距反而会占据大量宽度，导致文字无法有效缩小。
        // 因此对于超过 6 个字的长标题，我们舍弃 kern，让系统完美执行文字缩小。
        if title.count <= 6 {
            let attr = NSMutableAttributedString(string: title)
            attr.addAttribute(NSAttributedStringKey.kern, value: 3.0, range: NSRange(location: 0, length: attr.length))
            titleLabel.attributedText = attr
        } else {
            titleLabel.text = title
        }
        
        stackView.addArrangedSubview(titleLabel)

        return stackView
    }
    
    @MainActor
    func getItemName(_ name:String, withChapter:Int)->NSAttributedString{
        let chapterLabel = "  " + NSLocalizedString("chapter_\(withChapter  + 1)", comment: "chapter_name") + NSLocalizedString("start_qi", comment: "起")

        // Use unified SutraTypography design system for proper Chinese font rendering
        let itemFont = SutraTypographyManager.shared.uiFont(for: .indexItem, weight: .regular)
        let noteFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)

        let attrString = NSMutableAttributedString(
            string: name,
            attributes: [NSAttributedStringKey.font: itemFont])

        let attrString2 = NSMutableAttributedString(
            string: chapterLabel,
            attributes: [NSAttributedStringKey.font: noteFont,
                         NSAttributedStringKey.foregroundColor: SutraDesignTokens.shared.color(for: .textSecondary)])

        attrString.append(attrString2)
        return attrString
    }

    @MainActor
    func getSutraAttributeString(_ item:[String:Any], maxLength:Int = Int.max)->NSAttributedString{
        let text = getSutra(item, maxLength: maxLength)
        return self.getSutraAttributeString(text: text)
    }
    
    @MainActor
    func getSutraAttributeString(text:String)->NSAttributedString{
        // Use unified SutraTypography design system for sutra text
        let font = SutraTypographyManager.shared.uiFont(for: .sutraBody, weight: .regular)
        let textColor = SutraDesignTokens.shared.color(for: .sutraText)

        let pStyle = NSMutableParagraphStyle()
        pStyle.lineHeightMultiple = 1.8       // 提升行距呼吸感（与阅读页统一）
        pStyle.maximumLineHeight = 44.0       // 配合更大行高
        pStyle.minimumLineHeight = 10.0

        pStyle.paragraphSpacing = 24          // 段落间重现古卷的留白呼吸
        pStyle.firstLineHeadIndent = font.pointSize * 2.0 // 精确的首行二字缩进

        let pAttributes: [NSAttributedStringKey: Any] = [
            NSAttributedStringKey.paragraphStyle: pStyle,
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: textColor,
            NSAttributedStringKey.kern: 1.5   // 文字呼吸感
        ]

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
    
    func getChapterSutra(chapter:Int)->String{
        guard let chapterPaths = chapterMap?[String(chapter + 1)] else {
            return ""
        }

        var sutraContents = [String]()
        for path in chapterPaths {
            sutraContents.append(self.getSutra(self.itemOfPath(path)))
        }
        return sutraContents.joined(separator: "\n")
    }

    func getContent(for pageIndex: Int) -> String {
        guard let index = index, pageIndex >= 0, pageIndex < index.count else {
            return ""
        }
        let item = index[pageIndex]
        if let path = item["path"] {
            if let itemDict = item as? [String: Any] {
                return getSutra(itemDict)
            }
            let itemAtPath = itemOfPath(path)
            return getSutra(itemAtPath)
        }
        return ""
    }

    func getTitleString(_ item: [String: Any]) -> String {
        return item["name"] as? String ?? ""
    }

    func getAllChapterTitles() -> [String] {
        var titles: [String] = []
        for i in 0..<10 {
            let chapterKey = "chapter_\(i)"
            let title = NSLocalizedString(chapterKey, comment: "chapter_name")
            titles.append(title)
        }
        return titles
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
