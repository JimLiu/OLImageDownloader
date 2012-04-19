//
//  ImageDownloadReceiver.m
//  iPlus
//
//  Created by junmin liu on 11-7-26.
//  Copyright 2011年 Openlab. All rights reserved.
//

#import "ImageDownloadReceiver.h"


@implementation ImageDownloadReceiver

@synthesize imageContainer, displayRect;
@synthesize failedCount;

- (id)initWithContainer:(id)container {
    self = [super init];
    if (self) {
        imageContainer = container;
    }
    return self;
}

- (void)dealloc
{
    imageContainer = nil;
    [super dealloc];
}

- (void)imageDidDownload:(NSData*)imageData url:(NSString *)url
{
    if (imageContainer) {
        if ([imageContainer respondsToSelector:@selector(imageDidDownload:url:)]) {
            [imageContainer performSelector:@selector(imageDidDownload:url:) withObject:imageData withObject:url];
        }
    }
}

- (void)imageDownloadFailed:(NSError *)error url:(NSString *)url {
	failedCount++;
    if (imageContainer) {
        if ([imageContainer respondsToSelector:@selector(imageDownloadFailed:url:)]) {
            [imageContainer performSelector:@selector(imageDownloadFailed:url:) withObject:error withObject:url];
        }
    }
}

- (void)updateProgress:(NSNumber*)totalBytesReadNumber 
               ofTotal:(NSNumber*)totalSizeNumber {
    if (imageContainer) {
        if ([imageContainer respondsToSelector:@selector(updateProgress:ofTotal:)]) {
            [imageContainer performSelector:@selector(updateProgress:ofTotal:) withObject:totalBytesReadNumber withObject:totalSizeNumber];
        }
    }
}

- (void)setProgress:(NSNumber*)progressNumber {
	float _progress = [progressNumber floatValue];
	if (progress != _progress) {
		progress = _progress;
		if (imageContainer) {
			if ([imageContainer respondsToSelector:@selector(setProgress:)]) {
				[imageContainer performSelector:@selector(setProgress:) withObject:[NSNumber numberWithFloat:progress]];
			}
		}		
	}
}


@end
