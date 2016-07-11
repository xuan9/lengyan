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

func UIColorFromRGB(rgbValue: UInt) -> UIColor {
    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

class SutraPageContentViewController: UITableViewController, SutraPage{

    internal var pageIndex = 0;
    var meta:[String:AnyObject] = [:];
    var contents:[[String:String]] = [];
    private var showHeader = true;
    let toobar = UIToolbar();

    override func viewDidLoad() {
        super.viewDidLoad()
        meta = (Book.data.index?[pageIndex])!;
        let path = meta["path"] as! String;
        let content = Book.data.contents?[path];
        if(content != nil){
            contents = content ?? []
            self.tableView.rowHeight = UITableViewAutomaticDimension
        } else {
            meta = Book.data.itemOfPath(path)
            for child in (meta["children"] as! NSArray) {
                let name:String = child["name"] as! String
                contents.append(["type":"index", "content": "• " + name])
            }
            self.tableView.rowHeight = 44;
        }
        
        self.tableView.estimatedRowHeight=100;
        self.tableView.separatorStyle = .None;
    }
    
    
    func titleWasTapped (){
        print("titleWasTapped");
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.scrollsToTop = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.scrollsToTop = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableViewAutomaticDimension;

    }
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return contents.count + 1
    }
    
    func treeView(treeView:RATreeView, willDisplayCell cell:UITableViewCell, forItem item:AnyObject){
        let level = treeView.levelForCell(cell) % 5;
        if (level == 0) {
            cell.backgroundColor = UIColorFromRGB(0xF7F7F7);
        } else if (level == 1) {
            cell.backgroundColor = UIColorFromRGB(0xD1EEFC);
        } else if (level == 2) {
            cell.backgroundColor = UIColorFromRGB(0xE0F8D8);
        }  else if (level == 3) {
            cell.backgroundColor = UIColorFromRGB(0xE0F8D8);
        }  else {
            cell.backgroundColor = UIColorFromRGB(0xE0F8D8);
        }
    }

     override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == contents.count {
            return self.actionRow();
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier("SutraTableViewCell", forIndexPath: indexPath) as! SutraTableViewCell
        cell.textView.backgroundColor = UIColor.clearColor()
        
        let p = contents[indexPath.row] as NSDictionary as! [String:String];
        
        cell.textView.text = p["content"];
        if p["type"] == "sutra" {
            cell.textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody);
            cell.textView.textColor = UIColor.darkTextColor()
            cell.backgroundColor = UIColor.clearColor()
        } else if p["type"] == "index" {
            cell.textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody);
            cell.textView.textColor = UIColor.blackColor()
            cell.backgroundColor = UIColor.clearColor()

//            cell.backgroundColor = UIColor.groupTableViewBackgroundColor()
        }  else {
            cell.textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote);
            cell.textView.textColor = UIColor(red: 33/255, green: 33/255, blue: 33/255, alpha: 1)
            cell.backgroundColor = UIColor.clearColor()

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
        
        let composeBtn = UIBarButtonItem.init(image: UIImage.init(named: "comment_outline_18pt"), style: .Plain, target: self, action: nil)
        
        let actionBtn = UIBarButtonItem.init(image: UIImage.init(named: "share_18pt"), style: .Plain, target: self, action: nil)

        let starBtn = UIBarButtonItem.init(image: UIImage.init(named: "like_outline_18pt"), style: .Plain, target: self, action: nil)

        
        let spaceEdge = UIBarButtonItem.init(barButtonSystemItem: .FixedSpace, target: nil, action: nil)
        spaceEdge.width = 22;
        let space = UIBarButtonItem.init(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
//        space.width = 44;
//        starBtn.setTitleTextAttributes([NSFontAttributeName : UIFont.systemFontOfSize(22)], forState: .Normal)

//        let toobar = UIToolbar();
        toobar.tintColor = UIColor.lightGrayColor()
        toobar.frame = CGRectMake(0, 0, tableView.frame.size.width, 40);
        toobar.hidden = false;
//        toobar.backgroundColor = UIColor.groupTableViewBackgroundColor()
        toobar.setItems([spaceEdge, starBtn, space,composeBtn, space, actionBtn,spaceEdge], animated: true)
        toobar.backgroundColor = UIColor.whiteColor()
        toobar.barTintColor = UIColor.whiteColor()
        let cell = UITableViewCell()
        cell.addSubview(toobar)
        return cell;
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
