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
import MediaPlayer

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
        self.automaticallyAdjustsScrollViewInsets = true;
        //self.navigationController?.hidesBarsOnSwipe = true;
//    self.navigationController?.hidesBarsWhenVerticallyCompact = true;
//        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        tableView.dataSource = self
        tableView.delegate = self
        self.setTitleBar()
        
        footPlayButton.addTarget(self, action: #selector(pressPlayButton(button:)), for: .touchUpInside)
        
        footPlayMode.addTarget(self, action: #selector(pressModeButton(button:)), for: .touchUpInside)
        
        progressBar.addTarget(self,action:#selector(progressBarChanged(slider:event:)),for:.valueChanged);

        self.playMode = Data.shared.lastPlayMode ?? -1

        Book.data.loadDataWithCompletionHandler { () in
            self.media = Book.data.media!
            
            DispatchQueue.main.async{
                self.tableView.reloadData()
            }
            
            self.media.forEach({ (
                group) in
                let list = group["files"] as! [String];
                list.forEach({( file) in
                    self.getTagStatus(tag: file){available in
                        if(available){
                            DispatchQueue.main.async{
                                self.tableView.reloadData()
                            }
                        }
                    }
                })
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
        self.initAudio();
    }
    func startAudioSession(){
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setCategory(AVAudioSessionCategoryPlayback)
            try session.setActive(true, with: .notifyOthersOnDeactivation)
        } catch{
            NSLog("\(error)")
        }
        
    }
    func initAudio(){
        
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(audioSessionInterrupted(notification:)),
                                               
                                               name:.AVAudioSessionInterruption,
                                               object: AVAudioSession.sharedInstance())
        
        self.setupNowPlayingInfoCenter()
        
    }
    
    @objc func audioSessionInterrupted(notification: NSNotification) {
        
        if notification.name == .AVAudioSessionInterruption
            && notification.userInfo != nil {
            
            var info = notification.userInfo!
            var intValue: UInt = 0
            (info[AVAudioSessionInterruptionTypeKey] as! NSValue).getValue(&intValue)
            if let type = AVAudioSessionInterruptionType(rawValue: intValue) {
                switch type {
                case .began:
                    self.pause()
                case .ended:
                    NSLog("audio interruption ended")
//                    let timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: "play", userInfo: nil, repeats: false)
                }
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
        //        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"選擇", style: .plain, target: self, action: nil)
        self.title = NSLocalizedString("media_tab_title", comment: "听经")//todo
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
        let tag = files[indexPath.row]
        
        let names = group["names"] as! [String]
        var name = names[indexPath.row]
        
        let isDownloaded = tagStatus[tag] == 2;
        let identifier =  isDownloaded ? "Media-Cell":"Media-Cell-Download"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MediaTableViewCell
        
        if(tagStatus[tag]==2){
            //"Downloaded"
            cell.nameLabel.textColor=UIColor.darkText
        }else  if(tagStatus[tag]==1){
            cell.nameLabel.textColor=UIColor.lightGray
            
            let downloadingText = NSLocalizedString("downloading_text", comment: "正在下载...")
                name = name + " -  " + downloadingText;
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
        let names = group["names"] as! [String]
        let name = names[indexPath.row]
        let ext =  group["extension"] as! String
//        let groupName = group["name"] as! String
        
        let cell = tableView.cellForRow(at: indexPath) as! MediaTableViewCell
        
        if(tagStatus[tag]==2){//available
            self.play(name: name, file: tag, ext:ext);
            return;
        }
        
        if( self.rReq[tag] != nil) {
            return;
        }
        
        let req = NSBundleResourceRequest(tags: [tag]);
        self.rReq[tag] = req
        req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        NSLog("beginAccessingResources: \(tag)")
        var progressView:UIProgressView?;
        if(tagStatus[tag]==0 || tagStatus[tag]==nil){
            self.tagStatus[tag] = 1
            cell.nameLabel.textColor=UIColor.lightGray
            let downloadingText = NSLocalizedString("downloading_text", comment: "正在下载...")
            cell.nameLabel.text =  name + " -  " + downloadingText;
            
            progressView = UIProgressView(frame: CGRect(x:  0, y: cell.frame.height - 2,width: cell.frame.width, height: 2))
            progressView?.trackTintColor = UIColor.darkGray
            progressView?.progressTintColor = UIColor.green;
            progressView?.observedProgress = req.progress
            cell.addSubview(progressView!);
        }
        
        req.beginAccessingResources{ error in
            NSLog("beginAccessingResources done: \(tag), \(String(describing: error))")
            if let error = error {
                self.tagStatus[tag]=0
                self.rReq[tag]?.endAccessingResources()
                self.rReq[tag] = nil
                let downloadFailed = NSLocalizedString("download_failed", comment: "下载失败")
                OperationQueue.main.addOperation {
                    cell.nameLabel.text = name + " - " + downloadFailed ;
                }
                self.handleDownloadingError(error as NSError)
            } else {
                self.tagStatus[tag]=2
                OperationQueue.main.addOperation {
                    self.tableView.reloadData()
//                    if(!self.isPlaying()){
                            self.play(name: name, file:tag, ext:ext);
//                        }
                    }

            }
            OperationQueue.main.addOperation {
                progressView?.removeFromSuperview();
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
        return self.queuePlayer != nil && self.queuePlayer!.rate != 0
    }
    func play(){
        self.startAudioSession();
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
            let message = NSLocalizedString("download_error_out_of_space", comment:"空间不足，下载失败")
            self.alert(message: message)
        case NSBundleOnDemandResourceExceededMaximumSizeError:
            let message = NSLocalizedString("download_error_too_big", comment:"程序错误，文件过大")
            self.alert(message: message )
        case NSBundleOnDemandResourceInvalidTagError:
            let message = NSLocalizedString("download_error_invalid_tag", comment:"程序错误，文件不存在")
            self.alert(message: message)
        default:
            self.alert(message: error.description)
        }
    }
    
    func play(name:String, file:String, ext:String){
        
        OperationQueue.main.addOperation {
            self.footLabel.text = name
            self.tableView.reloadData();
            if UIApplication.shared.applicationState != .active {
                return;
            }
        DispatchQueue.global().async {
            
            let req:NSBundleResourceRequest = self.rReq[file]!
            let url = req.bundle.url(forResource:file, withExtension: ext)
            if url == nil {
                NSLog("could not get URL for resource:\(file).\(ext)")
                return;
            } else {
                NSLog("get URL for resource:\(file).\(ext): \(url!)")
            }
            let playItem = AVPlayerItem(url:url!);
            
            if (self.queuePlayer == nil) {
                self.queuePlayer = AVQueuePlayer()
                self.queuePlayer!.addObserver(
                    self, forKeyPath:"currentItem", options:.initial, context:nil)
            }
            
            self.schedulePlayItems(newItem: playItem)
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey:Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "currentItem") {
            let item = self.queuePlayer?.currentItem;
            /*
            NSLog( "play item: \(item)");
            
            if( item != nil) {
                let meta = item?.asset.metadata;
                meta?.forEach({ (m) in
                    NSLog( "\(m.commonKey): \(m.stringValue)");
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
    
    @objc func pressPlayButton(button: UIButton) {
        NSLog("play btn pressed! isSelected:\(button.isSelected)")
        if(!button.isSelected){
            self.footPlayButton.isSelected = true;
            if(self.queuePlayer?.currentItem != nil) {
                self.play()
            } else if(lastPlayFile != nil){
                self.play(name: lastPlayFile![0], file:lastPlayFile![1], ext: lastPlayFile![2])
            }
        } else {
            self.footPlayButton.isSelected = false;
            self.pause()
        }
    }
    
    func getLastPlayItem() -> AVPlayerItem? {
        if self.lastPlayFile != nil {
            let file = self.lastPlayFile![1], ext = self.lastPlayFile![2]
            let req:NSBundleResourceRequest? = self.rReq[file];
            if req != nil {
                let url = req?.bundle.url(forResource:file, withExtension: ext)
                if url != nil {
                    return AVPlayerItem(url:url!);
                }
            }
        }
        return nil
    }
    
    @objc func progressBarChanged(slider: UISlider, event: UIEvent) {
//        NSLog("progress changed: \(slider.value) by event: \(event)")
        var playItem = self.queuePlayer?.currentItem
        if (playItem == nil ) {
            self.schedulePlayItems()
            playItem = self.queuePlayer?.currentItem
            if playItem == nil {
                NSLog("no currentItem")
                return
            }
        }
        
        let duration = playItem!.duration
        if (duration.isNumeric) {
            let phase = event.allTouches?.first?.phase
            let seekTime = CMTimeMakeWithSeconds(Double(slider.value) * (duration.seconds) , duration.timescale );
            
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
            NSLog("invalid duration")
        }
    }
    
    @objc func runTimedCode() {
        if (self.queuePlayer?.currentItem) != nil {
            let duration = self.queuePlayer?.currentItem?.duration;
            var durationText = "", progressText = ""
            var progress:Float = 0;
            
            if(duration?.isNumeric)!{
                let d = Int(duration!.seconds);
                durationText = self.getMediaDisplayTime(seconds: d)
                if(self.queuePlayer!.currentTime().isNumeric){
                    progress = Float(Double(self.queuePlayer!.currentTime().seconds)/duration!.seconds)
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
        let fileName = file!.substring(to:(file?.index((file?.endIndex)!, offsetBy: -((ext?.count)! + 1)))!)
        var name="";
        for group in media {
            let files = group["files"] as! [String]
            if files.contains(fileName) {
                let index:Int = files.index(of: fileName)!
                name = (group["names"]  as! [String])[index];
                break;
            }
        }
        return [name, fileName, ext!]
    }
    
    func schedulePlayItems(newItem:AVPlayerItem? = nil) {
        DispatchQueue.global().async {
            
            var currentItem = self.queuePlayer?.currentItem
            var file:[String]?;
            var startAt:CMTime? = currentItem != nil ? self.queuePlayer?.currentTime(): nil
            self.queuePlayer?.removeAllItems()
            
            if (newItem != nil ) {
                currentItem = newItem;
                file = self.getFileNameAndExtension(item: newItem)
                startAt = nil
            } else {
                file = self.lastPlayFile
            }
            
            if file == nil {
                NSLog("no playing file found")
                return
            }
            
            var name = file![1], ext = file![2]
            
            if(self.playMode <= 0){
                let downloaded = NSMutableArray();
                let assets = NSMutableArray();
                self.tagStatus.forEach({ (k,v) in
                    if(v == 2) {
                        downloaded.add(k);
                    }
                })
                
                //                if downloaded.count>0 {
                //                    name = downloaded.object(at: 0) as! String
                //                }
                
                //                let fullList:[String]?;
                let sorted = NSMutableArray();
                for group in self.media {
                    let files = group["files"] as! [String]
                    if files.contains(name) {
                        let index:Int = files.index(of: name) ?? 0;
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
                        if url != nil {
                            let item = AVURLAsset(url: url!)
                            assets.add(item)
                        }
                    }
                }
                
                let times = Int( 30 / assets.count)
                
                for _ in 1...times {
                    for asset in assets {
                        NSLog("creat AVPlayerItem")
                        let item = AVPlayerItem(asset: (asset as! AVURLAsset));
                        self.queuePlayer?.insert(item, after:nil);
                    }
                }
            }else if(self.playMode == Int.max || self.playMode <= 6){
                let times = self.playMode == Int.max ? 30 : self.playMode
                for _ in 1...times {
                    NSLog("creat AVPlayerItem")
                    let item = AVPlayerItem(asset: (currentItem?.asset)!);
                    self.queuePlayer?.insert(item, after:nil);
                }
            } else {
                NSLog("invalid play mode \(self.playMode)")
            }
            
            if startAt != nil  {
                self.queuePlayer?.seek(to: startAt!, toleranceBefore: kCMTimePositiveInfinity, toleranceAfter: kCMTimePositiveInfinity)
            }
            
            if !self.isPlaying() && newItem != nil {
                self.play()
            }
        }
    }
    
    func updatePlayModeIcon(){
        DispatchQueue.main.async{
            if(self.playMode <= 0){self.footPlayMode.setImage(UIImage(named:"ic_repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            }else if(self.playMode == Int.max){self.footPlayMode.setImage( UIImage(named:"ic_repeat_one")?.withRenderingMode(.alwaysTemplate), for: .normal)
            }else if(self.playMode <= 6){
                self.footPlayMode.setImage(UIImage(named:"ic_looks_\(self.playMode)")?.withRenderingMode(.alwaysTemplate), for: .normal)
            }
            
        }
    }
    func selectMode(mode:Int) {
        NSLog("selected mode: \(mode)");
        self.playMode = mode;
        self.updatePlayModeIcon();
        self.schedulePlayItems()
        Data.shared.lastPlayMode = mode;
    }
    
    @objc func pressModeButton(button: UIButton) {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if let presenter = optionMenu.popoverPresentationController {
            presenter.sourceView = button;
            presenter.sourceRect = button.bounds;
        }
        let aRepeat = UIAlertAction(title:  NSLocalizedString("play_mode_repeat", comment:"順序循環"), style: .default, handler: {
            (action) in
            self.selectMode(mode: -1);
        })
        aRepeat.setValue(UIImage(named: "ic_repeat"), forKey: "image")
        optionMenu.addAction(aRepeat)
        
        let aRepeat0 = UIAlertAction(title: NSLocalizedString("play_mode_repeat_one", comment:"單曲循環"), style: .default, handler: {
            (action) in
            self.selectMode(mode: Int.max);
        })
        aRepeat0.setValue(UIImage(named: "ic_repeat_one"), forKey: "image")
        optionMenu.addAction(aRepeat0)
        
        let singlePlay = NSLocalizedString("play_mode_play_one", comment:"單曲播放")
        for i in 1...6 {
            let a = UIAlertAction(title: "\(singlePlay)\(i)次", style: .default, handler: {
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
//
//    override func remoteControlReceived(with event: UIEvent?) {
//        NSLog(event!.type)
//        NSLog(event!.subtype)
//        if event!.type == UIEventType.remoteControl {
//            if event?.subtype == UIEventSubtype.remoteControlPlay {
//                self.play()
//            } else if event?.subtype == UIEventSubtype.remoteControlPause {
//                self.pause();
//            } else if event?.subtype == UIEventSubtype.remoteControlNextTrack {
//                self.queuePlayer?.advanceToNextItem()
//                self.play()
//            } else if event?.subtype == UIEventSubtype.remoteControlPreviousTrack {
//                self.queuePlayer?.seek(to: CMTimeMake(0,10));
//                self.play()
//            }
//        }
//    }
    
    private func setupNowPlayingInfoCenter() {
        UIApplication.shared.beginReceivingRemoteControlEvents();
        MPRemoteCommandCenter.shared().playCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.play()
            self.updateNowPlayingInfoCenter()
            return .success
        })
        MPRemoteCommandCenter.shared().pauseCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.pause()
            self.updateNowPlayingInfoCenter()
            return .success
        })
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.queuePlayer?.advanceToNextItem()
            self.play()
            self.updateNowPlayingInfoCenter()
            return .success
        })
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.queuePlayer?.seek(to: CMTimeMake(0,10))
            self.play()
            self.updateNowPlayingInfoCenter()
            return .success
        })
    }
    
    private func updateNowPlayingInfoCenter(artwork: UIImage? = nil) {
        guard let file = self.queuePlayer?.currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [String: AnyObject]()
            return
        }
        let name = getFileNameAndExtension(item: file)?[0];
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: name ?? "",
            MPMediaItemPropertyPlaybackDuration:  self.queuePlayer?.currentItem?.duration.seconds ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:  self.queuePlayer?.currentTime().seconds ?? 0
        ]
    }
}

class MediaTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool){
        super.setSelected(selected, animated: animated)
    }
}
