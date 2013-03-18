//
//  NSStringExtension.m
//  OLImageDownloaderDemo
//
//  Created by junmin liu on 13-3-4.
//  Copyright (c) 2013年 openlab Inc. All rights reserved.
//

#import "NSStringExtension.h"

@implementation NSString (Extension)

- (NSString *)md5String {
    const char *str = [self UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, strlen(str), r);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
}


@end
