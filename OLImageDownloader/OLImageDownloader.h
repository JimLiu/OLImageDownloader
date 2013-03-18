//
//  OLImageDownloader.h
//  OLImageDownloaderDemo
//
//  Created by junmin liu on 13-3-2.
//  Copyright (c) 2013年 openlab Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OLImageCache.h"
#import "OLImageRequestOperation.h"
#import "OLImageOperationHandler.h"

@interface OLImageDownloader : NSObject {
    // Using a queue to notify the delegates
    dispatch_queue_t _notificationsQueue;
    //
    dispatch_queue_t _barrierQueue;
}

@property (nonatomic, assign) NSInteger maxConcurrentDownloads;
@property (nonatomic, strong) OLImageCache *imageCache;

- (id)initWithName:(NSString *)name;
- (id)initWithImageCache:(OLImageCache *)imageCache;

// Get an instance with default name "photos"
+ (OLImageDownloader *)shared;
// Get an instance with a name which is the dictionary name that store the cached images
+ (OLImageDownloader *)downloaderWithName:(NSString *)name;

- (OLImageOperationHandler *)downloadImageWithURL:(NSURL *)URL
                                     highPriority:(BOOL)highPriority
                                      progressive:(BOOL)progressive
                                         progress:(OLImageRequestProgressBlock)progressBlock
                                        completed:(OLImageRequestCompletedBlock)completedBlock;

- (OLImageOperationHandler *)downloadImageWithURL:(NSURL *)URL
                                        completed:(OLImageRequestCompletedBlock)completedBlock;

- (OLImageOperationHandler *)downloadImageWithURL:(NSURL *)URL
                                     highPriority:(BOOL)highPriority
                                        completed:(OLImageRequestCompletedBlock)completedBlock;

- (void)removeHandler:(OLImageOperationHandler *)handler;

// canel a download by url
- (void)cancelDownloading:(NSString *)url;

@end
