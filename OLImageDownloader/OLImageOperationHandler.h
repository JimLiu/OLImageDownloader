//
//  OLImageOperationHandler.h
//  OLImageDownloader
//
//  Created by junmin liu on 13-2-14.
//  Copyright (c) 2013年 openlab Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^OLImageRequestProgressBlock)(NSUInteger receivedSize, long long expectedSize);
typedef void(^OLImageRequestCompletedBlock)(UIImage *image, NSData *data, NSError *error, BOOL finished);

@class OLImageDownloader;

@interface OLImageOperationHandler : NSObject {
}

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) BOOL progressive;
@property (nonatomic, copy) OLImageRequestProgressBlock progressBlock;
@property (nonatomic, copy) OLImageRequestCompletedBlock completedBlock;
@property (nonatomic, copy) void (^cancelBlock)();

- (id)initWithURL:(NSURL *)url
         progress:(OLImageRequestProgressBlock)progressBlock
        completed:(OLImageRequestCompletedBlock)completedBlock
        cancelled:(void (^)())cancelBlock
       downloader:(OLImageDownloader *)downloader;

// Cancel downloading, and don't notify this handler
//      @param cancelDownloading:
//                      YES, cancel downloading of the url;
//                      NO,  continue downloading but don't notify
- (void)cancel:(BOOL)cancelDownloading;

// Cancel downloading, and don't notify this handler
- (void)cancel;

@end
