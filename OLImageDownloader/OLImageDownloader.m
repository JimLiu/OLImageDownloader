//
//  OLImageDownloader.m
//  OLImageDownloaderDemo
//
//  Created by junmin liu on 13-3-2.
//  Copyright (c) 2013年 openlab Inc. All rights reserved.
//

#import "OLImageDownloader.h"

@interface OLImageDownloader (  ) 

@property (strong, nonatomic) NSOperationQueue *downloadQueue;
// Current downloading requests.
@property (nonatomic, strong) NSMutableArray *activeRequests;
// An array is used to store the image urls which are ready to download.
@property (nonatomic, strong) NSMutableArray *pendingUrls;
// All the image download operations for url
@property (nonatomic, strong) NSMutableDictionary *urlToHandlers;


@end

@implementation OLImageDownloader

static NSMutableDictionary *gDownloaders;

- (id)initWithImageCache:(OLImageCache *)imageCache
{
    if ((self = [super init]))
    {
        _imageCache = imageCache;
        _downloadQueue = NSOperationQueue.new;
        _downloadQueue.maxConcurrentOperationCount = 2;
        _notificationsQueue = dispatch_queue_create("com.openlab.OLImageDownloader.notificationsQueue", NULL);
        _barrierQueue = dispatch_queue_create("com.openlab.OLImageDownloader.barrierQueue", NULL);
        _activeRequests = [[NSMutableArray alloc] init];
        _pendingUrls = [[NSMutableArray alloc] init];
        _urlToHandlers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithName:(NSString *)name {
    self = [self initWithImageCache:[OLImageCache cacheWithName:name]];
    return self;
}

// Get a shared instance with name
+ (OLImageDownloader *)downloaderWithName:(NSString *)name {
    static dispatch_once_t once;
    dispatch_once(&once, ^{gDownloaders = NSMutableDictionary.new;});
    OLImageDownloader *downloader = nil;
    if (name) {
        @synchronized(gDownloaders)
        {
            if (!(downloader = gDownloaders[name])) {
                downloader = [[OLImageDownloader alloc] initWithName:name];
                gDownloaders[name] = downloader;
            }
            
        }
    }
    return downloader;
}

- (void)dealloc
{
    [self.downloadQueue cancelAllOperations];
    self.downloadQueue = nil;
    dispatch_release(_notificationsQueue);
    dispatch_release(_barrierQueue);
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads
{
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSInteger)maxConcurrentDownloads
{
    return _downloadQueue.maxConcurrentOperationCount;
}

- (void)removeFromPendingsByUrl:(NSString *)url {
    dispatch_barrier_sync(_barrierQueue, ^
    {
        [_pendingUrls removeObject:url];
    });
}

- (void)removeRequestByUrl:(NSString *)url {
    dispatch_barrier_sync(_barrierQueue, ^
    {
        [_pendingUrls removeObject:url];
        
        OLImageRequestOperation *request = nil;
        for (OLImageRequestOperation * r in _activeRequests) {
            if ([r.url.absoluteString isEqualToString:url]) {
                request = r;
                break;
            }
        }
        if (request) {
            [_activeRequests removeObject:request];
        }
    });
}

- (void)insertRequestToPendings:(NSString *)url
                        atIndex:(int)index {
    dispatch_barrier_sync(_barrierQueue, ^
    {
        [_pendingUrls insertObject:url atIndex:index];
    });
}

- (void)addRequestToPendings:(NSString *)url {
    dispatch_barrier_sync(_barrierQueue, ^
    {
        [_pendingUrls addObject:url];
    });
}

- (OLImageRequestOperation *)popRequest {
    OLImageRequestOperation *request = nil;
    if (_activeRequests.count > 0) {
        request = [_activeRequests objectAtIndex:0];
    }
    return request;
}

- (NSString *)popPendingUrl {
    __block NSString *url = nil;
    dispatch_barrier_sync(_barrierQueue, ^
    {
        if (_pendingUrls.count > 0) {
            url = [_pendingUrls objectAtIndex:0];
            [_pendingUrls removeObjectAtIndex:0];
        }
    });
    return url;
}

- (void)addHandler:(OLImageOperationHandler *)handler {
    NSString *url = [handler.url absoluteString];
    if (!url || !handler) {
        return;
    }
    dispatch_barrier_sync(_barrierQueue, ^
    {
        NSMutableArray *handlers = [_urlToHandlers objectForKey:url];
        if (!handlers) {
            handlers = [NSMutableArray array];
        }
        if (![handlers containsObject:handler]) {
            [handlers addObject:handler];
        }
        [_urlToHandlers setObject:handlers forKey:url];
    });
}

- (void)removeHandler:(OLImageOperationHandler *)handler
{
    NSString *url = [handler.url absoluteString];
    dispatch_barrier_sync(_barrierQueue, ^
    {
        NSMutableArray *handlers = [_urlToHandlers objectForKey:url];
        if (handlers) {
            [handlers removeObject:handler];
        }
    });
}

- (void)removeHandlersByUrl:(NSString *)url {
    dispatch_barrier_sync(_barrierQueue, ^
    {
        [_urlToHandlers removeObjectForKey:url];
    });
}

- (BOOL)isDownloading:(NSString *)url {
    __block BOOL downloading = NO;
    dispatch_barrier_sync(_barrierQueue, ^
    {
        OLImageRequestOperation *request = nil;
        for (OLImageRequestOperation * r in _activeRequests) {
            if ([r.url.absoluteString isEqualToString:url]) {
                request = r;
                break;
            }
        }
        if (request) {
            downloading = YES;
        }
    });
    return downloading;
}

- (NSMutableArray *)handlersForUrl:(NSString *)url {
    NSMutableArray *handlers = [_urlToHandlers objectForKey:url];
    if (handlers) {
        handlers = [NSMutableArray arrayWithArray:handlers];
    }
    return handlers;
}

- (void)startDownloadingWithURL:(NSURL *)URL
                    progressive:(BOOL)progressive {
    OLImageRequestOperation *request = [self requestImageWithURL:URL];
    if (progressive) {
        request.progressive = YES;
    }

    if (request) {
        dispatch_barrier_sync(_barrierQueue, ^
        {
            [_activeRequests addObject:request];
        });
        [self.downloadQueue addOperation:request];
    }    
}

- (void)downloadAnotherImageFromPending {
    NSString *url = [self popPendingUrl];
    if (url) {
        BOOL progressive = NO;
        NSArray *handlers = [self handlersForUrl:url];
        for (OLImageOperationHandler * h in handlers) {
            if (h.progressive) { // If any handler want to display progressively
                progressive = YES;
                break;
            }
        }
        [self startDownloadingWithURL:[NSURL URLWithString:url]
                          progressive:progressive];
    }

    NSLog(@"pedding: %d, active: %d, requests: %d",
          _pendingUrls.count, _activeRequests.count,
          _downloadQueue.operationCount);
}

- (void)notifyHandlers:(NSMutableArray *)handlers
     notificationBlock:(void(^)(OLImageOperationHandler *handler))block {
    for (OLImageOperationHandler *handler in handlers) {
        @try {
            if (handler && block) {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    block(handler);
                });
            }
        }
        @catch (NSException *exception) {
            NSLog(@"Could not access operation with url [%@], Invalid operation!\r\n%@", handler.url, exception);
        }
        @finally {
            // do nothing
        }
    }

}

- (OLImageRequestOperation *)requestImageWithURL:(NSURL *)URL {
    OLImageRequestOperation *request;
    NSString *url = [URL absoluteString];
    __weak OLImageDownloader *wself = self;
    request = [OLImageRequestOperation requestWithURL:URL
    progress:^(NSUInteger receivedSize, long long expectedSize)
    {
        if (!wself) return;
        dispatch_async(_notificationsQueue, ^
        {
            NSMutableArray *handlers = [self handlersForUrl:url];
            if (handlers) {
                [self notifyHandlers:handlers notificationBlock:^(OLImageOperationHandler *handler)
                 {
                     if (handler && handler.progressBlock) {
                         handler.progressBlock(receivedSize, expectedSize);
                     }
                 }];
            }
         });
    }
    completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished)
    {
        if (!wself) return;
        dispatch_async(_notificationsQueue, ^
        {
            NSMutableArray *handlers = [wself handlersForUrl:url];
            if (handlers) {
                [wself notifyHandlers:handlers notificationBlock:^(OLImageOperationHandler *handler)
                 {
                     if (handler && handler.completedBlock) {
                         handler.completedBlock(image, data, error, finished);
                     }
                 }];
            }
            
            if (finished) {
                [self removeHandlersByUrl:url];
                [self removeRequestByUrl:url]; // Remove the request from active queue.
                [self downloadAnotherImageFromPending]; // Pick another one to download
            }
        });
    }
    cancelled:^
    {
        // If request is canceled by downloader, it will be resumed soon, so it's no need to notify.
    }];
    request.imageCache = self.imageCache;
    request.progressive = NO;
    return request;
}

- (OLImageOperationHandler *)downloadImageWithURL:(NSURL *)URL
                                        completed:(OLImageRequestCompletedBlock)completedBlock {
    return [self downloadImageWithURL:URL highPriority:YES progressive:NO progress:nil completed:completedBlock];
}

- (OLImageOperationHandler *)downloadImageWithURL:(NSURL *)URL
                                     highPriority:(BOOL)highPriority
                                        completed:(OLImageRequestCompletedBlock)completedBlock {
    return [self downloadImageWithURL:URL highPriority:highPriority progressive:NO progress:nil completed:completedBlock];
}

- (OLImageOperationHandler *)downloadImageWithURL:(NSURL *)URL
                              highPriority:(BOOL)highPriority
                               progressive:(BOOL)progressive
                                  progress:(OLImageRequestProgressBlock)progressBlock
                                 completed:(OLImageRequestCompletedBlock)completedBlock {
    if ([URL isKindOfClass:NSString.class])
    {
        URL = [NSURL URLWithString:(NSString *)URL];
    }
    if (![URL isKindOfClass:NSURL.class])
    {
        URL = nil;
    }
    OLImageOperationHandler *handler = [[OLImageOperationHandler alloc]initWithURL:URL progress:progressBlock completed:completedBlock cancelled:nil downloader:self];
    handler.progressive = progressive;
    [self addHandler:handler]; // Add operation handler, it can recieve the notifications.
    
    NSString *url = [URL absoluteString];
    if ([self isDownloading:url]) {
        return handler; // Image is being downloaded
    }

    
    if (highPriority) { // if the priority is high, then add it to activity queue, download it immediately
        [self removeFromPendingsByUrl:url];
        if (_activeRequests.count >= self.maxConcurrentDownloads) {
            OLImageRequestOperation *deactiveRequest = [self popRequest]; // Cancel and dequeue an active request
            [deactiveRequest cancel];
            NSString *deactiveRequestUrl = deactiveRequest.url.absoluteString;
            
            [self removeRequestByUrl:deactiveRequestUrl];
            [self insertRequestToPendings:deactiveRequestUrl atIndex:0]; // Dequeue it from activity queue, but enqueue it to pending queue.
        }
        [self startDownloadingWithURL:URL progressive:progressive];// Begin to download image
        
    }
    else {
        if ([_pendingUrls containsObject:url]) {
            return handler; // Image had already been in pending queue
        }
        // if there is no enough active requests, download it immediately
        if (_activeRequests.count < self.maxConcurrentDownloads) {
            [self startDownloadingWithURL:URL progressive:progressive]; // Begin to download image
        }
        else {
            [self addRequestToPendings:url];
        }
    }
    
    
    return handler;
}


@end
