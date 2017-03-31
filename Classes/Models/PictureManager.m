//
//  PictureManager.m
//  DailyFuzzy
//
//  Created by Rego on 5/17/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "PictureManager.h"
#import "AlertManager.h"
#import "RedditFetcher.h"
#import "Utils.h"

@interface PictureManager()

#define CACHE_LIMIT (30*1024*1024)
#define CACHE_KEY   @"cache_size"
#define ALERT_STATUS_KEY @"notification_enabled"
#define ALERT_TIME_KEY @"alert_time"

#define SCHEMA_VERSION_KEY @"schema_version"
#define SCHEMA_VERSION 2

@end


@implementation PictureManager

static PictureManager *sInstance = nil;
static NSUserDefaults* sDefs = nil;
static NSDictionary* sDailyPic = nil;
static NSUInteger sTimeout = DEFAULT_IMAGE_TIMEOUT;
static NSDictionary* sRecentsTransitionPic = nil;

// the following data gets cleared when we're low on memory
static NSMutableDictionary* sLoadedImages = nil;


#pragma mark - helper methods

+ (NSInteger) newIndex:(NavType)direction from:(NSString*)photoId photos:(NSArray*)photos
{
    NSInteger curIndex = -1;
    for (id cur in photos)
    {
        curIndex++;
        NSDictionary* curDict = (NSDictionary*)(cur);
        if ([photoId isEqualToString:[curDict valueForKey:REDDIT_UNIQUE]])
        {
            break;
        }
    }
    return (direction == kNext) ? curIndex + 1 : curIndex - 1;
}

// deletes older photos from cache until it's under the specified limit
+ (void) limitCacheFolder:(NSString*)cacheDir toSize:(NSInteger)sizeLimit
{
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    NSInteger cacheSize = [sDefs integerForKey:CACHE_KEY];
    NSMutableArray* recents = [[sDefs arrayForKey:RECENTS_KEY] mutableCopy];
    while (cacheSize > sizeLimit && recents.count > 0)
    {
        NSDictionary* curDict = recents.lastObject;
        NSString* curId = (NSString*)[curDict objectForKey:REDDIT_UNIQUE];
        NSString* curPath = [NSString stringWithFormat:@"%@/%@.jpg",cacheDir,curId];
        if ([fileMgr fileExistsAtPath:curPath])
        {
            NSError* cacheError = nil;
            NSDictionary* attributes = [fileMgr attributesOfItemAtPath:curPath error:&cacheError];
            NSNumber *fileSize = [attributes objectForKey:NSFileSize];
            cacheSize -= fileSize.intValue;
            [fileMgr removeItemAtPath:curPath error:&cacheError];
        }
        [recents removeLastObject];
    }
    [sDefs setDouble:cacheSize forKey:CACHE_KEY];
}

#pragma mark - generic

+ (void) setRecentsTransitionPic:(NSDictionary*)photo
{
    sRecentsTransitionPic = photo;
}

+ (NSDictionary*) flushRecentsTransitionPic
{
    NSDictionary* transitionPic = sRecentsTransitionPic;
    sRecentsTransitionPic = nil;
    return transitionPic;
}

+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;
        sInstance = [[PictureManager alloc] init];
        sDefs = [NSUserDefaults standardUserDefaults];
        sLoadedImages = [[NSMutableDictionary alloc] init];
        
        id schemaVersion = [sDefs objectForKey:SCHEMA_VERSION_KEY];
        if ((schemaVersion == nil) || ([schemaVersion integerValue] != SCHEMA_VERSION))
        {
            NSArray* conformedRecents = [RedditFetcher conformImages:[sDefs arrayForKey:RECENTS_KEY]];
            NSArray* conformedFavorites = [RedditFetcher conformImages:[sDefs arrayForKey:FAVORITES_KEY]];
            [sDefs setObject:conformedRecents forKey:RECENTS_KEY];
            [sDefs setObject:conformedFavorites forKey:FAVORITES_KEY];
            [sDefs setInteger:SCHEMA_VERSION forKey:SCHEMA_VERSION_KEY];
            [sDefs synchronize];
            NSString* cacheDir = [NSSearchPathForDirectoriesInDomains (NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:nil];
        }
        
        id alertStatus = [sDefs objectForKey:ALERT_STATUS_KEY];
        if (alertStatus == nil)
        {
            // first-time execution: turn on daily alerts for current time
            [sDefs setBool:YES forKey:ALERT_STATUS_KEY];
            [sDefs synchronize];
            [AlertManager setAlertTime:[NSDate date]];
        }
        else
        {
            [AlertManager updateNotifications];
        }
    }
}

+ (void) didReceiveMemoryWarning
{
    [sLoadedImages removeAllObjects];
}

#pragma mark - picture navigation

+ (void) handleOnMain:(JSONCompletionHandler)completionHandler WithDict:(NSDictionary*)arg
{
    if (completionHandler)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(arg);
        });
    }
}

+ (void) handleOnMain:(ImageCompletionHandler)completionHandler WithData:(NSData*)arg
{
    if (completionHandler)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(arg);
        });
    }
}

+ (void) getDailyPic:(BOOL)forceNewPic forceLatest:(BOOL)forceLatest completion:(JSONCompletionHandler)completionHandler
{
    [sDefs setObject:[NSDate date] forKey:LAST_DATE_USED];
    NSArray* photos = [sDefs arrayForKey:RECENTS_KEY];
    if (forceNewPic || (photos.count == 0))
    {
        NSMutableArray* excludes = [[NSMutableArray alloc] init];
        if (forceNewPic)
        {
            NSArray* photos = [sDefs arrayForKey:RECENTS_KEY];
            for (id cur in photos)
            {
                NSDictionary* curDict = (NSDictionary*)(cur);
                [excludes addObject:[curDict valueForKey:REDDIT_UNIQUE]];
            }
        }
        
        [RedditFetcher topFuzzy:excludes completion:^(NSDictionary* dailyPic)
                     {
                         sDailyPic = dailyPic;
                         if (sDailyPic && [sDailyPic count])
                         {
                             [self addPhoto:sDailyPic to:RECENTS_KEY];
                         }
                         [self handleOnMain:completionHandler WithDict:sDailyPic];
                     }];
    }
    else
    {
        if (forceLatest || !sDailyPic || sDailyPic.count == 0)
        {
            sDailyPic = [photos firstObject];
        }
        [self handleOnMain:completionHandler WithDict:sDailyPic];
    }
}

+ (void) setTimeout:(NSInteger)timeout
{
    sTimeout = timeout;
}

+ (NSInteger)getTimeout
{
    return sTimeout;
}

// gets image from cache if it exists, otherwise loads from web into cache
+ (void) getImageWithURL:(NSURL*)imageURL withId:(NSString*)imageId completion:(ImageCompletionHandler)completionHandler
{
    NSData *imageData = (NSData*)[sLoadedImages objectForKey:imageId];
    if (imageURL && !imageData) {
        NSURLRequest *urlRequest = [NSURLRequest requestWithURL:imageURL
                                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                 timeoutInterval:sTimeout];
        
        [NSURLConnection sendAsynchronousRequest:urlRequest
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *imageData,
                                                   NSError *error) {
           
           if (error == nil && imageData != nil)
           {
               [sLoadedImages setObject:imageData forKey:imageId];
               [self setTimeout:DEFAULT_IMAGE_TIMEOUT];
           }
           [self handleOnMain:completionHandler WithData:imageData];
       }];
    }
    else
    {
        [self handleOnMain:completionHandler WithData:imageData];
    }
}

+ (NSString*) getCacheDir
{
    static NSString* cacheDir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheDir = [NSSearchPathForDirectoriesInDomains (NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    });
    return cacheDir;
}

+ (NSString*) getCachePathWithId:(NSString*)imageId
{
    return [NSString stringWithFormat:@"%@/%@.jpg",[self getCacheDir],imageId];
}

+ (NSData*) getCachedThumbWithId:(NSString*)imageId
{
    NSData* imageData = nil;
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    NSString* filePath = [self getCachePathWithId:imageId];
    if ([fileMgr fileExistsAtPath:filePath])
    {
        imageData = [fileMgr contentsAtPath:filePath];
    }
    return imageData;
}

+ (void) getThumbWithURL:(NSURL*)imageURL withId:(NSString*)imageId completion:(ImageCompletionHandler)completionHandler
{
    if (imageURL == nil)
    {
        return;
    }
    NSData* imageData = [self getCachedThumbWithId:imageId];
    
    if (!imageData && imageURL)
    {
        NSURLRequest *urlRequest = [NSURLRequest requestWithURL:imageURL
                                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                timeoutInterval:sTimeout];
        [NSURLConnection sendAsynchronousRequest:urlRequest
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *imageData,
                                                   NSError *error) {
                                   
           if (error == nil && imageData != nil)
           {
               NSString* filePath = [self getCachePathWithId:imageId];
               [self addImage:imageData toCache:filePath];
               [self limitCacheFolder:[self getCacheDir] toSize:CACHE_LIMIT];
               [self handleOnMain:completionHandler WithData:imageData];
           }
           
       }];
    }
    else
    {
        [self handleOnMain:completionHandler WithData:imageData];
    }
}

+ (BOOL) picCanChange:(NavType)direction from:(NSString*)key photo:(NSDictionary*)photo;
{
    NSString* actualKey = [key isEqualToString:DAILY_KEY] ? RECENTS_KEY : key;
    NSArray* photos = [sDefs arrayForKey:actualKey];
    NSString* photoId = [photo valueForKey:REDDIT_UNIQUE];
    NSInteger newIndex = [self newIndex:direction from:photoId photos:photos];
    if (direction == kPrevGetMore || ([key isEqualToString:RECENTS_KEY] && direction == kPrev))
    {
        return YES;
    }
    else
    {
        return ((newIndex < (int)photos.count) && (newIndex >= 0));
    }
}

+ (void) changePic:(NavType)direction from:(NSString*)key photo:(NSDictionary*)photo completion:(JSONCompletionHandler)completionHandler;
{
    BOOL isTodays = [key isEqualToString:DAILY_KEY];
    NSString* actualKey = isTodays ? RECENTS_KEY : key;
    NSArray* photos = [sDefs arrayForKey:actualKey];
    NSString* photoId = [photo valueForKey:REDDIT_UNIQUE];
    NSInteger newIndex = [self newIndex:direction from:photoId photos:photos];
    if (newIndex >= 0)
    {
        if (newIndex < photos.count)
        {
            NSDictionary* newPic = photos[newIndex];
            if (isTodays)
            {
                // reject if photo before today
                NSDate* date = [photos[newIndex] objectForKey:REDDIT_DATE];
                if (date == nil || [date timeIntervalSinceNow] < -3600)
                {
                    newPic = nil;
                }
            }
            [self handleOnMain:completionHandler WithDict:newPic];
        }
    }
    else if (direction == kPrevGetMore)
    {
        [self getDailyPic:YES forceLatest:NO completion:completionHandler];
    }
}

#pragma mark - picture updating

+ (void) addImage:(NSData*)imageData toCache:(NSString*)imagePath
{
    NSInteger cacheSize = [sDefs integerForKey:CACHE_KEY];
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:imagePath contents:imageData attributes:nil];
    if (!success)
    {
        NSLog(@"Failed to create file at path: %@", imagePath);
    }
    cacheSize += [imageData length];
    [sDefs setDouble:cacheSize forKey:CACHE_KEY];
}

+ (void) addPhoto:(NSDictionary*)photo to:(NSString*)key
{
    NSString* newId = (NSString*)[photo objectForKey:REDDIT_UNIQUE];
    if (newId == nil) {
        return;
    }
    NSArray* recents = [self getPhotosFrom:key];
    for (NSDictionary *entry in recents)
    {
        NSString* recentId = (NSString*)[entry objectForKey:REDDIT_UNIQUE];
        if ([recentId isEqualToString:newId])
        {
            // photo already added, do nothing.
            return;
        }
    }
    
    NSArray* oldRecents = [sDefs arrayForKey:key];
    
    NSMutableArray* newRecents = [[NSMutableArray alloc] init];
    [newRecents addObject:photo];
    BOOL dupeFound = NO;
    for (id cur in oldRecents)
    {
        if (!dupeFound)
        {
            NSDictionary* curDict = (NSDictionary*)(cur);
            NSString* curId = (NSString*)[curDict objectForKey:REDDIT_UNIQUE];
            if ([curId isEqualToString:newId])
            {
                dupeFound = YES;
                continue;
            }
        }
        [newRecents addObject:cur];
    }
    [sDefs setObject:newRecents forKey:key];
    [sDefs synchronize];
}

+ (void) movePhoto:(NSDictionary*)photo for:(NSString*)key to:(NSInteger)newIndex
{
    NSString* photoId = (NSString*)[photo objectForKey:REDDIT_UNIQUE];
    NSMutableArray* photos = [[sDefs arrayForKey:key] mutableCopy];
    id foundPhoto = nil;
    for (id cur in photos)
    {
        NSDictionary* curDict = (NSDictionary*)(cur);
        NSString* curId = (NSString*)[curDict objectForKey:REDDIT_UNIQUE];
        if ((curId == nil && photoId == nil) || [curId isEqualToString:photoId])
        {
            foundPhoto = cur;
            break;
        }
    }
    if (foundPhoto != nil)
    {
        [photos removeObject:foundPhoto];
        [photos insertObject:foundPhoto atIndex:newIndex];
        [sDefs setObject:photos forKey:key];
        [sDefs synchronize];
    }
}

+ (void) removePhoto:(NSDictionary*)photo from:(NSString*)key
{
    NSString* photoId = (NSString*)[photo objectForKey:REDDIT_UNIQUE];
    NSMutableArray* photos = [[sDefs arrayForKey:key] mutableCopy];
    id foundPhoto = nil;
    for (id cur in photos)
    {
        NSDictionary* curDict = (NSDictionary*)(cur);
        NSString* curId = (NSString*)[curDict objectForKey:REDDIT_UNIQUE];
        if ((curId == nil && photoId == nil) || [curId isEqualToString:photoId])
        {
            foundPhoto = cur;
            break;
        }
    }
    if (foundPhoto != nil)
    {
        [photos removeObject:foundPhoto];
        [sDefs setObject:photos forKey:key];
        [sDefs synchronize];
    }
}

+ (NSArray*) getPhotosFrom:(NSString*)key
{
    return [sDefs arrayForKey:key];
}

+ (BOOL) isFavorite:(NSString*)photoID
{
    NSArray* photos = [sDefs arrayForKey:FAVORITES_KEY];
    for (id cur in photos)
    {
        NSDictionary* curDict = (NSDictionary*)(cur);
        NSString* curId = (NSString*)[curDict objectForKey:REDDIT_UNIQUE];
        if ([curId isEqualToString:photoID])
        {
            return YES;
        }
    }
    return NO;
}


@end
