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
    
    override func setSelected(_ selected: Bool, animated: Bool){
        super.setSelected(selected, animated: animated)
    }
}


class MediaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var footer: UIView!
    
    internal var initialRow = 0;
    
    var media:[[String:String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        tableView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 0, 0)
//        tableView.separatorInset = UIEdgeInsetsMake(10, 0.0, 10, 0)
        automaticallyAdjustsScrollViewInsets = true
        tableView.dataSource = self
        tableView.delegate = self
        self.setTitleBar()
        
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.media = Book.data.media!
            DispatchQueue.main.async{
                self.tableView.reloadData()
            }
        }
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
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"選擇", style: .plain, target: self, action: nil)
        self.title = "聽經"
    }
    
    // MARK: - Table view data source
    
     func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }
    
     func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return media.count
    }
     public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        return 40;
    }
     public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let text:String = section == 0 ? "屏東能淨協會讀誦" : "聆志居士讀誦" ;
        let cell = tableView.dequeueReusableCell(withIdentifier: "Media-Cell-Header") as! MediaTableViewCell
        cell.nameLabel?.text =  text;
        return cell;
    }
         
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let item = media[(indexPath as NSIndexPath).row];
//        let isAudio = indexPath.section == 1
        //let mediaName = isAudio ? item["audio"] : item["video"]
        let row = (indexPath as NSIndexPath).row;
        let isAudio = indexPath.section == 0;
        let isDownloaded = false;//todo check if resource file local available
        let identifier =  isDownloaded ? "Media-Cell" : "Media-Cell-Download"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MediaTableViewCell
        
        let name = media[row]["name"]!
        let text:String = row % 2 == 0 ? "• " +  name : "   " + name
        
        cell.nameLabel?.text =  text;
        
        return cell;
    }
    
     func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    // Override to support conditional editing of the table view.
     func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
     func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            //        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            //todo
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    
    
}
