//
//  SutraPageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

protocol SutraPage {
    var pageIndex:Int {get set}
}

func UIColorFromRGB(_ rgbValue: UInt) -> UIColor {
    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

class SutraTableViewCell: UITableViewCell {
    
    @IBOutlet weak var textView: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

class SutraPageContentViewController: UITableViewController, SutraPage{
    
    internal var pageIndex = 0;
    var meta:[String:Any] = [:];
    var contents:[[String:String]] = [];
    var path:String = ""
    
    fileprivate var showHeader = true;
    let toolbar = UIToolbar();
    var sutraFont:UIFont? = nil, comentFont:UIFont? = nil, indexFont:UIFont? = nil;
    override func viewDidLoad() {
        super.viewDidLoad()
        meta = (Book.shared.index?[pageIndex])!;
        path = meta["path"] as! String;
        let content = Book.shared.contents?[path];
        if(content != nil){
            contents = content ?? []
            self.tableView.rowHeight = UITableViewAutomaticDimension
        } else {
            meta = Book.shared.itemOfPath(path)
            for child in (meta["children"] as! NSArray as! [[String:Any]]) {
                let name:String = child["name"] as! String
                contents.append(["type":"index", "content": "• " + name])
            }
            self.tableView.rowHeight = 44;
        }
        
        self.tableView.estimatedRowHeight = 100;
        self.tableView.separatorStyle = .none;
        self.tableView.allowsSelection = false;
        self.initFonts();
    }
    func initFonts(){
        comentFont =  UIFont.preferredFont(forTextStyle: UIFontTextStyle.body);
        if comentFont!.pointSize < 15 {
            comentFont = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.regular)
        }
        
        indexFont = UIFont.systemFont(ofSize: comentFont!.pointSize    , weight: UIFont.Weight.light);
        
        sutraFont = UIFont.systemFont(ofSize:  comentFont!.pointSize + 2, weight:UIFont.Weight.semibold)
        
    }
    
    
    func titleWasTapped (){
        print("titleWasTapped");
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.scrollsToTop = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.scrollsToTop = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath as NSIndexPath).row == contents.count {
            return 100;
        }else{
            return UITableViewAutomaticDimension;
        }
        
    }
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return contents.count + 1
    }
    
    func paragraphOf(text:String, font:UIFont?) -> NSAttributedString{
    let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineHeightMultiple = 1.6
    paragraphStyle.maximumLineHeight = 40.0
    paragraphStyle.minimumLineHeight = 10.0
    
    let attributes = font == nil ? [NSAttributedStringKey.paragraphStyle: paragraphStyle]
        :  [NSAttributedStringKey.font: font!, NSAttributedStringKey.paragraphStyle: paragraphStyle]
        
   return NSAttributedString(string:text, attributes: attributes)
    
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath as NSIndexPath).row == contents.count {
            return self.actionRow();
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SutraTableViewCell", for: indexPath) as! SutraTableViewCell
        cell.textView.backgroundColor = UIColor.clear
        
        let p = contents[(indexPath as NSIndexPath).row] as NSDictionary as! [String:String];
        
        var font:UIFont?
        if p["type"] == "sutra" {
            font = sutraFont
            cell.textView.font = font
            cell.textView.textColor = UIColor.darkText
            cell.backgroundColor = UIColor.clear
        } else if p["type"] == "index" {
            font = indexFont
            cell.textView.textColor = UIColor.black
            cell.backgroundColor = UIColor.clear
            
        }  else {
            font = comentFont;
            cell.textView.textColor = UIColor(red: 33/255, green: 33/255, blue: 33/255, alpha: 1)
            cell.backgroundColor = UIColor.clear
        }
        
        cell.textView.attributedText = paragraphOf(text: p["content"]!, font: font)

        return cell
    }
    
    func actionRow() -> UITableViewCell{
        if (navigationController?.isNavigationBarHidden ?? true){
            return UITableViewCell()
        }
        let actionBtn = UIBarButtonItem.init(image: UIImage.init(named: "share_18pt"), style: .plain, target: self, action: #selector(share(sender:)))
        
        let pureSutraBtn = UIBarButtonItem.init(image: UIImage.init(named: "sutra"), style: .plain, target: self, action: #selector(SutraPageContentViewController.pureSutra))
        
        let leftBtn = UIBarButtonItem.init(customView: UIImageView.init(image: UIImage.init(named: "ic_chevron_left_18pt")?.withRenderingMode(.alwaysTemplate)));
        let rightBtn = UIBarButtonItem.init(customView: UIImageView.init(image: UIImage.init(named: "ic_chevron_right_18pt")?.withRenderingMode(.alwaysTemplate)));
        leftBtn.customView?.tintColor = UIColor.lightGray
        rightBtn.customView?.tintColor = UIColor.lightGray
        
        
        let space44 = UIBarButtonItem.init(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        space44.width = 44;
        let spaceFlexible = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.tintColor = UIColor.lightGray
        toolbar.frame = CGRect(x: 0, y: 20, width: tableView.frame.size.width, height: 24);
        toolbar.isHidden = false;
        if meta["children"] != nil {
            toolbar.setItems([leftBtn, spaceFlexible, pureSutraBtn, spaceFlexible, actionBtn, spaceFlexible, rightBtn], animated: false)
        } else {
            toolbar.setItems([leftBtn, spaceFlexible, actionBtn, spaceFlexible, rightBtn], animated: false)
        }
        toolbar.backgroundColor = UIColor.white
        toolbar.barTintColor = UIColor.white
        let cell = UITableViewCell()
        let space = UIView(frame:CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 20));
        cell.addSubview(space)
        cell.addSubview(toolbar)
        return cell;
        
    }
    
    func toggleLike() {
        if Prefers.shared.isLike(path) {
            Prefers.shared.unlike(path)
            toolbar.items![2].tintColor = UIColor.lightGray
        } else {
            Prefers.shared.like(path)
            toolbar.items![2].tintColor = view.tintColor
        }
    }
    
    @objc func pureSutra(){
        
        let sutraVC = SutraPurePageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
        sutraVC.path = path;
        
        self.navigationController?.pushViewController(sutraVC, animated: true)
    }
    
    @objc func share(sender:UIBarButtonItem) {
        var shareContents = [String]()
        let bookTitle = NSLocalizedString("lengyan_book_title", comment: "《楞嚴經》")
        if meta["children"] == nil {
            var hasTitlePrefix:Bool = false;
            for c in contents {
                if c["type"] == "sutra" {
                    if !hasTitlePrefix {
                        shareContents.append(bookTitle)
                        hasTitlePrefix = true;
                    }
                    shareContents.append(c["content"]!)
                }
            }
        } else {
            
            shareContents.append(bookTitle + "之「" + (meta["name"] as! String) + "」")
            shareContents.append(Book.shared.getSutra(meta))
        }
        
        let activityViewController = UIActivityViewController(activityItems:[shareContents.joined(separator: "\n")], applicationActivities: nil)
        if let presenter = activityViewController.popoverPresentationController {
            presenter.barButtonItem = sender;
        }
        present(activityViewController, animated: true, completion: {})
    }
}
