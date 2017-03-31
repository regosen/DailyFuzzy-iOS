//
//  RedditFetcher.h
//
//  Based on material from Stanford CS193p Winter 2013.
//  Copyright 2013 Stanford University
//  All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PictureManager.h"

#define REDDIT_TITLE @"title"
#define REDDIT_URL @"url"
#define REDDIT_THUMB @"thumbnail"
#define REDDIT_UNIQUE @"id"
#define REDDIT_DATE @"date"

#define DEFAULT_JSON_TIMEOUT 10.0

@interface RedditFetcher : NSObject

+ (NSMutableArray*) conformImages:(NSArray*) images;
+ (void) topFuzzy:(NSArray*)excludedIDs completion:(JSONCompletionHandler)completionHandler;

@end
