//
//  PictureViewController.h
//  DailyFuzzy
//
//  Created by CS193p Instructor.
//  Copyright (c) 2011 Stanford University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PictureManager.h"

@protocol PictureViewControllerDelegate <NSObject>

typedef enum {
    kSlideLeft,
    kSlideRight,
    kNoSlide
} SlideType;

- (void)update:(NSDictionary *)photoInfo slideType:(SlideType)slideType;
- (BOOL)reloadLatestIfNeeded:(BOOL)gotoLatest;

@end

@interface PictureViewController : UIViewController <PictureViewControllerDelegate, UIAlertViewDelegate>

- (void)resetTitleBarButtons;

@property (nonatomic, weak) id parent;
@property (nonatomic) CGRect overrideBounds;

@end
