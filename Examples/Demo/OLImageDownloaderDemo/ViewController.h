//
//  ViewController.h
//  OLImageDownloaderDemo
//
//  Created by junmin liu on 12-12-2.
//  Copyright (c) 2012年 openlab Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OLImageRequestOperation.h"
#import "OLImageDownloader.h"

@interface ViewController : UIViewController {
    UIButton *_startButton;
    UIButton *_cancelButton;
    UIProgressView *_progressView;
    UIImageView *_imageView;
    UIImageView *_imageView2;
    
    OLImageRequestOperation *_request;
    OLImageRequestOperation *_request2;
    
    OLImageOperationHandler *_handler1;
}

@property (nonatomic, strong) IBOutlet UIButton *startButton;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) IBOutlet UIImageView *imageView2;

- (IBAction)start:(id)sender;
- (IBAction)cancel:(id)sender;


@end
