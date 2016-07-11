//
//  SutraActionGroupView.swift
//  lengyan
//
//  Created by Xuan on 16/7/5.
//  Copyright © 2016年 xuan. All rights reserved.
//

class SutraActionGroupView: UIView {
    var item:[String:AnyObject]?
    var path:String?
    
    var star: UIButton?;
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addCustomView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addCustomView() {
//        label.frame = CGRectMake(50, 10, 200, 100)
//        label.backgroundColor=UIColor.whiteColor()
//        label.textAlignment = NSTextAlignment.Center
//        label.text = "test label"
//        label.hidden=true
//        self.addSubview(label)
        
 
        
    }
    
    override func willMoveToSuperview(newSuperview: UIView?){
        print("willMoveToSuperview");
        star = UIButton(type: .System);
        star?.backgroundColor = UIColor.whiteColor()
        star?.setTitleColor(UIColor.darkGrayColor(), forState: .Normal)
        star!.frame=CGRectMake(0, 0, 80, 30)
        star!.setTitle( Data.shared.likes.contains(self.path!) ? "☆" : "★", forState: UIControlState.Normal)
        star!.addTarget(self, action:  #selector(SutraActionGroupView.toggleLike), forControlEvents: UIControlEvents.TouchUpInside)
        
        
        self.addSubview(star!)
    }

    
    func toggleLike() {
        if Data.shared.likes.contains(self.path!) {
            Data.shared.unlike(self.path!)
            star?.setTitle("★" , forState: .Normal)
        } else {
            Data.shared.like(self.path!)
            star?.setTitle("☆" , forState: .Normal)
        }
    }

}
