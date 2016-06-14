//
//  FirstViewController.swift
//  lengyanjing
//
//  Created by Xuan on 16/5/5.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController, RATreeViewDataSource,
RATreeViewDelegate {
    
    private var treeView: RATreeView!
    private var json:NSDictionary? = nil
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fileURL = NSBundle.mainBundle().URLForResource("data/lengyanjing-index-tree", withExtension: "json")
        let data = NSData(contentsOfURL: fileURL!);
        do {
            json = try (NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)) as? NSDictionary
        } catch _ {
            json = NSDictionary();
        }
        //        print(json)
        
        let bounds:CGRect = self.view.bounds;
        treeView = RATreeView(frame: CGRect(origin: CGPoint(x:bounds.origin.x,y:bounds.origin.y+20),size:bounds.size));
        treeView.delegate = self
        treeView.dataSource = self
        
        treeView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(treeView)
        treeView.reloadData()
        treeView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "indexCell")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func treeView(treeView: RATreeView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if(item == nil){
            return (self.json?["children"]?.count)!;
        } else if item?["children"]! != nil {
            return item!["children"]!!.count
        } else {
            return  0
        }
    }
    
    func treeView(treeView: RATreeView, cellForItem item: AnyObject?) -> UITableViewCell {
        let level = treeView.levelForCellForItem(item!)
        
        let cell = treeView.dequeueReusableCellWithIdentifier("indexCell") as! UITableViewCell;
        let item = item as! NSDictionary;
        
        let name = item["name"]! as? String
        let nameWithIndent = String(count: 3*level, repeatedValue: Character(" "))
        cell.textLabel?.text = nameWithIndent + name!;
        
        return cell
    }
    
    func treeView(treeView: RATreeView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if(item != nil){
            return (item!["children"]?![index])!
        }else{
            return (json!["children"]?[index])!
        }
    }
    
    
    
}

