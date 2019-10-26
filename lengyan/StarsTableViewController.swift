import UIKit

class StarsTableViewController: UITableViewController{
    
    internal var initialRow = 0;
    
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .default
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        tableView.separatorInset = UIEdgeInsetsMake(5, 0.0, 0, 0)
        tableView.separatorStyle = .none
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
        
        let identifier = "StarsTableViewCell";
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier);
        if (cell == nil) {
            cell = UITableViewCell.init(style:.subtitle,reuseIdentifier:identifier);
            let v =  cell!.contentView
            v.layer.borderColor = UIColor.lightGray.cgColor
            v.layer.borderWidth = 1/UIScreen.main.scale
        }
        cell?.textLabel?.numberOfLines = 20;
        cell?.textLabel?.attributedText =  Book.data.getSutraAttributeString(item, maxLength: 100);
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let pageVC = SutraPageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
        let path:String = Data.shared.likes[(indexPath as NSIndexPath).row];
        let item = Book.data.itemOfPath(path);
        if item["children"] != nil {
            self.openSutra(path)
        } else {
            pageVC.page = Book.data.index!.index(where: { (
                item) -> Bool in
                return item["path"] == path
            })!;
            self.navigationController?.pushViewController(pageVC, animated: true)
        }
    }
    
    func getIndexAttributeText(_ name:String)->NSAttributedString{
        let attributes = [NSAttributedStringKey.foregroundColor : UIColor.gray,NSAttributedStringKey.font: UIFont.systemFont(ofSize: 14)]
        return NSAttributedString(string: name, attributes:attributes)
    }
    
    
    func openSutra(_ path:String){
        let sutraVC = SutraPurePageViewController.init( transitionStyle:.pageCurl, navigationOrientation:.horizontal, options: .none)
        sutraVC.path = path
        sutraVC.isShowIndexButton = true
        sutraVC.onDismiss = {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.pushViewController(sutraVC, animated: true)
    }
    
    
}
