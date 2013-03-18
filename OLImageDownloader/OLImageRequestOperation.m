//
//  OLImageRequest.m
//  OLImageDownloader
//
//  Created by junmin liu on 12-12-19.
//  Copyright (c) 2012年 openlab Inc. All rights reserved.
//

#import "OLImageRequestOperation.h"
#import <ImageIO/ImageIO.h>

#define kOLImageRequestTimeOutInSeconds 30
#define kOLImageRequestVersion @"1.0"

NSString* const NetworkRequestErrorDomain = @"OLImageRequestErrorDomain";
NSString* const ImageErrorDomain = @"OLImageErrorDomain";

static NSString *defaultUserAgent = nil;


@interface OLImageRequestOperation ()

@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, strong) NSMutableData *imageData;
@property (nonatomic, assign) unsigned long long expectedSize;
@property (nonatomic, assign) unsigned long long partialDownloadSize;
@property (nonatomic, assign, getter = isExecuting) BOOL executing;
@property (nonatomic, assign, getter = isFinished) BOOL finished;
@property (nonatomic, strong) NSURLConnection *connection;

// The location that files will be downloaded to. Once a download is complete, files will be moved to downloadDestinationPath
@property (nonatomic, copy) NSString *temporaryFileDownloadPath;
// Used for writing data to a file when downloadDestinationPath is set
@property (nonatomic, strong) NSOutputStream *fileDownloadOutputStream;

@property (nonatomic, strong) NSMutableArray *requestCookies;

@property (copy, nonatomic) OLImageRequestProgressBlock progressBlock;
@property (copy, nonatomic) OLImageRequestCompletedBlock completedBlock;
@property (copy, nonatomic) void (^cancelBlock)();

@end

@implementation OLImageRequestOperation




+ (NSString *)defaultUserAgentString
{
	@synchronized (self) {
        
		if (!defaultUserAgent) {
            
			NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            
			// Attempt to find a name for this application
			NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
			if (!appName) {
				appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
			}
            
			NSData *latin1Data = [appName dataUsingEncoding:NSUTF8StringEncoding];
			appName = [[NSString alloc] initWithData:latin1Data encoding:NSISOLatin1StringEncoding];
            
			// If we couldn't find one, we'll give up
			if (!appName) {
				return nil;
			}
            
			NSString *appVersion = nil;
			NSString *marketingVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			NSString *developmentVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
			if (marketingVersionNumber && developmentVersionNumber) {
				if ([marketingVersionNumber isEqualToString:developmentVersionNumber]) {
					appVersion = marketingVersionNumber;
				} else {
					appVersion = [NSString stringWithFormat:@"%@ rv:%@",marketingVersionNumber,developmentVersionNumber];
				}
			} else {
				appVersion = (marketingVersionNumber ? marketingVersionNumber : developmentVersionNumber);
			}
            
			NSString *deviceName;
			NSString *OSName;
			NSString *OSVersion;
			NSString *locale = [[NSLocale currentLocale] localeIdentifier];
            
            UIDevice *device = [UIDevice currentDevice];
            deviceName = [device model];
            OSName = [device systemName];
            OSVersion = [device systemVersion];
            
			// Takes the form "My Application 1.0 (iPhone Simulator; iPhone OS 6.0; en_US) (via OLImageDownloader 1.0)"
			[self setDefaultUserAgentString:[NSString stringWithFormat:@"%@ %@ (%@; %@ %@; %@) (via OLImageDownloader %@)",
                                             appName, appVersion, deviceName, OSName, OSVersion, locale, kOLImageRequestVersion]];
		}
		return defaultUserAgent;
	}
	return nil;
}

+ (void)setDefaultUserAgentString:(NSString *)agent
{
    if (defaultUserAgent == agent) {
        return;
    }
	@synchronized (self) {
        defaultUserAgent = agent;
	}
}


- (id)initWithURL:(NSURL *)url
         progress:(OLImageRequestProgressBlock)progressBlock
        completed:(OLImageRequestCompletedBlock)completedBlock
        cancelled:(void (^)())cancelBlock {
    self = [super init];
    if (self) {
        _url = url;
        self.request = [NSMutableURLRequest requestWithURL:self.url
                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                           timeoutInterval:kOLImageRequestTimeOutInSeconds];
        self.progressive = NO;
        _temporaryFileDownloadPath = nil;
        self.requestCookies = [NSMutableArray array];
        
        _imageDecoderQueue = dispatch_queue_create("com.openlab.OLImageRequest.imageDecoder", NULL);
        _connectionQueue = dispatch_queue_create("com.openlab.OLImageRequest.connection", NULL);
        _progressBlock = [progressBlock copy];
        _completedBlock = [completedBlock copy];
        _cancelBlock = [cancelBlock copy];
        _executing = NO;
        _finished = NO;
    }
    return self;
}

+ (OLImageRequestOperation *)requestWithURL:(NSURL *)url
                          progress:(OLImageRequestProgressBlock)progressBlock
                         completed:(OLImageRequestCompletedBlock)completedBlock
                         cancelled:(void (^)())cancelBlock {
    return [[OLImageRequestOperation alloc] initWithURL:url progress:progressBlock completed:completedBlock cancelled:cancelBlock];
}


- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent
{
    return YES;
}



- (void)closeStream {
    if (_fileDownloadOutputStream) {
        [_fileDownloadOutputStream close];
        _fileDownloadOutputStream = nil;
    }
}

- (void)done
{
    [self reset];
    self.finished = YES;
    self.executing = NO;
}

- (void)reset
{
    [self.connection cancel];
    self.connection= nil;
    [self closeStream];
    self.cancelBlock = nil;
    self.completedBlock = nil;
    self.progressBlock = nil;
    self.connection = nil;
    self.imageData = nil;
}

- (void) dealloc {
    [self reset];
    dispatch_release(_imageDecoderQueue);
    dispatch_release(_connectionQueue);
}

- (void)setImageCache:(OLImageCache *)imageCache {
    if (imageCache != _imageCache) {
        _imageCache = imageCache;
        self.downloadDestinationPath = [self.imageCache filePathForURL:self.url];;
    }
}

- (void)setDownloadDestinationPath:(NSString *)downloadDestinationPath {
    if (![_downloadDestinationPath isEqualToString:downloadDestinationPath]) {
        _downloadDestinationPath = downloadDestinationPath;
        _temporaryFileDownloadPath = nil;
        [self closeStream];
    }
}

- (NSString *)temporaryFileDownloadPath {
    if (!_temporaryFileDownloadPath && self.downloadDestinationPath) {
        _temporaryFileDownloadPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[self.downloadDestinationPath md5String]];
    }
    return _temporaryFileDownloadPath;
}

- (NSOutputStream *)fileDownloadOutputStream {
    return _fileDownloadOutputStream;
}

- (void)failWithError:(NSError *)error
{
    NSLog(@"download error: %@", error);
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (self.completedBlock) {
            self.completedBlock(nil, nil, error, YES);
        }
        [self done];
    });
    
}

- (void)updatePartialDownloadSize
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	if (self.downloadDestinationPath && self.temporaryFileDownloadPath
        && [fileManager fileExistsAtPath:self.temporaryFileDownloadPath]) {
		NSError *err = nil;
        long long size = [[fileManager attributesOfItemAtPath:[self temporaryFileDownloadPath] error:&err] fileSize];
		if (err) {
            NSLog(@"Failed to get attributes for file at path '%@'",self.temporaryFileDownloadPath);
            /*
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:OLImageRequestErrorTypeFileManagementError
                                                userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to get attributes for file at path '%@'",[self temporaryFileDownloadPath]],NSLocalizedDescriptionKey,err,NSUnderlyingErrorKey,nil]]];
             */
            [self setPartialDownloadSize:0];
		}
        else {
            [self setPartialDownloadSize:size];
        }
	}
}

- (void)addRequestHeader:(NSString *)headerKey value:(NSString *)headerValue {
    [self.request setValue:headerValue forHTTPHeaderField:headerKey];
}

- (void)applyCookieHeader
{
    
	// Add cookies from the persistent (mac os global) store
	NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[self.url absoluteURL]];
    if (cookies) {
        [[self requestCookies] addObjectsFromArray:cookies];
    }
	
	// Apply request cookies
	cookies = [self requestCookies];

	if ([cookies count] > 0) {
		NSHTTPCookie *cookie;
		NSString *cookieHeader = nil;
		for (cookie in cookies) {
			if (!cookieHeader) {
				cookieHeader = [NSString stringWithFormat: @"%@=%@",[cookie name],[cookie value]];
			} else {
				cookieHeader = [NSString stringWithFormat: @"%@; %@=%@",cookieHeader,[cookie name],[cookie value]];
			}
		}
		if (cookieHeader) {
			[self addRequestHeader:@"Cookie" value:cookieHeader];
		}
	}
}

- (void)buildRequestHeaders
{	
	[self applyCookieHeader];
	
	// Build and set the user agent string if the request does not already have a custom user agent specified
	NSString *tempUserAgentString = [self userAgentString];
    if (!tempUserAgentString) {
        tempUserAgentString = [[self class] defaultUserAgentString];
    }
    if (tempUserAgentString) {
        [self addRequestHeader:@"User-Agent" value:tempUserAgentString];
    }
	
	// Should this request resume an existing download?
	[self updatePartialDownloadSize];
	if ([self partialDownloadSize]) {
        [self addRequestHeader:@"Range" value:[NSString stringWithFormat:@"bytes=%llu-",[self partialDownloadSize]]];
	}
}

- (void)startDownload {
    [self buildRequestHeaders];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.executing = YES;
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                          delegate:self
                                                  startImmediately:NO];
        // Ensure we aren't blocked by UI manipulations (default runloop mode for NSURLConnection is NSEventTrackingRunLoopMode)
        [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                   forMode:NSRunLoopCommonModes];
        
        [self.connection start];
        
        if (!self.connection) {
            if (self.completedBlock)
            {
                self.completedBlock(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Connection can't be initialized"}], YES);
            }
            [self done];
        }
    });
}

- (void)start {
    if (self.isCancelled)
    {
        [self done];
        return;
    }

    if (self.imageCache) {
        // load it from local cache first
        [self.imageCache queryDiskCacheForURL:self.url done:^(UIImage *image, NSData *imageData)
         {
             if (image)
             {
                 if (self.completedBlock) {
                     self.completedBlock(image, imageData, nil, YES);
                 }
                 [self done];
             }
             else {
                 [self startDownload];
             }
         }];
    }
    else {
        [self startDownload];
    }
}

- (void)cancel {
    if (self.isFinished) return;
        return;
    [super cancel];
    if (self.cancelBlock)
        self.cancelBlock();
    
    if (self.connection)
    {
        [self.connection cancel];
        self.connection = nil;
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    [self done];
}

- (void)moveTemporaryFileToDestination {
    if (!self.temporaryFileDownloadPath) {
        return;
    }
    
    //Move the temporary file to the destination path
    NSError *moveError = nil;
    NSError *fileError = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.downloadDestinationPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.downloadDestinationPath error:&fileError];
    }
    [[NSFileManager defaultManager] moveItemAtPath:[self temporaryFileDownloadPath] toPath:self.downloadDestinationPath error:&moveError];
    if (moveError) {
        fileError = [NSError errorWithDomain:NetworkRequestErrorDomain code:OLImageRequestErrorTypeFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to move file from '%@' to '%@'",[self temporaryFileDownloadPath],self.downloadDestinationPath],NSLocalizedDescriptionKey,moveError,NSUnderlyingErrorKey,nil]];
    }
}

- (void)deleteFiles {
    if (!self.temporaryFileDownloadPath) {
        return;
    }
    NSError *fileError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.temporaryFileDownloadPath error:&fileError];
    [[NSFileManager defaultManager] removeItemAtPath:self.downloadDestinationPath error:&fileError];
}

- (void)downloadCompletedWithImage:(UIImage *)image
                         imageData:(NSData *)imageData
                          finished:(BOOL)finished {
    if (finished) {
        self.finished = YES;
    }
    if (!finished && self.finished) { // If we already has downloaded finished, then we don't need to notify the unfinished state.
        return;
    }
        if (!finished && self.finished) { // Double check
            return;
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (self.completedBlock)
            {
                self.completedBlock(image, imageData, nil, finished);
            }
            if (finished) {
                [self done];
            }
        });
}

#pragma mark NSURLConnection (delegate)

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response
{
    if (![response respondsToSelector:@selector(statusCode)] || [((NSHTTPURLResponse *)response) statusCode] < 400)
    {
        self.expectedSize = response.expectedContentLength > 0 ? (NSUInteger)response.expectedContentLength : 0;
        NSDictionary *httpHeaders = [((NSHTTPURLResponse *)response) allHeaderFields];
        
        if (!_fileDownloadOutputStream && self.temporaryFileDownloadPath) {
            BOOL append = NO;
            if ([self.request valueForHTTPHeaderField:@"Range"]) {
                if ([httpHeaders objectForKey:@"Content-Range"]) {
                    append = YES;
                }
                else {
                    [self setPartialDownloadSize:0];
                }
            }
            _fileDownloadOutputStream = [[NSOutputStream alloc] initToFileAtPath:[self temporaryFileDownloadPath] append:append];
        }
        
        if (self.progressBlock)
        {
            self.progressBlock(self.partialDownloadSize, self.expectedSize);
        }
        
        if(!self.fileDownloadOutputStream)
            self.imageData = [NSMutableData dataWithCapacity:self.expectedSize];
        else {
            self.imageData = nil;
            [self.fileDownloadOutputStream open];
        }
        
        // Handle cookies
        NSArray *newCookies = [NSHTTPCookie cookiesWithResponseHeaderFields:httpHeaders forURL:self.url];
        // Store cookies in global persistent store
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:newCookies forURL:self.url mainDocumentURL:nil];

    }
    else
    {
        [self.connection cancel];
        self.connection = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (self.completedBlock)
            {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:[((NSHTTPURLResponse *)response) statusCode] userInfo:nil];
                self.completedBlock(nil, nil, error, YES);
            }
            [self done];
        });
        
    }
}

// http://stackoverflow.com/questions/1446509/handling-redirects-correctly-with-nsurlconnection
- (NSURLRequest *)connection: (NSURLConnection *)inConnection
             willSendRequest: (NSURLRequest *)inRequest
            redirectResponse: (NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) {
        NSMutableURLRequest *r = [self.request mutableCopy];
        [r setURL: [inRequest URL]];
        
        return r;
    } else {
        return inRequest;
    }
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
    dispatch_async(_connectionQueue, ^{
        
        if(!self.fileDownloadOutputStream)
            [self.imageData appendData:data];
        else {
            const uint8_t *dataBuffer = [data bytes];
            [self.fileDownloadOutputStream write:&dataBuffer[0] maxLength:[data length]];
        }
        
        self.partialDownloadSize += [data length];
        
        // If the image was downloaded, we need not to update partial image.
        if (self.progressive && self.expectedSize > 0
            && self.completedBlock)
        {
            dispatch_async(_imageDecoderQueue, ^
            {
                if (self.finished || self.isCancelled) {
                    return ;
                }
                // The following code is from http://www.cocoaintheshell.com/2011/05/progressive-images-download-imageio/
                // Thanks to the author @Nyx0uf
                
                // Get the total bytes downloaded
                const NSUInteger totalSize = [self.imageData length];
                
                // Update the data source, we must pass ALL the data, not just the new bytes
                CGImageSourceRef imageSource = NULL;
                if (self.fileDownloadOutputStream) {
                    NSURL *tempFileUrl = [NSURL fileURLWithPath:self.temporaryFileDownloadPath];
                    if (!tempFileUrl) {
                        NSLog(@"* * Bad input file path");
                        return;
                    }
                    imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)tempFileUrl, NULL);
                }
                else {
                    imageSource = CGImageSourceCreateIncremental(NULL);
                    CGImageSourceUpdateData(imageSource, (__bridge  CFDataRef)self.imageData, totalSize == self.expectedSize);
                }
                
                if (_width + _height == 0 && imageSource)
                {
                    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
                    if (properties)
                    {
                        CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
                        if (val) CFNumberGetValue(val, kCFNumberLongType, &_height);
                        val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
                        if (val) CFNumberGetValue(val, kCFNumberLongType, &_width);
                        CFRelease(properties);
                    }
                }
                
                if (_width + _height > 0 && totalSize < self.expectedSize && imageSource)
                {
                    // Create the image
                    CGImageRef partialImageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
                    
                    if (partialImageRef)
                    {
                        const size_t partialHeight = CGImageGetHeight(partialImageRef);
                        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                        CGContextRef bmContext = CGBitmapContextCreate(NULL, _width, _height, 8, _width * 4, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
                        CGColorSpaceRelease(colorSpace);
                        if (bmContext)
                        {
                            CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = _width, .size.height = partialHeight}, partialImageRef);
                            CGImageRelease(partialImageRef);
                            partialImageRef = CGBitmapContextCreateImage(bmContext);
                            CGContextRelease(bmContext);
                        }
                        else
                        {
                            CGImageRelease(partialImageRef);
                            partialImageRef = nil;
                        }
                    }
                    if (partialImageRef)
                    {
                        UIImage *image = [UIImage imageWithCGImage:partialImageRef];
                        UIImage *decompressedImage = [UIImage decodedImageWithImage:image];
                        [self downloadCompletedWithImage:decompressedImage imageData:nil finished:NO];
                        
                        CGImageRelease(partialImageRef);
                    }
                }
                if (imageSource) {
                    CFRelease(imageSource);
                }
                
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (self.progressBlock)
            {
                self.progressBlock(self.partialDownloadSize, self.expectedSize);
            }
        });
    });
    

}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
    self.connection = nil;
    
    __weak OLImageRequestOperation *wself = self;
    dispatch_async(_connectionQueue, ^
    {
        if (!wself) {
            return;
        }
        NSMutableData *data;
        UIImage *image;
        if (self.temporaryFileDownloadPath) {
            data = [NSData dataWithContentsOfFile:self.temporaryFileDownloadPath];
        }
        else {
            data = self.imageData;
        }
        self.partialDownloadSize = data.length;
        image = [[UIImage alloc] initWithData:data];
        [self closeStream];
        self.finished = YES; // Set the operation as finished
        if (!image || CGSizeEqualToSize(image.size, CGSizeZero) || self.expectedSize != self.partialDownloadSize) { // It's not a valid image
            NSLog(@"url: %@", self.url);
            NSLog(@"path: %@", self.temporaryFileDownloadPath);
            NSError *err = [NSError errorWithDomain:ImageErrorDomain
                                               code:OLImageRequestErrorTypeInvalidImage
                                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"It's not a valid image", NSLocalizedDescriptionKey, nil]];
            [self deleteFiles]; // If it's not a valid image, delete the local files, so that it can be downloaded from zero again.
            [self failWithError:err];
        }
        else {
            dispatch_async(_imageDecoderQueue, ^{
                UIImage *decompressedImage = [UIImage decodedImageWithImage:image];
                [self downloadCompletedWithImage:decompressedImage imageData:data finished:YES];
                if (self.imageCache) { // Just cache it then delete the temporary File
                    [self.imageCache storeImageToDisk:self.url imageData:data];
                    NSError *fileError = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:self.temporaryFileDownloadPath error:&fileError];
                }
                else {
                    [self moveTemporaryFileToDestination];
                }
            });
        }
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

//prevent caching of responses in Cache.db
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}


@end

@implementation UIImage (ForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image
{
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image.CGImage);
    BOOL imageHasAlphaInfo = (alphaInfo != kCGImageAlphaNone &&
                              alphaInfo != kCGImageAlphaNoneSkipFirst &&
                              alphaInfo != kCGImageAlphaNoneSkipLast);
    
    UIGraphicsBeginImageContextWithOptions(image.size, !imageHasAlphaInfo, 0);
    CGRect rect = (CGRect){.origin = CGPointZero, .size = image.size};
    [image drawInRect:rect];
    UIImage *decompressedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (!decompressedImage)
    {
        // If really have any error occurs, we use the original image at this moment
        decompressedImage = image;
    }

    
    return decompressedImage;
}

@end
