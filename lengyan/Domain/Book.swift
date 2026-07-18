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
        return CGSize(width: UIView.layoutFittingExpandedSize.width, height: UIView.noIntrinsicMetric)
    }
}

class Book: NSObject {
    static let shared:Book = Book()

    typealias ResourceDataProvider = (_ resourceName: String, _ fileExtension: String) -> Foundation.Data?

    enum LoadError: Error, Equatable, LocalizedError {
        case missingOrInvalidResources([String])

        var errorDescription: String? {
            switch self {
            case let .missingOrInvalidResources(resources):
                return "Book data is missing or invalid: \(resources.joined(separator: ", "))"
            }
        }
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LoadError)
    }

    private struct Corpus {
        let tree: [String: Any]
        let index: [[String: String]]
        let contents: [String: [[String: String]]]
        let media: [[String: Any]]
        let chapterMap: [String: [String]]
        let allPaths: [String]
    }
    
    // Loading is serialized so multiple callers cannot partially overwrite the
    // singleton with different parses of the same corpus.
    private let loadQueue = DispatchQueue(label: "com.dhyana.lengyan.book-loader", qos: .userInitiated)
    private let loadQueueKey = DispatchSpecificKey<Void>()
    private let stateLock = NSLock()
    private let resourceDataProvider: ResourceDataProvider
    private var storedLoadState: LoadState = .idle
    private var storedCorpus: Corpus?

    // All five views come from one immutable corpus replacement. Readers can
    // therefore observe either the old complete value or the new complete
    // value, never a partially published mix of JSON resources.
    var tree: [String: Any]? { corpusValue(\.tree) }
    var index: [[String: String]]? { corpusValue(\.index) }
    var contents: [String: [[String: String]]]? { corpusValue(\.contents) }
    var media: [[String: Any]]? { corpusValue(\.media) }
    var chapterMap: [String: [String]]? { corpusValue(\.chapterMap) }

    var loadState: LoadState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedLoadState
    }

    var loaded: Bool { loadState == .loaded }
    //Chinsese lanaguage style: simplified or traditional, based on system locale, default simplified
    var isSimplifiedChinese = true

    // Init language based on system locale. Tests can inject resource bytes so
    // missing/corrupt bundles and retry behavior are exercised deterministically.
    override convenience init() {
        self.init(resourceDataProvider: Book.bundledResourceData)
    }

    init(resourceDataProvider: @escaping ResourceDataProvider) {
        self.resourceDataProvider = resourceDataProvider
        super.init()
        loadQueue.setSpecific(key: loadQueueKey, value: ())
        configureLanguage()
    }

    private func configureLanguage() {
        // 优先响应 -AppleLanguages 启动参数（fastlane snapshot / UITest 通过 app.launchArguments 注入）
        let launchArgs = ProcessInfo.processInfo.arguments
        if let idx = launchArgs.firstIndex(of: "-AppleLanguages"), idx + 1 < launchArgs.count {
            let lang = launchArgs[idx + 1].trimmingCharacters(in: CharacterSet(charactersIn: "(\"' "))
            if lang.hasPrefix("zh-Hant") || lang.hasPrefix("zh-TW") || lang.hasPrefix("zh-HK") {
                isSimplifiedChinese = false
                return
            }
            if lang.hasPrefix("zh-Hans") || lang.hasPrefix("zh-CN") {
                isSimplifiedChinese = true
                return
            }
        }
        // 兜底：系统首选语言
        for lan in NSLocale.preferredLanguages {
            if lan.hasPrefix("zh-") {
                if lan.hasPrefix("zh-Hant") || lan.hasPrefix("zh-TW") || lan.hasPrefix("zh-HK") {
                    isSimplifiedChinese = false
                }
                break
            }
        }
    }

    private static func bundledResourceData(
        _ resourceName: String,
        _ fileExtension: String
    ) -> Foundation.Data? {
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: fileExtension
        ) else { return nil }
        return try? Foundation.Data(contentsOf: url)
    }
    
    //MARK: Loading data from json files

    /// Synchronously loads the bundled corpus. The completion runs on the
    /// caller's thread and receives an explicit success/failure result.
    @discardableResult
    func loadDataSyncWithCompletionHandler(
        _ handler: (Result<Void, LoadError>) -> Void
    ) -> Result<Void, LoadError> {
        let result = loadCorpusIfNeeded()
        handler(result)
        return result
    }

    /// Asynchronously loads once and always completes on the main queue.
    /// Calls arriving while a load is queued are serialized and reuse its
    /// published result instead of parsing and mutating shared state in parallel.
    func loadDataWithCompletionHandler(
        _ handler: @escaping (Result<Void, LoadError>) -> Void
    ) {
        loadQueue.async {
            let result = self.loadCorpusIfNeededOnLoadQueue()
            DispatchQueue.main.async {
                handler(result)
            }
        }
    }

    /// Explicit retry entry point for a genuine resource failure. Normal calls
    /// return the recorded failure rather than repeatedly re-reading the bundle.
    func retryLoading(_ handler: @escaping (Result<Void, LoadError>) -> Void) {
        loadQueue.async {
            let result: Result<Void, LoadError>
            switch self.loadState {
            case .loaded:
                result = .success(())
            case .failed:
                self.setLoadState(.idle)
                result = self.loadCorpusIfNeededOnLoadQueue()
            case .idle, .loading:
                result = self.loadCorpusIfNeededOnLoadQueue()
            }
            DispatchQueue.main.async {
                handler(result)
            }
        }
    }

    private func loadCorpusIfNeeded() -> Result<Void, LoadError> {
        if DispatchQueue.getSpecific(key: loadQueueKey) != nil {
            return loadCorpusIfNeededOnLoadQueue()
        }
        return loadQueue.sync {
            loadCorpusIfNeededOnLoadQueue()
        }
    }

    private func loadCorpusIfNeededOnLoadQueue() -> Result<Void, LoadError> {
        switch loadState {
        case .loaded:
            return .success(())
        case let .failed(error):
            return .failure(error)
        case .idle, .loading:
            break
        }

        setLoadState(.loading)
        let result = parseBundledCorpus()
        switch result {
        case let .success(corpus):
            publishLoaded(corpus)
            return .success(())
        case let .failure(error):
            publishFailure(error)
            print("⚠️ \(error.localizedDescription)")
            return .failure(error)
        }
    }

    private func parseBundledCorpus() -> Result<Corpus, LoadError> {
        var path = "data/"
        if self.isSimplifiedChinese {
            path = "data/simplified/"
        }

        var missingResources: [String] = []

        let parsedTree: [String: Any]
        if let data = resourceDataProvider(path + "lengyanjing-index-tree", "json"),
           let value = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
           let tree = value as? [String: Any],
           !tree.isEmpty {
            parsedTree = tree
        } else {
            parsedTree = [:]
            missingResources.append("index tree")
        }

        let parsedContents: [String: [[String: String]]]
        if let contentData = resourceDataProvider(path + "lengyanjing-content", "json"),
           let value = try? JSONSerialization.jsonObject(with: contentData, options: .allowFragments),
           let contents = value as? [String: [[String: String]]],
           !contents.isEmpty {
            parsedContents = contents
        } else {
            parsedContents = [:]
            missingResources.append("content")
        }

        let parsedIndex: [[String: String]]
        if let indexData = resourceDataProvider(path + "lengyanjing-index", "json"),
           let value = try? JSONSerialization.jsonObject(with: indexData, options: .allowFragments),
           let index = value as? [[String: String]],
           !index.isEmpty {
            parsedIndex = index
        } else {
            parsedIndex = []
            missingResources.append("index")
        }

        let parsedMedia: [[String: Any]]
        if let mediaData = resourceDataProvider(path + "lengyanjing-media", "json"),
           let value = try? JSONSerialization.jsonObject(with: mediaData, options: .allowFragments),
           let media = value as? [[String: Any]],
           media.allSatisfy({ item in
               guard let files = item["files"] as? [String],
                     let names = item["names"] as? [String],
                     item["name"] is String,
                     item["extension"] is String else { return false }
               return !files.isEmpty && files.count == names.count
           }) {
            // Audio metadata is optional for the core reading corpus. Publishing
            // an empty array keeps reading/search usable in a degraded build.
            parsedMedia = media
        } else {
            parsedMedia = []
            print("⚠️ Optional Book resource unavailable: media")
        }

        let parsedChapterMap: [String: [String]]
        if let chapterMapData = resourceDataProvider("data/lengyanjing-chapter-map", "json"),
           let value = try? JSONSerialization.jsonObject(with: chapterMapData, options: .allowFragments),
           let chapterMap = value as? [String: [String]],
           !chapterMap.isEmpty {
            parsedChapterMap = chapterMap
        } else {
            parsedChapterMap = [:]
            missingResources.append("chapter map")
        }

        if !missingResources.isEmpty {
            return .failure(.missingOrInvalidResources(missingResources))
        }

        let treePaths = collectValidatedTreePaths(from: parsedTree)
        if treePaths == nil {
            missingResources.append("index tree structure")
        }
        if parsedIndex.contains(where: {
            guard let path = $0["path"], let name = $0["name"] else { return true }
            return name.isEmpty || !(treePaths?.contains(path) ?? false)
        }) {
            missingResources.append("index structure")
        }
        if parsedContents.contains(where: { path, entries in
            !((treePaths?.contains(path) ?? false)
                && !entries.isEmpty
                && entries.allSatisfy {
                    guard let type = $0["type"], let content = $0["content"] else { return false }
                    return !type.isEmpty && !content.isEmpty
                })
        }) {
            missingResources.append("content structure")
        }
        let expectedChapterKeys = Set((1...10).map(String.init))
        if Set(parsedChapterMap.keys) != expectedChapterKeys
            || parsedChapterMap.values.contains(where: { paths in
                paths.isEmpty || paths.contains(where: { !(treePaths?.contains($0) ?? false) })
            }) {
            missingResources.append("chapter map structure")
        }
        if !missingResources.isEmpty {
            return .failure(.missingOrInvalidResources(missingResources))
        }

        return .success(Corpus(
            tree: parsedTree,
            index: parsedIndex,
            contents: parsedContents,
            media: parsedMedia,
            chapterMap: parsedChapterMap,
            allPaths: parsedIndex.compactMap { $0["path"] }
        ))
    }

    private func collectValidatedTreePaths(from node: [String: Any]) -> Set<String>? {
        guard let id = node["id"] as? String, !id.isEmpty,
              let name = node["name"] as? String, !name.isEmpty,
              let path = node["path"] as? String else { return nil }

        var paths: Set<String> = [path]
        if let rawChildren = node["children"] {
            guard let children = rawChildren as? [[String: Any]], !children.isEmpty else { return nil }
            for child in children {
                guard let childPaths = collectValidatedTreePaths(from: child),
                      paths.isDisjoint(with: childPaths) else { return nil }
                paths.formUnion(childPaths)
            }
        }
        return paths
    }

    private func corpusValue<Value>(_ keyPath: KeyPath<Corpus, Value>) -> Value? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedCorpus?[keyPath: keyPath]
    }

    private func publishLoaded(_ corpus: Corpus) {
        stateLock.lock()
        storedCorpus = corpus
        storedLoadState = .loaded
        stateLock.unlock()
    }

    private func publishFailure(_ error: LoadError) {
        stateLock.lock()
        storedCorpus = nil
        storedLoadState = .failed(error)
        stateLock.unlock()
    }

    private func setLoadState(_ state: LoadState) {
        stateLock.lock()
        storedLoadState = state
        stateLock.unlock()
    }
    
    //MARK: Path, item and relations in the tree
    func getAllPaths()->[String]{
        corpusValue(\.allPaths) ?? []
    }

    func getKeyItems() ->[[String]]{
        return KEY_PATHS.map { (path) -> [String] in
            let name = Book.shared.itemOfPath(path)["name"] as? String ?? ""
            return [path, name]
        }
    }

    func itemOfPath(_ path:String ) -> [String:Any] {
        guard let tree = self.tree else { return [:] }
        let rootPath = tree["path"] as? String
        if path.isEmpty || path == "/" || path == rootPath {
            return tree
        }
        var node: [String:Any]? = tree
        for id in path.components(separatedBy: "/") {
            guard let current = node else { break }
            if id.isEmpty { continue }
            guard let children = current["children"] as? [[String:Any]] else { continue }
            node = children.first(where: { ($0["id"] as? String) == id })
        }
        return node ?? [:]
    }

    /// Returns true only for a non-root corpus node whose canonical path is an
    /// exact match. The root aliases (`""` and `"/"`) are useful for browsing
    /// the full outline, but are never a meaningful persisted resume target.
    func isValidResumePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              path != "/",
              let resolvedPath = itemOfPath(path)["path"] as? String,
              !resolvedPath.isEmpty,
              resolvedPath != "/" else {
            return false
        }
        return resolvedPath == path
    }

    /// Compatibility name for callers that have not yet adopted the more
    /// precise resume-path terminology.
    func isValidReadingPath(_ path: String) -> Bool {
        isValidResumePath(path)
    }

    func parentOfItem(_ item:[String:Any]) -> [String:Any]? {
        guard let path = item["path"] as? String else { return nil }
        if path.isEmpty || path == "/" {
            return nil
        }
        guard let lastSlash = path.lastIndexOf("/") else {
            return self.itemOfPath("")
        }
        let parentPath = (path as NSString).substring(to: lastSlash)
        return self.itemOfPath(parentPath)
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
            attributes: [NSAttributedString.Key.font: parentFont])

        // Divider "之" uses smaller caption style
        let dividerFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
        let attrString2 = NSMutableAttributedString(
            string: (parent == nil ? "" : " 之 "),
            attributes: [NSAttributedString.Key.font: dividerFont])

        // Title uses navigation title style but with lighter weight and more letter spacing for elegance
        let titleFont = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular)
        let attrString1 = NSMutableAttributedString(
            string: title as String,
            attributes: [NSAttributedString.Key.font: titleFont, NSAttributedString.Key.kern: 2.0])

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
            attributes: [NSAttributedString.Key.font: font,
                         NSAttributedString.Key.paragraphStyle : paragraphStyle])

        // Divider "之" uses caption style
        let dividerFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .regular)
        let attrString2 = NSMutableAttributedString(
            string: parent == nil ? "" : " 之",
            attributes: [NSAttributedString.Key.font: dividerFont, NSAttributedString.Key.paragraphStyle : paragraphStyle])

        let paragraphStyle2 = NSMutableParagraphStyle()
        paragraphStyle2.alignment = .center
        paragraphStyle2.paragraphSpacingBefore = 2 // 稍微缩短主副标距离，防止两行文字顶破导航栏上下边缘

        // Title uses navigation title style - lighter, airier
        let titleFont = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular)
        let titleText = parentTitle.count > 15 ? " " + title : "\n" + title
        let attrString1 = NSMutableAttributedString(
            string: titleText,
            attributes: [
                NSAttributedString.Key.font: titleFont,
                NSAttributedString.Key.paragraphStyle : paragraphStyle2,
                NSAttributedString.Key.kern: 3.0 // 典雅宽绰的字间距
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
            pAttr.addAttribute(NSAttributedString.Key.kern, value: 1.0, range: NSRange(location: 0, length: pAttr.length))
            
            // 将辅助介词“之”单独缩小及减淡颜色
            let zhiRange = (pText as NSString).range(of: " 之")
            if zhiRange.location != NSNotFound {
                let zhiFont = SutraTypographyManager.shared.uiFont(for: .sutraCaption, weight: .light).withSize(10)
                pAttr.addAttribute(NSAttributedString.Key.font, value: zhiFont, range: zhiRange)
                // 采用与主标题相同的主色，仅依靠字号大小差异来区分，保证绝对的可读性
                pAttr.addAttribute(NSAttributedString.Key.foregroundColor, value: SutraDesignTokens.shared.color(for: .textPrimary), range: zhiRange)
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
            attr.addAttribute(NSAttributedString.Key.kern, value: 3.0, range: NSRange(location: 0, length: attr.length))
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
            attributes: [NSAttributedString.Key.font: itemFont])

        let attrString2 = NSMutableAttributedString(
            string: chapterLabel,
            attributes: [NSAttributedString.Key.font: noteFont,
                         NSAttributedString.Key.foregroundColor: SutraDesignTokens.shared.color(for: .textSecondary)])

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
        pStyle.maximumLineHeight = 80.0       // 配合更大行高
        pStyle.minimumLineHeight = 10.0

        pStyle.paragraphSpacing = 24          // 段落间重现古卷的留白呼吸
        pStyle.firstLineHeadIndent = font.pointSize * 2.0 // 精确的首行二字缩进

        let pAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.paragraphStyle: pStyle,
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.kern: 1.5   // 文字呼吸感
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
            guard let path = item["path"] as? String else { return "" }
            let content = Book.shared.contents?[path]
            if let content {
                var length = 0
                for c in content {
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

    func getChapterOfPath(_ path: String) -> Int? {
        guard let chapterMap = chapterMap else { return nil }
        // 1. Try exact match first
        for (chapterKey, paths) in chapterMap {
            if paths.contains(path) {
                if let chapterInt = Int(chapterKey) {
                    return chapterInt - 1
                }
            }
        }
        // 2. Try prefix matching to support deeply nested bookmarked paths
        for (chapterKey, paths) in chapterMap {
            for p in paths {
                if path == p || path.hasPrefix(p + "/") {
                    if let chapterInt = Int(chapterKey) {
                        return chapterInt - 1
                    }
                }
            }
        }
        return nil
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
            
        debugLog("Could not getBelongingKeyPagePath for path \(path)")
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
