//
//  ImageDownloadReceiver.h
//  iPlus
//
//  Created by junmin liu on 11-7-26.
//  Copyright 2011年 Openlab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageDownloadReceiver : NSObject {
    id      imageContainer;
	CGRect displayRect;
	int failedCount;
	float progress;
	float max;
}

@property (nonatomic, assign) id imageContainer;
@property (nonatomic, assign) CGRect displayRect;
@property (nonatomic, assign) int failedCount; 


- (id)initWithContainer:(id)container;

@end
