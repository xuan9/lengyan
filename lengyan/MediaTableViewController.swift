//
//  MediaTableViewController.swift
//  lengyan
//
//  Created by Xuan on 16/8/4.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class MediaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var footer: UIView!

    internal var initialRow = 0;
    
    var media:[[String:Any]] = []
    private var player:AVAudioPlayer? = nil;
    
    private var tagStatus:[String:Int8] = [:]
    private var wantedTags:[String:Int8] = [:]
    private var playingName:String = "";
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.contentInset = UIEdgeInsetsMake(40.0, 0.0, 0, 0)
        automaticallyAdjustsScrollViewInsets = true
        tableView.dataSource = self
        tableView.delegate = self
        self.setTitleBar()
        
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.media = Book.data.media!
            self.media.forEach({ (
                group) in
                let list = group["files"] as! [String];
                list.forEach({( file) in
                    self.getTagStatus(tag: file){available in
                    }
                })
            })

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
        return self.media.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if( self.media.isEmpty){
            return 0
        } else {
            let list = self.media[section]["files"] as! [String];
            return list.count;
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        return 40;
    }
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let text:String = self.media[section]["name"] as! String
        let cell = tableView.dequeueReusableCell(withIdentifier: "Media-Cell-Header") as! MediaTableViewCell
        cell.nameLabel?.text = text;
        return cell;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = self.media[indexPath.section];
        let files = group["files"] as! [String]
        var name = files[indexPath.row]

        let isDownloaded = tagStatus[name] == 2;
        let identifier =  isDownloaded ? "Media-Cell" : "Media-Cell-Download"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MediaTableViewCell
        
        if(tagStatus[name]==2){
            //"Downloaded"
            cell.nameLabel.textColor=UIColor.darkText
        }else  if(tagStatus[name]==1){
            cell.nameLabel.textColor=UIColor.darkGray
            name = name + " -  Downloading"
        } else {
            cell.nameLabel.textColor = UIColor.darkGray
        }
        
        cell.nameLabel?.text =  name;
        return cell;
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
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        let group = self.media[indexPath.section];
        let files = group["files"] as! [String]
        let tag = files[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath) as! MediaTableViewCell
        
        if(tagStatus[tag]==0 || tagStatus[tag]==nil){
            self.tagStatus[tag] = 1
//            self.tableView.reloadData()
            
            cell.nameLabel.textColor=UIColor.darkGray
            cell.nameLabel.text = tag + " -  Downloading"
        }
        
        let req = NSBundleResourceRequest(tags: [tag]);
        req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        req.beginAccessingResources{ error in
            if let error = error {
                self.tagStatus[tag]=0
                OperationQueue.main.addOperation {
                    cell.nameLabel.text = tag + " -  Downloading failed: " + ("Fail to access remote resources: \(error)")
                }
                self.handleDownloadingError(error as NSError)
            } else {
                self.tagStatus[tag]=2
                OperationQueue.main.addOperation {
                    self.tableView.reloadData()
                }
                print("indexPathForSelectedRow: \(self.tableView.indexPathForSelectedRow)")
                if(self.tableView.indexPathForSelectedRow==nil || self.tableView.indexPathForSelectedRow == indexPath){
                    self.play(req:req, tag:tag, name: tag)
                }
            }
        }
        
    }
    
    
    func getTagStatus(tag:String, completionHandler: @escaping (Bool) -> Swift.Void){
        let req = NSBundleResourceRequest(tags: [tag]);
        req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        req.conditionallyBeginAccessingResources(){available in
            if(available){
                self.tagStatus[tag] = 2
            } else {
            }
            completionHandler(available)
        }
    }
    
    func handleDownloadingError(_ error: NSError) {
        switch error.code{
        case NSBundleOnDemandResourceOutOfSpaceError:
            let message = "You don't have enough storage left to download this resource."
            self.alert(message: message)
        case NSBundleOnDemandResourceExceededMaximumSizeError:
            assert(false, "The bundle resource was too large.")
        case NSBundleOnDemandResourceInvalidTagError:
            assert(false, "The requested tag does not exist.")
        default:
            self.alert(message: error.description)
        }
    }
    
    func play(req:NSBundleResourceRequest, tag: String, name:String){
        
        let url = req.bundle.url(forResource:name, withExtension: "mp3")
        if (player != nil){
            if(player?.url == url){
                player?.pause()
            }else{
                player?.stop();
            }
        }
        do{
            playingName = name;
            self.tableView.reloadData();
            
            player = try AVAudioPlayer(contentsOf: url!,fileTypeHint: AVFileTypeMPEGLayer3)
            player?.numberOfLoops = -1
            self.player?.prepareToPlay()
            self.player?.play()
        } catch  {
            OperationQueue.main.addOperation {                                                        self.alert(message: "\(error)", title: "Fail to play \(name)");
            }
            
        }
    }

    func alert(message: String, title: String = "") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "好", style: .cancel) { action in
        })
        OperationQueue.main.addOperation {
            self.present(alert, animated: true, completion: nil)
        }
    }
}


class MediaTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool){
        super.setSelected(selected, animated: animated)
    }
}
