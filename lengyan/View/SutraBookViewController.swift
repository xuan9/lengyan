//
//  SutraPageContentViewController.swift
//  lengyan
//
//  Created by Xuan on 16/6/19.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit


class SutraBookTableViewCell: UITableViewCell {
    
    @IBOutlet weak var textView: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

class SutraBookViewController: UITableViewController{
    
    internal var initialRow = 0;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.estimatedRowHeight = 300;
        self.tableView.separatorStyle = .none;
        self.setTitleBar()
    }
    
    func titleWasTapped (){
        print("titleWasTapped");
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.scrollsToTop = true
        
        if (initialRow > 0) {
            // print("viewWillAppear, scroll to row: \(initialRow)");
            self.tableView.selectRow(at: IndexPath.init(row: initialRow, section: 0), animated: false, scrollPosition: .top)
            initialRow = -1;
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.scrollsToTop = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }
    
    func close() {
        self.navigationController?.dismiss(animated: true, completion: {
            
        })
    }
    
    func setTitleBar() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:" ❬   ", style: .plain, target: self, action: #selector(SutraIndexViewController.close))
        self.navigationItem.leftBarButtonItem?.setBackButtonBackgroundImage(UIImage.init(named: "ic_chevron_left_18pt"), for: .normal, barMetrics: .default)

        
        self.title = "楞嚴經"
        self.navigationController?.navigationBar.isTranslucent = false;
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
        return (Book.shared.index?.count)!;
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var meta:[String:String] = (Book.shared.index![(indexPath as NSIndexPath).row]);
        let path = meta["path"] ;
        let contents:[[String:String]]? =  (Book.shared.contents?[path!]);
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SutraBookTableViewCell", for: indexPath) as! SutraBookTableViewCell
        cell.textView.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);

        
        if(contents == nil){
            cell.textView.attributedText = nil;
        } else {
            cell.textView.attributedText =  getSutraAttributeText(contents!);
        }
        
        return cell
    }
    
    func getSutraAttributeText(_ contents:[[String:String]])->NSAttributedString{

        var sutraContents = [String]()

        for c in contents {
            if c["type"] == "sutra" {
                sutraContents.append(c["content"]!)
            }
        }

        let text = sutraContents.joined(separator: "\n")

        // Use SutraTypography design system
        let attributes: [NSAttributedString.Key: Any] = [
            .font: SutraTypographyManager.shared.uiFont(for: .sutraBody),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary)
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    func getIndexAttributeText(_ name:String)->NSAttributedString{
        // Use SutraTypography design system for index items
        let attributes: [NSAttributedString.Key: Any] = [
            .font: SutraTypographyManager.shared.uiFont(for: .indexItem),
            .foregroundColor: SutraDesignTokens.shared.color(for: .textSecondary)
        ]

        return NSAttributedString(string: name, attributes: attributes)
    }
    
}
