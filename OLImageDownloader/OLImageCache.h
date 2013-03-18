//
//  OLImageCache.h
//  OLImageDownloader
//
//  Created by junmin liu on 12-12-2.
//  Copyright (c) 2012年 openlab Inc. All rights reserved.
//  Reference code:
//      https://github.com/rs/SDURLCache
//      https://github.com/steipete/SDURLCache
//

#import <Foundation/Foundation.h>
#import "NSStringExtension.h"

@interface OLImageCache : NSObject {
    NSString *_cacheName;
    NSUInteger _memoryCapacity;
    NSUInteger _diskCapacity;
    BOOL _diskCacheInfoDirty;
    BOOL _timerPaused;
    NSUInteger _diskCacheUsage;
    NSTimeInterval _minCacheInterval;
    dispatch_source_t _maintenanceTimer;
}

/*
 * Defines the minimum number of seconds between now and the expiration time of a cacheable response
 * in order for the response to be cached on disk. This prevent from spending time and storage capacity
 * for an entry which will certainly expire before behing read back from disk cache (memory cache is
 * best suited for short term cache). The default value is set to 5 minutes (300 seconds).
 */
@property (nonatomic, assign) NSTimeInterval minCacheInterval;

/*!
 @method memoryCapacity
 @abstract Returns the in-memory capacity of the receiver.
 @result The in-memory capacity, measured in bytes, for the receiver.
 */
- (NSUInteger)memoryCapacity;

/*!
 @method diskCapacity
 @abstract Returns the on-disk capacity of the receiver.
 @result The on-disk capacity, measured in bytes, for the receiver.
 */
- (NSUInteger)diskCapacity;

/*
 * Init with a cache name
 * Name: 
 *      The name of image caches. A directory in iOS's cache directory will be created with this name, all the images cached with current instance will be stored to this directory.
 */
- (id)initWithName:(NSString *)name;
+ (OLImageCache *)cacheWithName:(NSString *)name;

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity cacheName:(NSString *)name;

/*
 * Checks if the provided URL exists in cache.
 */
- (BOOL)isCached:(NSURL *)url;
- (void)storeImageToDisk:(NSURL *)URL imageData:(NSData *)imageData;
- (void)queryDiskCacheForURL:(NSURL *)url
                        done:(void (^)(UIImage *image, NSData *imageData))doneBlock;
- (NSString *)filePathForURL:(NSURL *)URL;


@end
