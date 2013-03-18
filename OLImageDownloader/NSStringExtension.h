//
//  NSStringExtension.h
//  OLImageDownloaderDemo
//
//  Created by junmin liu on 13-3-4.
//  Copyright (c) 2013年 openlab Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface NSString (Extension)

- (NSString *)md5String;

@end
