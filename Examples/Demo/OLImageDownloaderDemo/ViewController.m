//
//  ViewController.m
//  OLImageDownloaderDemo
//
//  Created by junmin liu on 12-12-2.
//  Copyright (c) 2012年 openlab Inc. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
@synthesize startButton = _startButton;
@synthesize cancelButton = _cancelButton;
@synthesize progressView = _progressView;
@synthesize imageView = _imageView;
@synthesize imageView2 = _imageView2;

- (void)viewDidLoad
{
    [super viewDidLoad];
    //
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)start:(id)sender {
    [self cancel:nil];
    NSURL *url = [NSURL URLWithString:@"http://farm9.staticflickr.com/8528/8507439532_72c023906f.jpg"];
    OLImageDownloader *downloader = [OLImageDownloader downloaderWithName:@"images"];
    _handler1 = [downloader downloadImageWithURL:url highPriority:NO progressive:YES progress:^(NSUInteger receivedSize, long long expectedSize)
    {
        NSLog(@"download1 progress: %d/%lld", receivedSize, expectedSize);
    }
    completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished)
    {
        NSLog(@"download1 update image: %f/%f", image.size.width, image.size.height);
        self.imageView.image = image;
        if (finished) {
            _handler1 = nil;
        }
        if (error) {
            NSLog(@"download error: %@", error);
        }
    }];
    /*
    if (!_request) {
        _request = [OLImageRequestOperation
                    requestWithURL:url
                    progress:^(NSUInteger receivedSize, long long expectedSize)
                    {
                        NSLog(@"download1 progress: %d/%lld", receivedSize, expectedSize);
                    }
                    completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished)
                    {
                        self.imageView.image = image;
                        if (finished) {
                            _request = nil;
                        }
                        if (error) {
                            NSLog(@"download error: %@", error);
                        }
                    }
                    cancelled:^
                    {}
                    ];
    }
    url = [NSURL URLWithString:@"http://farm9.staticflickr.com/8200/8280278840_3aed7e730b_b.jpg"];
    if (!_request2) {
        _request2 = [OLImageRequestOperation
                     requestWithURL:url
                     progress:^(NSUInteger receivedSize, long long expectedSize)
                     {
                         NSLog(@"download2 progress: %d/%lld", receivedSize, expectedSize);                         
                     }
                     completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished)
                     {
                         self.imageView2.image = image;
                         if (finished) {
                             _request2 = nil;
                         }
                         if (error) {
                             NSLog(@"download error: %@", error);
                         }
                     }
                     cancelled:^
                     {}
                     ];
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"xx.png"];

    _request.downloadDestinationPath = dataPath;
    dataPath = [documentsDirectory stringByAppendingPathComponent:@"yy.jpg"];
    _request2.downloadDestinationPath = dataPath;
    _request.progressive = YES;
    _request2.progressive = YES;
    //[_request2 performSelectorInBackground:@selector(start) withObject:nil];
    //[_request performSelectorInBackground:@selector(start) withObject:nil];
    self.imageView.image = nil;
    self.imageView2.image = nil;
    [_request start];
    //[_request2 start];
     */
}

- (IBAction)cancel:(id)sender {
    if (_handler1) {
        [_handler1 cancel];
        _handler1 = nil;
    }
    if (_request) {
        [_request cancel];
        _request = nil;
    }
    if (_request2) {
        [_request2 cancel];
        _request2 = nil;
    }
}


@end
