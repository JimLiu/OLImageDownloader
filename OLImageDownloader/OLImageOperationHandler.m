//
//  OLImageOperationHandler.m
//  OLImageDownloader
//
//  Created by junmin liu on 13-2-14.
//  Copyright (c) 2013年 openlab Inc. All rights reserved.
//

#import "OLImageOperationHandler.h"
#import "OLImageDownloader.h"

@interface OLImageOperationHandler ()

@property (nonatomic, weak) OLImageDownloader *downloader;

@end

@implementation OLImageOperationHandler

- (id)initWithURL:(NSURL *)url
         progress:(OLImageRequestProgressBlock)progressBlock
        completed:(OLImageRequestCompletedBlock)completedBlock
        cancelled:(void (^)())cancelBlock
       downloader:(OLImageDownloader *)downloader {
    if ((self = [super init]))
    {
        _url = url;
        _progressive = NO;
        _progressBlock = [progressBlock copy];
        _completedBlock = [completedBlock copy];
        _cancelBlock = [cancelBlock copy];
        _downloader = downloader;
    }
    return self;
}

- (void)dealloc {
    _downloader = nil;
}

- (void)cancel {
    
}

@end
