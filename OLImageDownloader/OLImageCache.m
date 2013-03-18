//
//  OLImageCache.m
//  OLImageDownloader
//
//  Created by junmin liu on 12-12-2.
//  Copyright (c) 2012年 openlab Inc. All rights reserved.
//  Reference code:
//      https://github.com/rs/SDURLCache
//      https://github.com/steipete/SDURLCache
//

#import "OLImageCache.h"

#define kOLImageCachePath @"OLImageCache"
#define kOLImageCacheMaintenanceTime 5ull


static NSTimeInterval const kOLImageCacheInfoDefaultMinCacheInterval = 5.0 * 60.0; // 5 minute
static NSString *const kOLImageCacheInfoFileName = @"olimagecache.plist";
static NSString *const kOLImageCacheInfoAccessesKey = @"accesses";
static NSString *const kOLImageCacheInfoSizesKey = @"sizes";


// deadlock-free variant of dispatch_sync
void dispatch_sync_afreentrant(dispatch_queue_t queue, dispatch_block_t block);
inline void dispatch_sync_afreentrant(dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_get_current_queue() == queue ? block() : dispatch_sync(queue, block);
}

void dispatch_async_afreentrant(dispatch_queue_t queue, dispatch_block_t block);
inline void dispatch_async_afreentrant(dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_get_current_queue() == queue ? block() : dispatch_async(queue, block);
}

@interface OLImageCache ()
@property (nonatomic, retain) NSString *diskCachePath;
@property (nonatomic, retain) NSMutableDictionary *diskCacheInfo;
- (void)periodicMaintenance;
@end

@implementation OLImageCache
@synthesize minCacheInterval = _minCacheInterval;
@synthesize diskCachePath = _diskCachePath;
@synthesize diskCacheInfo = _diskCacheInfo;

+ (NSString *)cacheKeyForURL:(NSURL *)url
{
    return [url.absoluteString md5String];
}

static dispatch_queue_t get_disk_cache_queue() {
    static dispatch_once_t onceToken;
    static dispatch_queue_t _diskCacheQueue;
	dispatch_once(&onceToken, ^{
		_diskCacheQueue = dispatch_queue_create("com.openlab.imagecache.processing", NULL);
	});
	return _diskCacheQueue;
}

static dispatch_queue_t get_disk_io_queue() {
    static dispatch_queue_t _diskIOQueue;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_diskIOQueue = dispatch_queue_create("com.openlab.imagecache.io", NULL);
	});
	return _diskIOQueue;
}

- (dispatch_source_t)maintenanceTimer {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _maintenanceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        if (_maintenanceTimer) {
            dispatch_source_set_timer(_maintenanceTimer, dispatch_walltime(DISPATCH_TIME_NOW, kOLImageCacheMaintenanceTime * NSEC_PER_SEC),
                                      kOLImageCacheMaintenanceTime * NSEC_PER_SEC, kOLImageCacheMaintenanceTime/2 * NSEC_PER_SEC);
            __block OLImageCache *blockSelf = self;
            dispatch_source_set_event_handler(_maintenanceTimer, ^{
                [blockSelf periodicMaintenance];
                
                // will abuse cache queue to lock timer
                dispatch_async_afreentrant(get_disk_cache_queue(), ^{
                    dispatch_suspend(_maintenanceTimer); // pause timer
                    _timerPaused = YES;
                });
            });
            // initially wake up timer
            dispatch_resume(_maintenanceTimer);
        }
    });
    return _maintenanceTimer;
}

- (NSMutableDictionary *)diskCacheInfo {
    if (!_diskCacheInfo) {
        dispatch_sync_afreentrant(get_disk_cache_queue(), ^{
            if (!_diskCacheInfo) { // Check again, maybe another thread created it while waiting for the mutex
                _diskCacheInfo = [[NSMutableDictionary alloc] initWithContentsOfFile:[_diskCachePath stringByAppendingPathComponent:kOLImageCacheInfoFileName]];
                if (!_diskCacheInfo) {
                    _diskCacheInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                      [NSMutableDictionary dictionary], kOLImageCacheInfoAccessesKey,
                                      [NSMutableDictionary dictionary], kOLImageCacheInfoSizesKey,
                                      nil];
                }
                _diskCacheInfoDirty = NO;
                NSArray *sizes = [[_diskCacheInfo objectForKey:kOLImageCacheInfoSizesKey] allValues];
                _diskCacheUsage = [[sizes valueForKeyPath:@"@sum.self"] unsignedIntegerValue];
                
                // create maintenance timer
                [self maintenanceTimer];
            }
        });
    }
    
    return _diskCacheInfo;
}

- (void)createDiskCachePath {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if (![fileManager fileExistsAtPath:_diskCachePath]) {
            [fileManager createDirectoryAtPath:_diskCachePath
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:NULL];
        }
    });
}

- (void)saveCacheInfo {
    [self createDiskCachePath];
    dispatch_async_afreentrant(get_disk_cache_queue(), ^{
        NSData *data = [NSPropertyListSerialization dataFromPropertyList:self.diskCacheInfo format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
        if (data) {
            [data writeToFile:[_diskCachePath stringByAppendingPathComponent:kOLImageCacheInfoFileName] atomically:YES];
        }
        
        _diskCacheInfoDirty = NO;
    });
}

- (void)removeCachedResponseForCachedKeys:(NSArray *)cacheKeys {
    dispatch_async_afreentrant(get_disk_cache_queue(), ^{
        @autoreleasepool {
            NSEnumerator *enumerator = [cacheKeys objectEnumerator];
            NSString *cacheKey;
            
            NSMutableDictionary *accesses = [self.diskCacheInfo objectForKey:kOLImageCacheInfoAccessesKey];
            NSMutableDictionary *sizes = [self.diskCacheInfo objectForKey:kOLImageCacheInfoSizesKey];
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            
            while ((cacheKey = [enumerator nextObject])) {
                NSUInteger cacheItemSize = [[sizes objectForKey:cacheKey] unsignedIntegerValue];
                [accesses removeObjectForKey:cacheKey];
                [sizes removeObjectForKey:cacheKey];
                [fileManager removeItemAtPath:[_diskCachePath stringByAppendingPathComponent:cacheKey] error:NULL];
                
                _diskCacheUsage -= cacheItemSize;
            }
        }
    });
}

- (void)balanceDiskUsage {
    if (_diskCacheUsage < self.diskCapacity) {
        return; // Already done
    }
    
    dispatch_async_afreentrant(get_disk_cache_queue(), ^{
        NSMutableArray *keysToRemove = [NSMutableArray array];
        
        // Apply LRU cache eviction algorithm while disk usage outreach capacity
        NSDictionary *sizes = [self.diskCacheInfo objectForKey:kOLImageCacheInfoSizesKey];
        
        NSInteger capacityToSave = _diskCacheUsage - self.diskCapacity;
        NSArray *sortedKeys = [[self.diskCacheInfo objectForKey:kOLImageCacheInfoAccessesKey] keysSortedByValueUsingSelector:@selector(compare:)];
        NSEnumerator *enumerator = [sortedKeys objectEnumerator];
        NSString *cacheKey;
        
        while (capacityToSave > 0 && (cacheKey = [enumerator nextObject])) {
            [keysToRemove addObject:cacheKey];
            capacityToSave -= [(NSNumber *)[sizes objectForKey:cacheKey] unsignedIntegerValue];
        }
        
        [self removeCachedResponseForCachedKeys:keysToRemove];
        [self saveCacheInfo];
    });
}

- (NSString *)filePathForURL:(NSURL *)URL {
    NSString *cacheKey = [[self class] cacheKeyForURL:URL];
    NSString *cacheFilePath = [_diskCachePath stringByAppendingPathComponent:cacheKey];
    return cacheFilePath;
}

- (void)storeImageToDisk:(NSURL *)URL imageData:(NSData *)imageData {
    dispatch_async(get_disk_io_queue(), ^{
        NSString *cacheKey = [[self class] cacheKeyForURL:URL];
        NSString *cacheFilePath = [self filePathForURL:URL];
        
        [self createDiskCachePath];
        
        NSFileManager *fileManager = NSFileManager.new;
        [fileManager createFileAtPath:cacheFilePath contents:imageData attributes:nil];
        // Update disk usage info
        NSNumber *cacheItemSize = [[fileManager attributesOfItemAtPath:cacheFilePath error:NULL] objectForKey:NSFileSize];
        
        dispatch_async_afreentrant(get_disk_cache_queue(), ^{
            NSNumber *previousCacheItemSize = [[self.diskCacheInfo objectForKey:kOLImageCacheInfoSizesKey] objectForKey:cacheKey];
            _diskCacheUsage -= [previousCacheItemSize unsignedIntegerValue];
            _diskCacheUsage += [cacheItemSize unsignedIntegerValue];
            
            // Update cache info for the stored item
            [(NSMutableDictionary *)[self.diskCacheInfo objectForKey:kOLImageCacheInfoAccessesKey] setObject:[NSDate date] forKey:cacheKey];
            [(NSMutableDictionary *)[self.diskCacheInfo objectForKey:kOLImageCacheInfoSizesKey] setObject:cacheItemSize forKey:cacheKey];
            
            [self saveCacheInfo];
            
            // start timer for cleanup (rely on fact that dispatch_suspend syncs with disk cache queue)
            if (_timerPaused) {
                _timerPaused = NO;
                dispatch_resume([self maintenanceTimer]);
            }
        });
    });
}

- (void)removeCachedResponseForURL:(NSURL *)URL {
    [self removeCachedResponseForCachedKeys:[NSArray arrayWithObject:[[self class] cacheKeyForURL:URL]]];
    [self saveCacheInfo];
}

- (void)removeAllCachedResponses {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    [fileManager removeItemAtPath:_diskCachePath error:NULL];
    dispatch_async_afreentrant(get_disk_cache_queue(), ^{
        self.diskCacheInfo = nil;
    });
}

- (void)queryDiskCacheForURL:(NSURL *)url
                        done:(void (^)(UIImage *image, NSData *imageData))doneBlock {
    if (!doneBlock)
        return;
    if (!url)
    {
        doneBlock(nil, nil);
        return;
    }
    
    NSString *cacheKey = [[self class] cacheKeyForURL:url];
    
    __block UIImage *image = nil;
    __block NSData *imageData = nil;
    dispatch_sync(get_disk_cache_queue(), ^{
        NSMutableDictionary *accesses = [self.diskCacheInfo objectForKey:kOLImageCacheInfoAccessesKey];
        if ([accesses objectForKey:cacheKey]) { // OPTI: Check for cache-hit in a in-memory dictionnary before to hit the FS
            @try {
                imageData = [NSData dataWithContentsOfFile:[_diskCachePath stringByAppendingPathComponent:cacheKey]];
                if (imageData) {
                    // OPTI: Log the entry last access time for LRU cache eviction algorithm but don't save the dictionary
                    //       on disk now in order to save IO and time
                    [accesses setObject:[NSDate date] forKey:cacheKey];
                    _diskCacheInfoDirty = YES;
                    
                    image = [UIImage imageWithData:imageData];
                }
            }
            @catch (NSException *exception) {
                if ([exception.name isEqualToString:NSInvalidArgumentException]) {
                    NSLog(@"Could not unarchive object at %@, Invalid archive!", [_diskCachePath stringByAppendingPathComponent:cacheKey]);
                    [self removeCachedResponseForURL:url];
                }
            }
            @finally {
                // do nothing
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            doneBlock(image, imageData);
        });
    });
    
}

// called in NSTimer
- (void)periodicMaintenance {
    if (_diskCacheUsage > self.diskCapacity) {
        dispatch_async(get_disk_io_queue(), ^{
            [self balanceDiskUsage];
        });
    }
    else if (_diskCacheInfoDirty) {
        dispatch_async(get_disk_io_queue(), ^{
            [self saveCacheInfo];
        });
    }
}

+ (NSString *)defaultCachePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:kOLImageCachePath];
}

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity cacheName:(NSString *)name {
    if ((self = [super init])) {
        self.minCacheInterval = kOLImageCacheInfoDefaultMinCacheInterval;
        _cacheName = name;
        self.diskCachePath = [[[self class] defaultCachePath] stringByAppendingPathComponent:name];
        _memoryCapacity = memoryCapacity;
        _diskCapacity = diskCapacity;
        [self createDiskCachePath];
	}
    
    return self;
}

- (id)initWithName:(NSString *)name {
    self = [self initWithMemoryCapacity:1024*1024   // 1MB mem cache
                           diskCapacity:1024*1024*10 // 10MB disk cache
                              cacheName:name];
    if (self) {
    }
    return self;
}

+ (OLImageCache *)cacheWithName:(NSString *)name {
    return [[OLImageCache alloc]initWithName:name];
}

- (NSUInteger)memoryCapacity {
    return _memoryCapacity;
}

- (NSUInteger)diskCapacity {
    return _diskCapacity;
}


- (BOOL)isCached:(NSURL *)url {
    NSString *cacheKey = [[self class] cacheKeyForURL:url];
    NSString *cacheFile = [_diskCachePath stringByAppendingPathComponent:cacheKey];
    
    BOOL isCached = [[[NSFileManager alloc] init] fileExistsAtPath:cacheFile];
    return isCached;
}

- (void)dealloc {
    if(_maintenanceTimer) {
        dispatch_source_cancel(_maintenanceTimer);
        dispatch_release(_maintenanceTimer);
    }
    _diskCachePath = nil;
    _diskCacheInfo = nil;
}

@end
