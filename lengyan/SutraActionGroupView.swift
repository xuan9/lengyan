//
//  SutraActionGroupView.swift
//  lengyan
//
//  Created by Xuan on 16/7/5.
//  Copyright © 2016年 xuan. All rights reserved.
//

class SutraActionGroupView: UIView {
    var item:[String:Any]?
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
    
    override func willMove(toSuperview newSuperview: UIView?){
        print("willMoveToSuperview");
        star = UIButton(type: .system);
        star?.backgroundColor = UIColor.white
        star?.setTitleColor(UIColor.darkGray, for: UIControlState())
        star!.frame=CGRect(x: 0, y: 0, width: 80, height: 30)
        star!.setTitle( Data.shared.likes.contains(self.path!) ? "☆" : "★", for: UIControlState())
        star!.addTarget(self, action:  #selector(SutraActionGroupView.toggleLike), for: UIControlEvents.touchUpInside)
        
        
        self.addSubview(star!)
    }

    
    func toggleLike() {
        if Data.shared.likes.contains(self.path!) {
            Data.shared.unlike(self.path!)
            star?.setTitle("★" , for: UIControlState())
        } else {
            Data.shared.like(self.path!)
            star?.setTitle("☆" , for: UIControlState())
        }
    }

}
