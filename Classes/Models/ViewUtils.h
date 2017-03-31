//
//  ViewUtils.h
//  DailyFuzzy
//
//  Created by Rego on 5/20/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#ifndef DailyFuzzy_DailyViewUtils_h
#define DailyFuzzy_DailyViewUtils_h

#import <UIKit/UIKit.h>

#define NUM_PLACE_PHOTOS 50
#define NUM_RECENT_PHOTOS 20
#define FAVORITES_ADD @"Add to Favorites"
#define FAVORITES_DEL @"Remove from Favorites"

@interface ViewUtils : NSObject <UIAlertViewDelegate>

// Controls a spinner at the center of the view
+ (void) startSpinner:(UIView*)view;
+ (void) stopSpinner:(UIView*)view;
+ (void) stopAllSpinners;
+ (void) refreshSpinnerPositions:(UIView*)view;

+ (void) alertWithTitle:(NSString*)title message:(NSString*)message;
+ (void) setTopBounds:(float)topBounds bottomBounds:(float)bottomBounds;
+ (float) getTopBounds;
+ (float) getBottomBounds;
    
@end

#endif
