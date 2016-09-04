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

class SutraPageContentViewController: UITableViewController, SutraPage{

    internal var pageIndex = 0;
    var meta:[String:Any] = [:];
    var contents:[[String:String]] = [];
    var path:String = ""

    fileprivate var showHeader = true;
    let toobar = UIToolbar();

    override func viewDidLoad() {
        super.viewDidLoad()
        meta = (Book.data.index?[pageIndex])!;
        path = meta["path"] as! String;
        let content = Book.data.contents?[path];
        if(content != nil){
            contents = content ?? []
            self.tableView.rowHeight = UITableViewAutomaticDimension
        } else {
            meta = Book.data.itemOfPath(path)
            for child in (meta["children"] as! NSArray as! [[String:Any]]) {
                let name:String = child["name"] as! String
                contents.append(["type":"index", "content": "• " + name])
            }
            self.tableView.rowHeight = 44;
        }
        
        self.tableView.estimatedRowHeight = 100;
        self.tableView.separatorStyle = .none;
        self.tableView.allowsSelection = false;
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
        return UITableViewAutomaticDimension;

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
    

     override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath as NSIndexPath).row == contents.count {
            return self.actionRow();
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SutraTableViewCell", for: indexPath) as! SutraTableViewCell
        cell.textView.backgroundColor = UIColor.clear
        
        let p = contents[(indexPath as NSIndexPath).row] as NSDictionary as! [String:String];
        
        cell.textView.text = p["content"];
        if p["type"] == "sutra" {
            cell.textView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline);
            cell.textView.textColor = UIColor.darkText
            cell.backgroundColor = UIColor.clear
        } else if p["type"] == "index" {
            cell.textView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body);
            cell.textView.textColor = UIColor.black
            cell.backgroundColor = UIColor.clear

//            cell.backgroundColor = UIColor.groupTableViewBackgroundColor()
        }  else {
            var font =  UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote);
            if font.pointSize < 13 {
                font = UIFont.systemFont(ofSize: 13, weight: UIFontWeightRegular)
            }
            cell.textView.font = font;
            cell.textView.textColor = UIColor(red: 33/255, green: 33/255, blue: 33/255, alpha: 1)
            cell.backgroundColor = UIColor.clear

        }
        return cell
     }
    
    func actionRow() -> UITableViewCell{
        //action group
//        let actions = SutraActionGroupView();
//        actions.path = meta["path"] as? String
//        actions.frame = CGRectMake(0, 0, tableView.frame.size.width, 50);
//        actions.backgroundColor = UIColor.whiteColor()
        
//        let actionBtn = UIBarButtonItem.init(barButtonSystemItem: .Action, target: self, action: nil);
        
//        let composeBtn = UIBarButtonItem.init(barButtonSystemItem: .Compose, target: self, action: nil);
        
//        let composeBtn = UIBarButtonItem.init(image: UIImage.init(named: "comment_outline_18pt"), style: .Plain, target: self, action: #selector(SutraPageContentViewController.comment))
        
        let actionBtn = UIBarButtonItem.init(image: UIImage.init(named: "share_18pt"), style: .plain, target: self, action: #selector(SutraPageContentViewController.share))

        let likeBtn = UIBarButtonItem.init(image: UIImage.init(named: "ic_star_border_18pt"), style: .plain, target: self, action: #selector(SutraPageContentViewController.toggleLike))
        
        if Data.shared.isLike(path) {
            likeBtn.tintColor = view.tintColor
        }
       
        let pureSutraBtn = UIBarButtonItem.init(image: UIImage.init(named: "sutra"), style: .plain, target: self, action: #selector(SutraPageContentViewController.pureSutra))

        let leftBtn = UIBarButtonItem.init(customView: UIImageView.init(image: UIImage.init(named: "ic_chevron_left_18pt")?.withRenderingMode(.alwaysTemplate)));
        let rightBtn = UIBarButtonItem.init(customView: UIImageView.init(image: UIImage.init(named: "ic_chevron_right_18pt")?.withRenderingMode(.alwaysTemplate)));
        leftBtn.customView?.tintColor = UIColor.lightGray
        rightBtn.customView?.tintColor = UIColor.lightGray

        
        let space44 = UIBarButtonItem.init(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        space44.width = 44;
        let spaceFlexible = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
//        space.width = 44;
//        starBtn.setTitleTextAttributes([NSFontAttributeName : UIFont.systemFontOfSize(22)], forState: .Normal)

//        let btnInsets = UIEdgeInsetsMake(-20, 0.0, 0, 0.0)
//        likeBtn.imageInsets = btnInsets
//        actionBtn.imageInsets = btnInsets
//        pureSutraBtn.imageInsets = btnInsets
//        leftBtn.imageInsets = btnInsets
//        rightBtn.imageInsets = btnInsets
//        composeBtn.imageInsets = btnInsets
        
        toobar.tintColor = UIColor.lightGray
        toobar.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 60);
        toobar.isHidden = false;
//        toobar.backgroundColor = UIColor.groupTableViewBackgroundColor()
        if meta["children"] != nil {
            toobar.setItems([leftBtn, spaceFlexible, likeBtn, spaceFlexible, pureSutraBtn, spaceFlexible, actionBtn, spaceFlexible, rightBtn], animated: false)
        } else {
            toobar.setItems([leftBtn, spaceFlexible, likeBtn, spaceFlexible, actionBtn, spaceFlexible, rightBtn], animated: false)
        }
        toobar.backgroundColor = UIColor.white
        toobar.barTintColor = UIColor.white
        let cell = UITableViewCell()
        cell.addSubview(toobar)
        return cell;
        //todo add a button to read pure sutra 
        //todo add a tab to show started sutra
        
    }
    
    func toggleLike() {
        if Data.shared.isLike(path) {
            Data.shared.unlike(path)
            toobar.items![2].tintColor = UIColor.lightGray
        } else {
            Data.shared.like(path)
            toobar.items![2].tintColor = view.tintColor
        }
    }
    
    func pureSutra(){
        
//        let sutraVC = SutraPurePageViewController.init( transitionStyle:.PageCurl, navigationOrientation:.Horizontal, options: .None)
        let sutraVC = SutraPurePageContentViewController.init();
        sutraVC.item = meta;
        
//        let sutraVC:SutraBookViewController = self.storyboard!.instantiateViewControllerWithIdentifier("SutraBookViewController") as! SutraBookViewController
//        sutraVC.initialRow = self.pageIndex
        
        let navVC = UINavigationController.init(rootViewController: sutraVC);
        self.navigationController?.present(navVC, animated: true, completion: nil)
    }
    
    func share() {
        //todo attribute string
        var shareContents = [String]()
        if meta["children"] == nil {
            var hasTitlePrefix:Bool = false;
            var hasCommentaryPrefix:Bool = false;
            for c in contents {
                if c["type"] == "sutra" {
                    if !hasTitlePrefix {
                        shareContents.append("《楞嚴經》")
                        hasTitlePrefix = true;
                    }
                   shareContents.append(c["content"]!)
                } else  if c["type"] == "commentary" {
                    if !hasCommentaryPrefix {
                        shareContents.append("\n「宣化上人講解」")
                        hasCommentaryPrefix = true;
                    }
                    shareContents.append(c["content"]!)
                }
            }
        } else {
            shareContents.append("《楞嚴經》之「" + (meta["name"] as! String) + "」")
            shareContents.append(Book.data.getSutra(meta))
        }
        let activityViewController = UIActivityViewController(activityItems:[shareContents.joined(separator: "\n")], applicationActivities: nil)
        present(activityViewController, animated: true, completion: {})
    }
    
//
//    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return showHeader ? 50.0 : 0;
//    }
    
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
     if editingStyle == .Delete {
     // Delete the row from the data source
     tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
     } else if editingStyle == .Insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
