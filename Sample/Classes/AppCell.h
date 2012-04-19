//
//  AppCell.h
//  TopPaid
//
//  Created by junmin liu on 12-4-19.
//  Copyright (c) 2012年 Openlab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppRecord.h"
#import "ImageDownloader.h"
#import "ImageDownloadReceiver.h"

@interface AppCell : UITableViewCell {
    AppRecord *_appRecord;
    
    UIImage *_image; // 存放下载图片的变量
    ImageDownloadReceiver *_imageDownloadReceiver; //图片下载接受器

}

@property (nonatomic, retain) AppRecord *appRecord;

@end
