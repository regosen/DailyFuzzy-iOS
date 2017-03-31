//
//  PictureManager.h
//  DailyFuzzy
//
//  Created by Rego on 5/17/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#ifndef DailyFuzzy_PictureManager_h
#define DailyFuzzy_PictureManager_h

#import <StoreKit/StoreKit.h>

#define RECENTS_KEY @"fuzzy_recents"
#define FAVORITES_KEY @"fuzzy_favorites"
#define DAILY_KEY @"fuzzy_daily"
#define DEFAULT_IMAGE_TIMEOUT 15.0
#define LONGER_IMAGE_TIMEOUT 30.0

typedef void(^JSONCompletionHandler)(NSDictionary*);
typedef void(^ImageCompletionHandler)(NSData*);

@interface PictureManager : NSObject

typedef enum {
    kPrev,
    kNext,
    kPrevGetMore
} NavType;

+ (void) didReceiveMemoryWarning;
+ (void) setRecentsTransitionPic:(NSDictionary*)photo;
+ (NSDictionary*) flushRecentsTransitionPic;

// picture navigation
+ (void) getDailyPic:(BOOL)forceNewPic forceLatest:(BOOL)forceLatest completion:(JSONCompletionHandler)completionHandler;
+ (NSData*) getCachedThumbWithId:(NSString*)imageId;
+ (void) getThumbWithURL:(NSURL*)imageURL withId:(NSString*)imageId completion:(ImageCompletionHandler)completionHandler;
+ (void) getImageWithURL:(NSURL*)imageURL withId:(NSString*)imageId completion:(ImageCompletionHandler)completionHandler;
+ (BOOL) picCanChange:(NavType)direction from:(NSString*)key photo:(NSDictionary*)photo;
+ (void) changePic:(NavType)direction from:(NSString*)key photo:(NSDictionary*)photo completion:(JSONCompletionHandler)completionHandler;

+ (void) handleOnMain:(JSONCompletionHandler)completionHandler WithDict:(NSDictionary*)arg;
+ (void) handleOnMain:(ImageCompletionHandler)completionHandler WithData:(NSData*)arg;
+ (NSArray*) getPhotosFrom:(NSString*)key;
+ (void)setTimeout:(NSInteger)timeout;
+ (NSInteger)getTimeout;

// picture updating
+ (void) addPhoto:(NSDictionary*)photo to:(NSString*)key;
+ (void) movePhoto:(NSDictionary*)photo for:(NSString*)key to:(NSInteger)newIndex;
+ (void) removePhoto:(NSDictionary*)photo from:(NSString*)key;+ (BOOL) isFavorite:(NSString*)photoID;

@end

#endif
