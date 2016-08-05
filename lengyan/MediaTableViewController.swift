//
//  MediaTableViewController.swift
//  lengyan
//
//  Created by Xuan on 16/8/4.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation
import UIKit

class MediaTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var toolbar: UIToolbar!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(selected: Bool, animated: Bool){
        super.setSelected(selected, animated: animated)
    }
    
}


class MediaTableViewController: UITableViewController{
    
    internal var initialRow = 0;
    
    var media:[[String:String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 0, 0)
        tableView.separatorInset = UIEdgeInsetsMake(10, 0.0, 10, 0)
        
        self.setTitleBar()
        
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.media = Book.data.media!
            dispatch_async(dispatch_get_main_queue()){
                self.tableView.reloadData()
            }
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
    //
    //    override func viewWillAppear(animated: Bool) {
    //        super.viewWillAppear(animated)
    //    }
    //
    //    override func viewWillDisappear(animated: Bool) {
    //        super.viewWillDisappear(animated)
    //    }
    //
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setTitleBar() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"選擇", style: .Plain, target: self, action: nil)
        self.title = "聽經"
    }
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return media.count;
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let item = media[indexPath.row];
        let isAudio = indexPath.section == 1
        let mediaName = isAudio ? item["audio"] : item["video"]
        
        let isDownloaded = true;//todo check if resource file local available
        let identifier = isDownloaded ? (isAudio ? "Media-Cell-Audio" : "Media-Cell-Audio") : "Media-Cell-Download";
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier, forIndexPath: indexPath) as! MediaTableViewCell
        
        cell.nameLabel?.text = "• " + item["name"]!;
        
        return cell
    }
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? "屏東能淨協會朗讀" : "聆志居士讀誦 繁體字幕";
    }
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    
    
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            //        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            //todo
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    
    
}
