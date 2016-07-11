//
//  Utils.swift
//  lengyan
//
//  Created by Xuan on 16/7/10.
//  Copyright © 2016年 xuan. All rights reserved.
//

import Foundation

func imageScaledToFillSize(size: CGSize, image: UIImage) -> UIImage
{
    let aspect = image.size.width / image.size.height;
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    if (size.width / aspect <= size.height) {
        let resizedImg = imageScaledToSize(CGSize(width: size.height * aspect, height: size.height), image: image)
        resizedImg.drawInRect(CGRectMake((size.width - resizedImg.size.width)/2, 0, resizedImg.size.width, resizedImg.size.height))
    } else {
        let resizedImg = imageScaledToSize(CGSize(width: size.width, height: size.width / aspect), image: image)
        resizedImg.drawInRect(CGRectMake(0, (size.height-resizedImg.size.height)/2, resizedImg.size.width, resizedImg.size.height))
    }
    let imageR = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageR;
}

func imageScaledToSize(size: CGSize, image: UIImage) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0);
    image.drawInRect(CGRectMake(0.0, 0.0, size.width, size.height))
    let imageR = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext();
    return imageR;
}

func SetBackgroundImage(view:UIView, imageName:String){
    let targetImage = UIImage.init(named: imageName)
    
    // redraw the image to fit |yourView|'s size
    UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0);
    targetImage!.drawInRect(CGRectMake(0,0, view.frame.size.width, view.frame.size.height));
    let resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    view.backgroundColor = UIColor.init(patternImage: resultImage)
}