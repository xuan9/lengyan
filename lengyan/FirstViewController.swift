//
//  FirstViewController.swift
//  lengyanjing
//
//  Created by Xuan on 16/5/5.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {
        fileprivate var tree:[String:Any]?;
    fileprivate var fullIndexVC:SutraIndexViewController?;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = true
        let fullIndexVC = SutraIndexViewController();
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.tree = Book.data.tree
            fullIndexVC.tree =  Book.data.tree
            DispatchQueue.main.async{
                self.view.addSubview(fullIndexVC.view);
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

