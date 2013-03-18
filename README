OLImageDownloader
=========

Asynchronous image downloader with cache support

It provides:

- An asynchronous image downloader
- An asynchronous disk image caching with automatic cache expiration handling
- Resuming interrupted downloads
- Multi-Threaded downloading
- Tracking download progress
- LRU cache cleanup
- Use GCD and ARC

NOTE: Requires iOS 5.0

How To Use
----------

### Using blocks

With blocks, you can be notified about the image download progress and whenever the image retrival
has completed with success or not:

```objective-c
#import "OLImageDownloader.h"

@interface ActivityVideoCell ()
@property (nonatomic, strong) UIImage *avatarImage;
@property (nonatomic, strong) OLImageOperationHandler *avatarImageOperation;

@end


- (void)downloadAvatarImage {
    if (!_avatarImageOperation) {
        NSURL *imageUrl = [NSURL URLWithString:self.layout.activity.user.avatarUrl];
        OLImageDownloader *downloader = [OLImageDownloader shared];
        _avatarImageOperation = [downloader downloadImageWithURL:imageUrl
                                  completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished)
        {
            if (image)
            {
                self.avatarImage = image;
                [self setNeedsDisplay];
            }
            if (finished) {
                _avatarImageOperation = nil;
            }
        }];
    }
}

```

Note: neither your success nor failure block will be call if your image request is canceled before completion.

Installation
------------
It's easy to use this in your project, just copy all the files into your project.

### Add dependencies

- In you application project app’s target settings, find the "Build Phases" section and open the "Link Binary With Libraries" block:
- Click the "+" button again and select the "ImageIO.framework", this is needed by the progressive download feature:

### Import headers in your source files

In the source files where you need to use the library, import the header file:

```objective-c
#import "OLImageDownloader.h"
```

## Reference codes

- [SDWebImage](https://github.com/rs/sdwebimage).
- [SDURLCache](https://github.com/steipete/SDURLCache).
- [MKNetworkKit](https://github.com/MugunthKumar/MKNetworkKit).
- [ASIHTTPRequest](http://allseeing-i.com/ASIHTTPRequest/).

## Licenses

All source code is licensed under the [MIT License](https://github.com/JimLiu/OLImageDownloader/blob/master/LICENSE).