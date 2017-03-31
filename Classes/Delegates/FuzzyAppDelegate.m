//
//  DailyFuzzyAppDelegate.m
//  DailyFuzzy
//
//  Created by Rego on 5/16/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "FuzzyAppDelegate.h"
#import "RecentFuzziesController.h"
#import "FavoritesViewController.h"
#import "SettingsViewController.h"
#import "ViewUtils.h"
#import "PictureManager.h"
#import "AlertManager.h"

#import "Appirater.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@implementation FuzzyAppDelegate

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [PictureManager didReceiveMemoryWarning];
}

- (BOOL)resetBadges
{
    UITabBarController *tabController = (UITabBarController *)self.window.rootViewController;
    tabController.delegate = self;
    UITabBarItem* dailyTabItem = [tabController.tabBar.items objectAtIndex:0];
    
    if (dailyTabItem.badgeValue != nil || [UIApplication sharedApplication].applicationIconBadgeNumber != 0)
    {
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
        [dailyTabItem setBadgeValue:nil];
        return YES;
    }
    return NO;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
    if ([viewController.title isEqualToString:@"Recents Nav"])
    {
        RecentFuzziesController* plController = (RecentFuzziesController*)viewController.childViewControllers[0];
        [plController update:[PictureManager getPhotosFrom:RECENTS_KEY]];
    }
    else if ([viewController.title isEqualToString:@"Favorites Nav"])
    {
        FavoritesViewController* flController = (FavoritesViewController*)viewController.childViewControllers[0];
        [flController update:[PictureManager getPhotosFrom:FAVORITES_KEY]];
    }
    else if ([viewController.title isEqualToString:@"Daily Fuzzy Nav"])
    {
        if ([self resetBadges])
        {
            PictureViewController* pvController = (PictureViewController*)viewController.childViewControllers[0];
            [PictureManager getDailyPic:YES forceLatest:NO completion:^(NSDictionary * newPic) {
                [pvController update:newPic slideType:kSlideRight];
            }];
        }
    }
}

- (void)switchToTodays
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UITabBarController* tabController = (UITabBarController *)self.window.rootViewController;
        [tabController setSelectedIndex:0];
    });
}

- (void)switchToRecents
{
    // HACK: put the PictureViewController directly in a navigation controller for the Recents tab
    // when transitioning this way
    UITabBarController* tabController = (UITabBarController *)self.window.rootViewController;
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *navViewController0 = tabController.viewControllers[0];
        UINavigationController *navViewController1 = tabController.viewControllers[1];
        PictureViewController *pVC0 = (PictureViewController*)navViewController0.viewControllers[0];
        PictureViewController *pVC1 = (PictureViewController*)[tabController.storyboard instantiateViewControllerWithIdentifier:@"PictureVC"];
        pVC1.overrideBounds = pVC0.view.bounds;
        [pVC1 view];
        [navViewController1 pushViewController:pVC1 animated:YES];
        [tabController setSelectedIndex:1];
    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Fabric with:@[[Crashlytics class]]];
    [Appirater setAppId:@"826034630"];
    
    // Override point for customization after application launch.
    [PictureManager initialize];
    UITabBarController *tabController = (UITabBarController *)self.window.rootViewController;
    tabController.delegate = self;
    tabController.tabBar.tintColor = [UIColor whiteColor];
    
    [[UITabBarItem appearance] setTitleTextAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [UIColor darkGrayColor], NSForegroundColorAttributeName,
      [UIFont fontWithName:@"font" size:0.0], NSFontAttributeName,
      nil]
                                             forState:UIControlStateNormal];
    
    [[UITabBarItem appearance] setTitleTextAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [UIColor whiteColor], NSForegroundColorAttributeName,
      [UIFont fontWithName:@"font" size:0.0], NSFontAttributeName,
      nil]
                                             forState:UIControlStateSelected];
    
    // set selected and unselected icons
    for (UITabBarItem *item in tabController.tabBar.items)
    {
        item.image = [[UIImage imageNamed:@"tab-item.png"] imageWithRenderingMode: UIImageRenderingModeAlwaysOriginal];

        item.selectedImage = [UIImage imageNamed:@"tab-item.png"];
    }
    
    UINavigationController* pvNav = (UINavigationController*)tabController.childViewControllers[0];
    [ViewUtils setTopBounds:tabController.tabBar.frame.size.height bottomBounds:pvNav.navigationBar.frame.size.height];
    
    PictureViewController* pvController = (PictureViewController*)pvNav.childViewControllers[0];
    if ([self resetBadges])
    {
        [PictureManager getDailyPic:YES forceLatest:NO completion:^(NSDictionary * newPic) {
            [pvController update:newPic slideType:kSlideRight];
        }];
    }
    else
    {
        [pvController reloadLatestIfNeeded:YES];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToRecents)
                                                 name:@"SwitchToRecents"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToTodays)
                                                 name:@"SwitchToNewFuzzy"
                                               object:nil];
    [Appirater setDaysUntilPrompt:7];
    [Appirater setUsesUntilPrompt:5];
    [Appirater setSignificantEventsUntilPrompt:-1];
    [Appirater setTimeBeforeReminding:9];
    [Appirater setDebug:NO];
    
    return YES;
}
    
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    UITabBarController* tabController = (UITabBarController *)self.window.rootViewController;
    UITabBarItem* dailyTabItem = [tabController.tabBar.items objectAtIndex:0];
    
    PictureViewController* pvController = (PictureViewController*)tabController.selectedViewController.childViewControllers[0];
    
    if (tabController.selectedIndex == 0)
    {
        if ([self resetBadges])
        {
            [PictureManager getDailyPic:YES forceLatest:NO completion:^(NSDictionary * newPic) {
                [pvController update:newPic slideType:kSlideRight];
            }];
        }
        else
        {
            [pvController reloadLatestIfNeeded:YES];
        }
    }
    else
    {
        NSInteger badgeNumber = application.applicationIconBadgeNumber;
        NSString* badgeNumString = badgeNumber > 0 ? [NSString stringWithFormat:@"%ld", (long)badgeNumber] : nil;
        [dailyTabItem setBadgeValue:badgeNumString];
    }
    
    UINavigationController* snavController = (UINavigationController*)tabController.childViewControllers[3];
    SettingsViewController* svController = (SettingsViewController*)snavController.childViewControllers[0];
    [svController refreshView];
    
    [AlertManager updateNotifications];
    [Appirater appEnteredForeground:YES];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
