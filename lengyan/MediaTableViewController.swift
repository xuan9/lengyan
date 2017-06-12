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
    
    @IBOutlet weak var footerHightConstraint: NSLayoutConstraint!
    
    @IBOutlet var footLabel: UILabel!
    
    @IBOutlet var footPlayMode: UIButton!
    
    @IBOutlet var footPlayButton: UIButton!
    
    @IBOutlet var progressBar: UISlider!
    
    @IBOutlet var progressLabel: UILabel!
    
    @IBOutlet var durationLabel: UILabel!
    
    internal var initialRow = 0;
    
    var media:[[String:Any]] = []
    private var queuePlayer:AVQueuePlayer? = nil;
    
    private var tagStatus:[String:Int8] = [:]
    private var wantedTags:[String:Int8] = [:]
    var timer: Timer!
    private var playMode = -1;
    
    private var rReq:[String:NSBundleResourceRequest] = [:]
    private var lastPlayFile:[String]?
    private var isPlayingOnSlideBegan = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.contentInset = UIEdgeInsetsMake(40.0, 0.0, 0, 0)
        automaticallyAdjustsScrollViewInsets = true
        tableView.dataSource = self
        tableView.delegate = self
        self.setTitleBar()
        
        footPlayButton.addTarget(self, action: #selector(pressPlayButton(button:)), for: .touchUpInside)
        
        footPlayMode.addTarget(self, action: #selector(pressModeButton(button:)), for: .touchUpInside)
        
        progressBar.addTarget(self,action:#selector(progressBarChanged(slider:event:)),for:.valueChanged);

        self.playMode = Data.shared.lastPlayMode ?? -1

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                self.tableView.reloadData()
            })
            //reload last play status
//            DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
//                if self.lastPlayFile == nil {
//                    self.lastPlayFile = Data.shared.lastPlayFile;
//                    if self.lastPlayFile != nil {
//                        self.schedulePlayItems()
//                    }
//                    self.playMode = Data.shared.lastPlayMode ?? -1
//                    if self.playMode != -1 {
//                        self.schedulePlayItems()
//                    }
//                }
//            })
        }
        if lastPlayFile == nil  {
            footerHightConstraint.constant = 0
            footer.layoutIfNeeded()
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
        //        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"選擇", style: .plain, target: self, action: nil)
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
        let identifier =  isDownloaded ? "Media-Cell":"Media-Cell-Download"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MediaTableViewCell
        
        if(tagStatus[name]==2){
            //"Downloaded"
            cell.nameLabel.textColor=UIColor.darkText
        }else  if(tagStatus[name]==1){
            cell.nameLabel.textColor=UIColor.lightGray
            name = name + " -  正在下载..."
        } else {
            cell.nameLabel.textColor = UIColor.lightGray
        }
        
        cell.nameLabel?.text =  name;
        return cell;
    }
    
    // Override to support conditional editing of the table view.
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
//        let group = self.media[indexPath.section];
//        let files = group["files"] as! [String]
//        let tag = files[indexPath.row]
//        if( self.self.tagStatus[tag] != nil && self.tagStatus[tag]! > 0) {
//            return true;
//        }
        return false
    }
    
    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let group = self.media[indexPath.section];
            let files = group["files"] as! [String]
            let tag = files[indexPath.row]
            
            if( self.rReq[tag] != nil) {
                if self.lastPlayFile != nil {
                    if (self.lastPlayFile?[0] == tag) {
                        self.pause()
                        self.lastPlayFile = nil;
                        self.schedulePlayItems()
                        footerHightConstraint.constant = 0
                        footer.layoutIfNeeded()
                    } else if playMode <= 0 {
                        self.pause()
                        self.schedulePlayItems()
                    }
                }
                
                self.rReq[tag]?.endAccessingResources()
                self.rReq[tag] = nil
                self.tagStatus[tag]=0
//                alert(message: "文件已经释放。若再次使用，可点击此文件再次下载。")
                self.tableView.reloadData()
            }
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        let group = self.media[indexPath.section];
        let files = group["files"] as! [String]
        let tag = files[indexPath.row]
        let ext =  group["extension"] as! String
//        let groupName = group["name"] as! String
        
        let cell = tableView.cellForRow(at: indexPath) as! MediaTableViewCell
        
        if(tagStatus[tag]==2){//available
            self.play(name: tag, ext:ext);
            return;
        }
        
        if( self.rReq[tag] != nil) {
            return;
        }
        
        if(tagStatus[tag]==0 || tagStatus[tag]==nil){
            self.tagStatus[tag] = 1
            cell.nameLabel.textColor=UIColor.lightGray
            cell.nameLabel.text = tag + " -  正在下载..."
        }
        
        let req = NSBundleResourceRequest(tags: [tag]);
        self.rReq[tag] = req
        req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        print("beginAccessingResources: \(tag)")
        req.beginAccessingResources{ error in
            print("beginAccessingResources done: \(tag), \(error)")
            if let error = error {
                self.tagStatus[tag]=0
                self.rReq[tag]?.endAccessingResources()
                self.rReq[tag] = nil
                OperationQueue.main.addOperation {
                    cell.nameLabel.text = tag + " -  下载失败" ;
                }
                self.handleDownloadingError(error as NSError)
            } else {
                self.tagStatus[tag]=2
                OperationQueue.main.addOperation {
                    self.tableView.reloadData()
                }
                if((self.tableView.indexPathForSelectedRow==nil || self.tableView.indexPathForSelectedRow == indexPath) ){
                    self.play(name: tag, ext:ext);
                }
            }
        }
        
    }
    
    func stopPlayerTimer() {
        if timer != nil && timer.isValid {
            timer.invalidate()
        }
    }
    func startPlayerTimer() {
        self.stopPlayerTimer()
        OperationQueue.main.addOperation {
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.runTimedCode), userInfo: nil, repeats: true)
        }
    }
    func isPlaying() -> Bool {
        return self.queuePlayer?.rate != 0
    }
    func play(){
        self.queuePlayer?.play()
        self.startPlayerTimer()
        
        OperationQueue.main.addOperation {
            self.footPlayButton.isSelected = true
        }
    }
    func pause() {
        self.stopPlayerTimer()
        self.queuePlayer?.pause()
        OperationQueue.main.addOperation {
            self.footPlayButton.isSelected = false
        }
    }
    func getTagStatus(tag:String, completionHandler: @escaping (Bool) -> Swift.Void){
        let req = NSBundleResourceRequest(tags: [tag]);
        req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        req.conditionallyBeginAccessingResources(){available in
            if(available){
                self.tagStatus[tag] = 2
                self.rReq[tag] = req
            } else {
            }
            completionHandler(available)
        }
    }
    
    func handleDownloadingError(_ error: NSError) {
        switch error.code{
        case NSBundleOnDemandResourceOutOfSpaceError:
            let message = "空间不足，下载失败"
            self.alert(message: message)
        case NSBundleOnDemandResourceExceededMaximumSizeError:
            self.alert(message: "程序错误，文件过大" )
        case NSBundleOnDemandResourceInvalidTagError:
            self.alert(message: "程序错误，文件不存在" )
        default:
            self.alert(message: error.description)
        }
    }
    
    func play(name:String, ext:String){
        DispatchQueue.global().async {
            OperationQueue.main.addOperation {
                self.footLabel.text = name
                self.tableView.reloadData();
            }
            
            let req:NSBundleResourceRequest = self.rReq[name]!
            let url = req.bundle.url(forResource:name, withExtension: ext)
            
            let playItem = AVPlayerItem(url:url!);
            if (self.queuePlayer == nil) {
                self.queuePlayer = AVQueuePlayer()
                self.queuePlayer!.addObserver(
                    self, forKeyPath:"currentItem", options:.initial, context:nil)
            }
            
            self.schedulePlayItems(newItem: playItem)
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey:Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "currentItem") {
            let item = self.queuePlayer?.currentItem;
            /*
            print( "play item: \(item)");
            
            if( item != nil) {
                let meta = item?.asset.metadata;
                meta?.forEach({ (m) in
                    print( "\(m.commonKey): \(m.stringValue)");
                })
            }
                */
            let file = getFileNameAndExtension(item: item)
            
            if file != nil {
                self.lastPlayFile = file
                Data.shared.lastPlayFile = file
            }
            
            OperationQueue.main.addOperation {
                if(item == nil){
                    self.durationLabel.text = ""
                    self.progressLabel.text = ""
                    self.progressLabel.text = ""
                } else {
                    self.progressLabel.text = ""
                    self.progressLabel.text = ""
                    self.footLabel.text = file![0]
                    self.footer.isHidden = false
                    if self.footerHightConstraint.constant == 0 {
                        self.footerHightConstraint.constant = 90
                        self.footer.layoutIfNeeded()
                        self.updatePlayModeIcon();
                    }
                }
                self.footPlayButton.isSelected = (item != nil && self.isPlaying());
            }
            
        }
    }
    
    func pressPlayButton(button: UIButton) {
        NSLog("play btn pressed! isSelected:\(button.isSelected)")
        if(!button.isSelected){
            self.footPlayButton.isSelected = true;
            if(self.queuePlayer?.currentItem != nil) {
                self.play()
            } else if(lastPlayFile != nil){
                self.play(name: lastPlayFile![0], ext: lastPlayFile![1])
            }
        } else {
            self.footPlayButton.isSelected = false;
            self.pause()
        }
    }
    
    func pressModeButton(button: UIButton) {
        self.showModeOptions()
    }
    
    func getLastPlayItem() -> AVPlayerItem? {
        if self.lastPlayFile != nil {
            let name = self.lastPlayFile![0], ext = self.lastPlayFile![0]
            let req:NSBundleResourceRequest? = self.rReq[name]
            if req != nil {
                let url = req?.bundle.url(forResource:name, withExtension: ext)
                if url != nil {
                    return AVPlayerItem(url:url!);
                }
            }
        }
        return nil
    }
    
    func progressBarChanged(slider: UISlider, event: UIEvent) {
        print("progress changed: \(slider.value) by event: \(event)")
        var playItem = self.queuePlayer?.currentItem
        if (playItem == nil ) {
            self.schedulePlayItems()
            playItem = self.queuePlayer?.currentItem
            if playItem == nil {
                print("no currentItem")
                return
            }
        }
        
        let duration = playItem!.duration
        if (duration.isNumeric) {
            let phase = event.allTouches?.first?.phase
            let seekTime = CMTimeMakeWithSeconds(Float64(slider.value.multiplied(by: Float(duration.seconds))) , duration.timescale );
            
            self.progressLabel.text = self.getMediaDisplayTime(seconds: Int(seekTime.seconds))
            
            if phase == UITouchPhase.began {
                self.isPlayingOnSlideBegan = self.isPlaying()
                if( phase == UITouchPhase.began && self.isPlayingOnSlideBegan){
                    self.pause()
                }
            } else if phase == UITouchPhase.ended || phase == UITouchPhase.cancelled {
                DispatchQueue.global(qos: .background).async {
                    self.queuePlayer?.seek(to: seekTime, toleranceBefore: kCMTimePositiveInfinity, toleranceAfter: kCMTimePositiveInfinity)
                    if self.isPlayingOnSlideBegan {
                        self.play()
                    }
                }
            }
        } else {
            print("invalid duration")
        }
    }
    
    func runTimedCode() {
        if (self.queuePlayer?.currentItem) != nil {
            let duration = self.queuePlayer!.currentItem!.duration
            var durationText = "", progressText = ""
            var progress:Float = 0;
            
            if(duration.isNumeric){
                let d = Int(duration.seconds);
                durationText = self.getMediaDisplayTime(seconds: d)
                if(self.queuePlayer!.currentTime().isNumeric){
                    progress = Float(self.queuePlayer!.currentTime().seconds.divided(by: duration.seconds))
                    let progressSeconds = Int((self.queuePlayer?.currentTime().seconds)!)
                    progressText = self.getMediaDisplayTime(seconds: progressSeconds)
                }
            }
                self.durationLabel.text = durationText
                self.progressLabel.text = progressText
                self.progressBar.value = progress
        }
    }
    func getMediaDisplayTime(seconds:Int)->String {
       return "\(String(format: "%02d", seconds / 60)):\(String(format: "%02d", seconds % 60))"
    }
    
    func getFileNameAndExtension(item:AVPlayerItem?)->[String]?{
        let url = (item?.asset as? AVURLAsset)?.url
        if url == nil {
            return nil
        }
        let file = url?.lastPathComponent;
        var ext = url?.pathExtension
        if (ext == nil) {
            ext = ""
        }
        let name = file!.substring(to:(file?.index((file?.endIndex)!, offsetBy: -((ext?.characters.count)! + 1)))!)
        return [name, ext!]
    }
    
    func schedulePlayItems(newItem:AVPlayerItem? = nil) {
        var currentItem = self.queuePlayer?.currentItem
        var file:[String]?;
        var startAt:CMTime? = currentItem != nil ? self.queuePlayer?.currentTime(): nil
        self.queuePlayer?.removeAllItems()

        if (newItem != nil ) {
            currentItem = newItem;
            file = getFileNameAndExtension(item: newItem)
            startAt = nil
        } else {
           file = lastPlayFile
        }
        
        if file == nil {
            print("no playing file found")
            return
        }
        
        var name = file![0], ext = file![1]
        
        if(name != nil) {
            if(self.playMode <= 0){
                var downloaded = NSMutableArray();
                var assets = NSMutableArray();
                tagStatus.forEach({ (k,v) in
                    if(v == 2) {
                        downloaded.add(k);
                    }
                })
                
                if name == nil && downloaded.count>0 {
                    name = downloaded.object(at: 0) as! String
                }
                
                var fullList:[String]?;
                var sorted = NSMutableArray();
                for group in media {
                    let files = group["files"] as! [String]
                    if files.contains(name) {
                        let index:Int = files.index(of: name)!
                        for i in index...(files.count-1) {
                            if downloaded.contains(files[i]) {
                                sorted.add(files[i])
                            }
                            
                        }
                        if(index>0){
                            for i in 0...(index-1){
                                if downloaded.contains(files[i]) {
                                    sorted.add(files[i])
                                }
                            }
                        }
                        break;
                    }
                }
                
                for tag in sorted {
                    let req = self.rReq["\(tag)"]
                    if( req != nil){
                        let url = req?.bundle.url(forResource:tag as? String, withExtension: ext)
                        let item = AVURLAsset(url: url!)
                        assets.add(item)
                        print("add item \(tag)")
                    }
                }
                for _ in 1...30 {
                    for asset in assets {
                        let item = AVPlayerItem(asset: (asset as! AVURLAsset));
                        self.queuePlayer?.insert(item, after:nil);
                    }
                }
            }else if(self.playMode == Int.max || self.playMode <= 6){
                let times = self.playMode == Int.max ? 30 : self.playMode
                for _ in 1...times {
                    let item = AVPlayerItem(asset: (currentItem?.asset)!);
                    self.queuePlayer?.insert(item, after:nil);
                }
            } else {
                print("invalid play mode \(playMode)")
            }
        }
        
        if startAt != nil  {
            self.queuePlayer?.seek(to: startAt!, toleranceBefore: kCMTimePositiveInfinity, toleranceAfter: kCMTimePositiveInfinity)
        }
        
        if !self.isPlaying() && newItem != nil {
            self.play()
        }
        
    }
    
    func updatePlayModeIcon(){
        DispatchQueue.main.async{
            if(self.playMode <= 0){self.footPlayMode.setImage(UIImage(named:"ic_repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            }else if(self.playMode == Int.max){self.footPlayMode.setImage( UIImage(named:"ic_repeat_one")?.withRenderingMode(.alwaysTemplate), for: .normal)
            }else if(self.playMode <= 6){
                self.footPlayMode.setImage(UIImage(named:"ic_looks_\(self.playMode)")?.withRenderingMode(.alwaysTemplate), for: .normal)
            }}
    }
    func selectMode(mode:Int) {
        self.playMode = mode;
        self.updatePlayModeIcon();
        self.schedulePlayItems()
        Data.shared.lastPlayMode = mode;
    }
    
    func showModeOptions (){
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let aRepeat = UIAlertAction(title: "順序循環", style: .default, handler: {
            (action) in
            self.selectMode(mode: -1);
        })
        aRepeat.setValue(UIImage(named: "ic_repeat"), forKey: "image")
        optionMenu.addAction(aRepeat)
        
        let aRepeat0 = UIAlertAction(title: "單曲循環", style: .default, handler: {
            (action) in
            self.selectMode(mode: Int.max);
        })
        aRepeat0.setValue(UIImage(named: "ic_repeat_one"), forKey: "image")
        optionMenu.addAction(aRepeat0)
        
        for i in 1...6 {
            let a = UIAlertAction(title: "单曲播放\(i)次", style: .default, handler: {
                (action) in
                self.selectMode(mode: i);
            })
            a.setValue(UIImage(named: "ic_looks_\(i)"), forKey: "image")
            optionMenu.addAction(a)
        }
        
        let cancelAction = UIAlertAction(title: "Close", style: .cancel, handler: nil)
        optionMenu.addAction(cancelAction)
        
        present(optionMenu, animated: true, completion: nil)
    }
    
}

class MediaTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool){
        super.setSelected(selected, animated: animated)
    }
}
