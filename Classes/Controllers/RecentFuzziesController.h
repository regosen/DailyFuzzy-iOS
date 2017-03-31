//
//  RecentFuzziesController.h
//  DailyFuzzy
//
//  Created by Rego on 5/16/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#ifndef PictureListController_h
#define PictureListController_h

#import <UIKit/UIKit.h>
#import "PictureViewController.h"

@protocol PictureListControllerDelegate <NSObject>

- (void)update:(NSArray*)photos;
- (void)removePhoto:(NSDictionary*)photo;

@end

@interface RecentFuzziesController : UITableViewController <PictureListControllerDelegate>

@property (retain) id <PictureViewControllerDelegate> delegate;

@end


#endif