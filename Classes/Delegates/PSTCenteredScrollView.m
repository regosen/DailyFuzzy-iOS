//
//  PSTCenteredScrollView.m
//  PSTCenteredScrollView
//
//  Created by Peter Steinberger on 2/21/13.
//  Copyright (c) 2013 PSPDFKit. All rights reserved.
//
// Copyright (c) 2013 Peter Steinberger <steipete@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is furnished
// to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Modified by Daily Fuzzy to support animated gifs

#import "PSTCenteredScrollView.h"
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/CGImageSource.h>

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVPlayerViewController.h>

@interface PSTCenteredScrollView ()

@property (nonatomic) CGSize screenSize;

@end

@implementation PSTCenteredScrollView

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.delegate = self;

        self.containerView = [[UIView alloc] initWithFrame:frame];

        [self addSubview:self.containerView];
        self.contentSize = self.containerView.frame.size;
    }
    return self;
}

- (BOOL)setVideo:(NSURL*)imageURL fromController:(UIViewController*)pVC
{
    NSString *urlString = [[imageURL absoluteString] stringByReplacingOccurrencesOfString:@".gifv" withString:@".mp4"];
    NSURL *url = [NSURL URLWithString:urlString];
    
    AVPlayer *player = [AVPlayer playerWithURL:url];
    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.showsPlaybackControls = NO;
    playerVC.view.backgroundColor = [UIColor clearColor];
    
    [pVC addChildViewController:playerVC];
    [playerVC.view setFrame: self.containerView.bounds];
    [self.containerView addSubview: playerVC.view];
    UIView* view = [[UIView alloc] initWithFrame:playerVC.view.frame];
    [self.containerView addSubview: view];
    
    [playerVC didMoveToParentViewController:pVC];
    playerVC.player = player;
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[player currentItem]];
    [player play];
    
    return YES;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)setImage:(NSData *)imageData url:(NSURL*)imageURL screenSize:(CGSize)screenSize
{
    self.image = imageData ? [[UIImage alloc] initWithData:imageData] : nil;
    BOOL missingImage = (self.image == nil);
    if (missingImage)
    {
        self.image = [UIImage imageNamed:@"missing-image"];
    }
    [self.imageView removeFromSuperview];
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    BOOL isGif = (imageSource && CGImageSourceGetCount(imageSource) > 1);
    if (imageSource) {
        CFRelease(imageSource);
    }
    
    CGRect frame = CGRectMake(0, 0, self.image.size.width, self.image.size.height);
    self.containerView.frame = frame;
    self.containerView.bounds = frame;
    if (isGif)
    {
        self.webView = [[UIWebView alloc] initWithFrame:frame];
        [self.webView loadData:imageData MIMEType:@"image/tiff" textEncodingName:@"utf-8" baseURL:imageURL];
        
        // HACK: UIWebView intercepts tap gestures unless you cover it with a dummy UIView
        UIView* dummyView = [[UIView alloc] initWithFrame:frame];
        [self.webView addSubview:dummyView];
        
        [self.containerView addSubview:self.webView];
    }
    else
    {
        self.imageView = [[UIImageView alloc] initWithFrame:frame];
        self.imageView.image = self.image;
        [self.containerView addSubview:self.imageView];
    }
    
    [self refreshZoomBounds:screenSize force:YES];
    return !missingImage;
}

- (void) refreshZoomBounds:(CGSize)screenSize force:(BOOL)force
{
    if (self.image &&
        (force
         || (self.screenSize.width != screenSize.width)
         || (self.screenSize.height != screenSize.height)))
    {
        self.screenSize = screenSize;
        float zoomScaleWidth = screenSize.width/self.image.size.width;
        float zoomScaleHeight = screenSize.height/self.image.size.height;
        
        float fillScale = MAX(zoomScaleWidth, zoomScaleHeight);
        float fitScale = MIN(zoomScaleWidth, zoomScaleHeight);
        self.minimumZoomScale = fitScale;
        self.maximumZoomScale = MAX(1, fillScale)*2;
        
        [self setZoomScale:fitScale];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.containerView;
}

// from 2010 WWDC session
- (void)layoutSubviews {
	[super layoutSubviews];
    
	CGSize boundsSize = self.bounds.size;
	UIView *centerView = self.containerView;	
    CGRect frameToCenter = centerView.frame;

	if (frameToCenter.size.width < boundsSize.width) {
		frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) * 0.5f;
	} else {
		frameToCenter.origin.x = 0;
	}

	if (frameToCenter.size.height < boundsSize.height) {
		frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) * 0.5f;
	} else {
		frameToCenter.origin.y = 0;
	}
    
    centerView.frame = frameToCenter;
}

@end
