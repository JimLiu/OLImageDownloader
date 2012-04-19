//
//  AppCell.m
//  TopPaid
//
//  Created by junmin liu on 12-4-19.
//  Copyright (c) 2012年 Openlab. All rights reserved.
//

#import "AppCell.h"

@implementation AppCell
@synthesize appRecord = _appRecord;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        _imageDownloadReceiver = [[ImageDownloadReceiver alloc]initWithContainer:self];
    }
    return self;
}

- (void)setAppRecord:(AppRecord *)appRecord {
    
    if (_appRecord != appRecord) {
        if (_appRecord) {
            [[ImageDownloader photosDownloader] removeDelegate:_imageDownloadReceiver forURL:_appRecord.imageURLString];
        }
        [_appRecord release];
        _appRecord = [appRecord retain];
        if (_appRecord) {
            [[ImageDownloader photosDownloader] activeRequest:_appRecord.imageURLString delegate:_imageDownloadReceiver];
        }
        [_image release];
        _image = nil;
        
        self.imageView.image = [UIImage imageNamed:@"Placeholder.png"];
        self.accessoryType = UITableViewCellAccessoryNone;
        self.textLabel.text = appRecord.appName;
        self.detailTextLabel.text = appRecord.artist;

        [self setNeedsDisplay];
    }
}

- (void)dealloc
{
    _imageDownloadReceiver.imageContainer = nil;
    [_imageDownloadReceiver release];
    [_image release];
    [super dealloc];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}



- (void)imageDidDownload:(NSData *)imageData url:(NSString *)url {
    NSLog(@"imageDidDownload: %@", url);
    UIImage *image = [UIImage imageWithData:imageData];
    if (image) {
        [_image release];
        _image = [image retain];
        
        self.imageView.image = _image; //显示图片
        
        [self setNeedsDisplay];
        [self setNeedsLayout];
    }
    
}


- (void)imageDownloadFailed:(NSError *)error url:(NSString *)url {
    NSLog(@"imageDownloadFailed: %@, %@", url, [error localizedDescription]);
}


@end
