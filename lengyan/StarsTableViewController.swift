import UIKit

class StarsTableViewController: UITableViewController{
    
    internal var initialRow = 0;
    
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .default
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
//        tableView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 44, 0)
        tableView.separatorInset = UIEdgeInsetsMake(5, 0.0, 0, 0)
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.white
        tableView.separatorInset = UIEdgeInsetsMake(10, 0.0, 10, 0)
        tableView.rowHeight = UITableViewAutomaticDimension

        self.setTitleBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.hidesBarsOnSwipe = false;

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
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setTitleBar() {
        //self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"❬", style: .Plain, target: self, action: #selector(SutraIndexViewController.close))
        
        self.title = NSLocalizedString("star_tab_title", comment: "收藏")//todo

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
            let v =  cell!.contentView
            v.layer.cornerRadius = 10
            v.layer.borderColor = UIColor.lightGray.cgColor
            v.layer.borderWidth = 1
        }
//        cell?.detailTextLabel?.text=path;
        cell?.textLabel?.numberOfLines = 20;
        cell?.textLabel?.attributedText =  Book.data.getSutraAttributeString(item, maxLength: 100);
//        cell?.textLabel?.attributedText = Book.data.getTitleLine(item);
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let pageVC = SutraPageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
        let path:String = Data.shared.likes[(indexPath as NSIndexPath).row];
        let item = Book.data.itemOfPath(path);
        if item["children"] != nil {
            self.openSutra(item)
        } else {
            pageVC.page = Book.data.index!.index(where: { (
                item) -> Bool in
                return item["path"] == path
            })!;
            self.navigationController?.pushViewController(pageVC, animated: true)
        }
    }
    
    func getIndexAttributeText(_ name:String)->NSAttributedString{
        let attributes = [NSForegroundColorAttributeName : UIColor.gray,NSFontAttributeName: UIFont.systemFont(ofSize: 14)]
        return NSAttributedString(string: name, attributes:attributes)
    }
    
    
    func openSutra(_ item: [String : Any]){
        let sutraVC = SutraPurePageContentViewController.init();
        sutraVC.item = item
        sutraVC.isShowIndexButton = true
        sutraVC.onDismiss = {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.pushViewController(sutraVC, animated: true)
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
