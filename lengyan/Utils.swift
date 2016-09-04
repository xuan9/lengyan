//
//  Utils.swift
//  lengyan
//
//  Created by Xuan on 16/7/10.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation

func imageScaledToFillSize(_ size: CGSize, image: UIImage) -> UIImage
{
    let aspect = image.size.width / image.size.height;
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    if (size.width / aspect <= size.height) {
        let resizedImg = imageScaledToSize(CGSize(width: size.height * aspect, height: size.height), image: image)
        resizedImg.draw(in: CGRect(x: (size.width - resizedImg.size.width)/2, y: 0, width: resizedImg.size.width, height: resizedImg.size.height))
    } else {
        let resizedImg = imageScaledToSize(CGSize(width: size.width, height: size.width / aspect), image: image)
        resizedImg.draw(in: CGRect(x: 0, y: (size.height-resizedImg.size.height)/2, width: resizedImg.size.width, height: resizedImg.size.height))
    }
    let imageR = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageR!;
}

func imageScaledToSize(_ size: CGSize, image: UIImage) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0);
    image.draw(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    let imageR = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext();
    return imageR!;
}

func SetBackgroundImage(_ view:UIView, imageName:String){
    let targetImage = UIImage.init(named: imageName)
    
    // redraw the image to fit |yourView|'s size
    UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0);
    targetImage!.draw(in: CGRect(x: 0,y: 0, width: view.frame.size.width, height: view.frame.size.height));
    let resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    view.backgroundColor = UIColor.init(patternImage: resultImage!)
}
