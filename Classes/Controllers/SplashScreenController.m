//
//  SplashScreenController.m
//  DailyFuzzy
//
//  Created by Rego on 6/11/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import <UIKit/UIGestureRecognizerSubclass.h>
#import "SplashScreenController.h"
#import "ViewUtils.h"

#define UIColorFromRGB(rgbValue, alphaValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:alphaValue]

#define COLOR_GREEN  UIColorFromRGB(0x2aa93a, 1)
#define COLOR_LIGHTGRAY  UIColorFromRGB(0xe5e5e5, 1)

#define STATUS_BAR_HEIGHT 20

@interface SplashScreenController() <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIImageView *imageView;

@end


@implementation SplashScreenController

#define FIRST_LAUNCH_SCREEN @"first-launch-screen"

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:COLOR_LIGHTGRAY];
    CGSize screenSize = self.view.bounds.size;
    float yOffset = 0;
    
    // create fake top bar
    float navbarHeight = [ViewUtils getTopBounds];
    UIView* fakeNavbar = [[UIView alloc] initWithFrame:CGRectMake(0,yOffset,screenSize.width,navbarHeight+STATUS_BAR_HEIGHT)];
    [fakeNavbar setBackgroundColor:COLOR_GREEN];
    yOffset += STATUS_BAR_HEIGHT;
    
    // add title image
    UIImage* imageTitle = [UIImage imageNamed:@"splash-title"];
    float imageRatioX = screenSize.width / imageTitle.size.width;
    float imageRatioY = navbarHeight / imageTitle.size.height;
    
    UIImageView* viewTitle = [[UIImageView alloc] initWithImage:imageTitle];
    float yMargin = STATUS_BAR_HEIGHT;
    if (imageRatioX < imageRatioY)
    {
        // scale to fit by width
        float scaledHeight = imageTitle.size.height * imageRatioX;
        yMargin = (navbarHeight - scaledHeight)/2;
        viewTitle.frame = CGRectMake(0, yOffset + yMargin, screenSize.width, scaledHeight);
    }
    else
    {
        // scale to fit by height*2
        float scaledWidth = imageTitle.size.width * imageRatioY;
        yMargin = navbarHeight / 4.f;
        viewTitle.frame = CGRectMake((screenSize.width - scaledWidth)/2, yOffset, scaledWidth, navbarHeight);
    }
    yMargin = MAX(yMargin, STATUS_BAR_HEIGHT);
    [fakeNavbar addSubview:viewTitle];
    yOffset += navbarHeight + yMargin;
    
    // text below header
    UIImage* imageHeader = [UIImage imageNamed:@"splash-header"];
    UIImageView* viewHeader = [[UIImageView alloc] initWithImage:imageHeader];
    float headerHeight = imageHeader.size.height * imageRatioX;
    viewHeader.frame = CGRectMake(0, yOffset, screenSize.width, headerHeight);
    float topBounds = yOffset + headerHeight;
    
    
    // add fake footer (tab bar)
    float tabbarHeight = [ViewUtils getBottomBounds];
    yOffset = screenSize.height - tabbarHeight;
    UIView* fakeTabbar = [[UIView alloc] initWithFrame:CGRectMake(0,yOffset,screenSize.width,tabbarHeight)];
    [fakeTabbar setBackgroundColor:COLOR_GREEN];
    
    // text above footer
    UIImage* imageFooter = [UIImage imageNamed:@"splash-footer"];
    float heightFooter = imageFooter.size.height * imageRatioX;
    yOffset = fakeTabbar.frame.origin.y - (heightFooter + yMargin);
    UIImageView* viewFooter = [[UIImageView alloc] initWithImage:imageFooter];
    viewFooter.frame = CGRectMake(0, yOffset, screenSize.width, heightFooter);
    float bottomBounds = yOffset;
    
    // center
    UIImage* imageCenter = [UIImage imageNamed:@"splash-center"];
    UIImageView* viewCenter = [[UIImageView alloc] initWithImage:imageCenter];
    viewCenter.frame = CGRectMake(0,topBounds,screenSize.width,bottomBounds - topBounds);
    viewCenter.contentMode = UIViewContentModeScaleAspectFit;
    
    
    [self.view addSubview:fakeNavbar];
    [self.view addSubview:viewHeader];
    [self.view addSubview:viewCenter];
    [self.view addSubview:viewFooter];
    [self.view addSubview:fakeTabbar];
    [self.view setUserInteractionEnabled:YES];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self dismissViewControllerAnimated:YES completion:^(void)
     {
         if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]){
             UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
             [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
         }
     }];
    
	[super touchesBegan:touches withEvent:event];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIDeviceOrientationPortrait);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

@end
