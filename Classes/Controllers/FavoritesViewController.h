//
//  FavoritesViewController.h
//  DailyFuzzy
//
//  Created by Rego on 5/16/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#ifndef CoreDataTableViewController_h
#define CoreDataTableViewController_h

#import <UIKit/UIKit.h>
#import "PictureViewController.h"
#import "RecentFuzziesController.h"

@interface FavoritesViewController : UITableViewController <PictureListControllerDelegate>

@property (retain) id <PictureViewControllerDelegate> delegate;

@end


#endif