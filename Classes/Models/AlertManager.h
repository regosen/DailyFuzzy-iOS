//
//  AlertManager.h
//  DailyFuzzy
//
//  Created by Rego on 3/31/17.
//  Copyright (c) 2017 Regaip Sen. All rights reserved.
//

#ifndef DailyFuzzy_AlertManager_h
#define DailyFuzzy_AlertManager_h

@interface AlertManager : NSObject

+ (BOOL) getAlertStatus;
+ (void) setAlertStatus:(BOOL)active;
+ (NSDate*) getAlertTime;
+ (void) setAlertTime:(NSDate*)time;
+ (void) updateNotifications;

@end

#endif
