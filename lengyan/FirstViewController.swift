//
//  FirstViewController.swift
//  lengyanjing
//
//  Created by Xuan on 16/5/5.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {
    private var tree:NSDictionary?;
    private var fullIndexVC:SutraIndexViewController?;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let fullIndexVC = SutraIndexViewController();
        Book.data.loadDataWithCompletionHandler { (Void) in
            self.tree = Book.data.tree
            fullIndexVC.tree =  Book.data.tree
            dispatch_async(dispatch_get_main_queue()){
                self.view.addSubview(fullIndexVC.view);
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func canBecomeFirstResponder() -> Bool {
        return true;
    }

}

