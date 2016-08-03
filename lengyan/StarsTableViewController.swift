import UIKit

class StarsTableViewController: UITableViewController{
    
    internal var initialRow = 0;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 44, 0)
        
        //        self.tableView.rowHeight = 300;
        //        self.tableView.separatorStyle = .None;
        self.setTitleBar()
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func titleWasTapped (){
        print("titleWasTapped");
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.scrollsToTop = true
        
        if (initialRow >= 0) {
            print("viewWillAppear, scroll to row: \(initialRow)");
            self.tableView.selectRowAtIndexPath(NSIndexPath.init(forRow: initialRow, inSection: 0), animated: false, scrollPosition: .Top)
            initialRow = -1;
        }
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.scrollsToTop = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setTitleBar() {
        //        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"❬", style: .Plain, target: self, action: #selector(SutraIndexViewController.close))
        //        self.title = "精選"
        //        self.navigationController?.navigationBar.showHeader = false;
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
        return Data.shared.likes.count;
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let path = Data.shared.likes[indexPath.row];
        let item =  Book.data.itemOfPath(path);
        
        //        let cell = tableView.dequeueReusableCellWithIdentifier("StarsTableViewCell", forIndexPath: indexPath) as UITableViewCell
        let identifier = "StarsTableViewCell";
        var cell = tableView.dequeueReusableCellWithIdentifier(identifier);
        if (cell == nil) {
            cell = UITableViewCell.init(style:.Subtitle,reuseIdentifier:identifier);
            cell?.detailTextLabel?.textColor = UIColor.brownColor()
        }
        
        cell?.textLabel?.numberOfLines = 20;
        cell?.textLabel?.text = Book.data.getSutra(item, maxLength: 300);
        
        cell?.detailTextLabel?.attributedText = Book.data.getTitleLine(item);
        return cell!
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let pageVC = SutraPageViewController.init( transitionStyle:.PageCurl, navigationOrientation:.Horizontal, options: .None)
        let path:String = Data.shared.likes[indexPath.row];
        pageVC.page = Book.data.index!.indexOf({ (
            item) -> Bool in
            return item["path"] == path
        })!;
        
        let navVC = UINavigationController.init(rootViewController: pageVC);
        self.presentViewController(navVC, animated: true, completion: nil)
    }
    
    func getIndexAttributeText(name:String)->NSAttributedString{
        let attributes = [NSForegroundColorAttributeName : UIColor.grayColor(),NSFontAttributeName: UIFont.systemFontOfSize(14)]
        return NSAttributedString(string: name, attributes:attributes)
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
    
    
}
