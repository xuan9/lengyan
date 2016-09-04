import UIKit

class StarsTableViewController: UITableViewController{
    
    internal var initialRow = 0;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        tableView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 44, 0)
        tableView.separatorInset = UIEdgeInsetsMake(15, 0.0, 15, 0)
        //        self.tableView.rowHeight = 300;
        self.tableView.separatorStyle = .none;
        self.setTitleBar()
    }
    
    func titleWasTapped (){
        print("titleWasTapped");
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let rows = tableView.numberOfRows(inSection: 0)
        if rows != Data.shared.likes.count {
                tableView.reloadData()
        }
        if (initialRow > 0) {
            print("viewWillAppear, scroll to row: \(initialRow)");
            self.tableView.selectRow(at: IndexPath.init(row: initialRow, section: 0), animated: false, scrollPosition: .top)
            initialRow = -1;
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        return Data.shared.likes.count;
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let path = Data.shared.likes[(indexPath as NSIndexPath).row];
        let item =  Book.data.itemOfPath(path);
        
        //        let cell = tableView.dequeueReusableCellWithIdentifier("StarsTableViewCell", forIndexPath: indexPath) as UITableViewCell
        let identifier = "StarsTableViewCell";
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier);
        if (cell == nil) {
            cell = UITableViewCell.init(style:.subtitle,reuseIdentifier:identifier);
            cell?.detailTextLabel?.textColor = UIColor.lightGray
        }
        
        cell?.textLabel?.numberOfLines = 20;
        cell?.textLabel?.text = "☸ " + Book.data.getSutra(item, maxLength: 300);
        
        cell?.detailTextLabel?.attributedText = Book.data.getTitleLine(item);
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let pageVC = SutraPageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
        let path:String = Data.shared.likes[(indexPath as NSIndexPath).row];
        pageVC.page = Book.data.index!.index(where: { (
            item) -> Bool in
            return item["path"] == path
        })!;
        
        let navVC = UINavigationController.init(rootViewController: pageVC);
        self.present(navVC, animated: true, completion: nil)
    }
    
    func getIndexAttributeText(_ name:String)->NSAttributedString{
        let attributes = [NSForegroundColorAttributeName : UIColor.gray,NSFontAttributeName: UIFont.systemFont(ofSize: 14)]
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
