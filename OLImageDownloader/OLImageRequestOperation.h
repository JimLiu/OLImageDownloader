//
//  OLImageRequest.h
//  OLImageDownloader
//
//  Created by junmin liu on 12-12-19.
//  Copyright (c) 2012年 openlab Inc. All rights reserved.
//
//  Reference codes:
//      https://github.com/rs/sdwebimage
//      https://github.com/MugunthKumar/MKNetworkKit
//      http://allseeing-i.com/ASIHTTPRequest/

#import <Foundation/Foundation.h>
#import "OLImageCache.h"
#import "NSStringExtension.h"
#import "OLImageOperationHandler.h"

typedef enum {
    OLImageRequestErrorTypeConnectionFailure = 1,
    OLImageRequestErrorTypeRequestTimedOut = 2,
    OLImageRequestErrorTypeAuthentication = 3,
    OLImageRequestErrorTypeRequestCancelled = 4,
    OLImageRequestErrorTypeUnableToCreateRequest = 5,
	OLImageRequestErrorTypeFileManagementError = 6,
	OLImageRequestErrorTypeTooMuchRedirection = 7,
	OLImageRequestErrorTypeInvalidImage = 8,
	OLImageRequestErrorTypeUnhandledExceptionError = 99
} OLImageRequestErrorType;

@interface OLImageRequestOperation : NSOperation {
    size_t _width, _height;
    
    dispatch_queue_t _connectionQueue;
    dispatch_queue_t _imageDecoderQueue;
}

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, copy) NSString *userAgentString;
@property (nonatomic, assign) BOOL progressive;
// When downloadDestinationPath is set, the result of this request will be downloaded to the file at this location
// If downloadDestinationPath is not set, download data will be stored in memory
@property (nonatomic, copy) NSString *downloadDestinationPath;
@property (nonatomic, strong) OLImageCache *imageCache;

- (id)initWithURL:(NSURL *)url
         progress:(OLImageRequestProgressBlock)progressBlock
        completed:(OLImageRequestCompletedBlock)completedBlock
        cancelled:(void (^)())cancelBlock;

+ (OLImageRequestOperation *)requestWithURL:(NSURL *)url
                          progress:(OLImageRequestProgressBlock)progressBlock
                         completed:(OLImageRequestCompletedBlock)completedBlock
                         cancelled:(void (^)())cancelBlock;



@end


@interface UIImage (ForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image;

@end
