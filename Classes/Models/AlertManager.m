//
//  AlertManager.m
//  DailyFuzzy
//
//  Created by Rego on 3/31/17.
//  Copyright (c) 2017 Regaip Sen. All rights reserved.
//

#import "AlertManager.h"
#import "Utils.h"

@interface AlertManager()

#define ALERT_STATUS_KEY @"notification_enabled"
#define ALERT_TIME_KEY @"alert_time"

    @end


@implementation AlertManager

+ (BOOL) getAlertStatus
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:ALERT_STATUS_KEY];
}

+ (void) setAlertStatus:(BOOL)active
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:active forKey:ALERT_STATUS_KEY];
    [defs synchronize];
    [self updateNotifications];
}

+ (NSDate*) getAlertTime
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSDate *alertTime = [defs objectForKey:ALERT_TIME_KEY];
    
    // extract the time for alert time and use today's date (or tomorrow's if it's already passed)
    NSDate* now = [NSDate date];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *componentsToday = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    NSDateComponents *componentsAlert = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:alertTime];
    [componentsAlert setYear:componentsToday.year];
    [componentsAlert setMonth:componentsToday.month];
    [componentsAlert setDay:componentsToday.day];
    NSDate* alertDate = [calendar dateFromComponents:componentsAlert];
    BOOL incrementDate = [now compare:alertDate] != NSOrderedAscending;
    
    id lastDateUsedObj = [defs objectForKey:LAST_DATE_USED];
    if (!incrementDate && lastDateUsedObj != nil)
    {
        // if user is limited and already got a fuzzy today, push alert to next day
        NSDate *lastUsed = [Utils stripTime:(NSDate*)lastDateUsedObj];
        NSDate *today = [Utils stripTime:[NSDate date]];
        incrementDate = [today isEqualToDate:lastUsed];
    }
    
    if (incrementDate)
    {
        // increment next alert by a day
        NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
        [offsetComponents setDay:1];
        
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        alertDate = [gregorian dateByAddingComponents:offsetComponents toDate:alertDate options:0];
    }
    
    return alertDate;
}

+ (void) setAlertTime:(NSDate*)time
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:time forKey:ALERT_TIME_KEY];
    [defs synchronize];
    [self updateNotifications];
}

+ (void) updateNotifications
{
    UIApplication* app = [UIApplication sharedApplication];
    [app cancelAllLocalNotifications];
    if (self.getAlertStatus)
    {
        NSDate* alertTime = self.getAlertTime;
        NSLog(@"Next alert: %@", alertTime);
        
        NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
        [offsetComponents setDay:1];
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        
        // post notification for each of next 7 days (in case the user doesn't respond the first day)
        for (NSInteger offset = 0; offset < 7; offset++ )
        {
            UILocalNotification* notifyAlarm = [[UILocalNotification alloc] init];
            notifyAlarm.fireDate = alertTime;
            notifyAlarm.repeatInterval = 0;
            notifyAlarm.timeZone = [NSTimeZone defaultTimeZone];
            notifyAlarm.alertBody = @"There's a new fuzzy for you!";
            notifyAlarm.soundName = UILocalNotificationDefaultSoundName;
            notifyAlarm.applicationIconBadgeNumber = 1;
            
            [app scheduleLocalNotification:notifyAlarm];
            
            alertTime = [gregorian dateByAddingComponents:offsetComponents toDate:alertTime options:0];
        }
    }    
}

@end
