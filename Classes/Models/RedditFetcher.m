//
//  RedditFetcher.m
//
//  Based on material from Stanford CS193p Winter 2013.
//  Copyright 2011 Stanford University. All rights reserved.
//

#import "RedditFetcher.h"
#import "Utils.h"

@implementation RedditFetcher

static NSArray* sLastEntries = nil;
static NSDate* sLastQueryTime = nil;

static NSArray* sToxicSubstrings = nil; // swear words that children should not see
static NSArray* sWhitelistRegexes = nil; // word prefixes that indicate this is a picture of animals
static NSArray* sOverridableBlacklistRegexes = nil; // substrings that indicate this is a picture of non-animals
static NSArray* sNonOverridableBlacklistRegexes = nil; // substrings to avoid, even if it's a picture of animals
    
+ (NSArray*)regexArrayFromPrefixes:(NSArray*)prefixes
{
    NSMutableArray *regexes = [NSMutableArray arrayWithCapacity:[prefixes count]];
    [prefixes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSError *error = NULL;
        // prepend \b to match any word that starts with a keyword
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@", obj]
                                      options:NSRegularExpressionCaseInsensitive
                                      error:&error];
        if (regex)
        {
            [regexes addObject:regex];
        }
        
    }];
    return [regexes copy];
}
    
+ (void)initialize
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *pListPath = [bundle pathForResource:@"Info" ofType:@"plist"];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:pListPath];
    
    sWhitelistRegexes = [self regexArrayFromPrefixes:[dictionary objectForKey:@"Whitelist Prefixes"]];
    sOverridableBlacklistRegexes = [self regexArrayFromPrefixes:[dictionary objectForKey:@"Overridable Blacklist Prefixes"]];
    sNonOverridableBlacklistRegexes = [self regexArrayFromPrefixes:[dictionary objectForKey:@"Non-Overridable Blacklist Prefixes"]];
    
    // obfuscating toxic words, to make sure they can't be seen even when inspecting app data
    unsigned char obfuscatedToxicSubstrings[] = { 0x75,0x70,0x86,0x92,0xca,0x5e,0x02,0x06,0xe6,0x5c,0x04,0xf3,0x80,0x1e,0x1c,0x1a,0xd1,0x5b,0xf7,0x96,0xb8,0xce,0xd2,0x00,0x61,0x02,0xd7,0xe5,0xc7,0x9d,0x94,0xa0 };
    sToxicSubstrings = [[Utils deobfuscate:obfuscatedToxicSubstrings size:sizeof(obfuscatedToxicSubstrings)] componentsSeparatedByString:@","];
}


+ (void)executeJSONFetch:(NSString *)query completion:(JSONCompletionHandler)completionHandler
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:query]
                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval:DEFAULT_JSON_TIMEOUT];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *jsonData,
                                               NSError *error) {

        NSDictionary *results = (jsonData && !error) ? [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves error:&error] : nil;

        if (error) NSLog(@"[%@ %@] JSON error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error.localizedDescription);
        [PictureManager handleOnMain:completionHandler WithDict:results];
    }];
}

// trim to lightweight dictionary
+ (NSDictionary *) redditToLocal:(NSDictionary*)redditDict
{
    NSMutableDictionary* localDict = [[NSMutableDictionary alloc] init];
    if (redditDict != nil && redditDict.count > 0)
    {
        [localDict setObject:[redditDict objectForKey:REDDIT_UNIQUE] forKey:REDDIT_UNIQUE];
        NSMutableString* redditTitle = [redditDict objectForKey:REDDIT_TITLE];
        NSString* fixedTitle = [[redditTitle stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"] stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
        [localDict setObject:fixedTitle forKey:REDDIT_TITLE];
        [localDict setObject:[redditDict objectForKey:REDDIT_URL] forKey:REDDIT_URL];
        [localDict setObject:[redditDict objectForKey:REDDIT_THUMB] forKey:REDDIT_THUMB];
        [localDict setObject:[NSDate date] forKey:REDDIT_DATE];
    }
    return localDict;
}

+ (NSMutableArray*) conformImages:(NSArray*) images
{
    NSMutableArray* newImages = [[NSMutableArray alloc] init];
    for (NSDictionary* data in images)
    {
        NSString* urlString = [data objectForKey:REDDIT_URL];
        NSString* thumbString = [data objectForKey:REDDIT_THUMB];
        NSURL *url = [NSURL URLWithString:urlString];
        NSURL *thumbUrl = [NSURL URLWithString:thumbString];
        if (![thumbUrl.host containsString:@"redditmedia.com"])
        {
            if ([url.host containsString:@"imgur.com"])
            {
                NSString* filebase = [[urlString lastPathComponent] stringByDeletingPathExtension];
                if ([filebase length] == 5 || [filebase length] == 7)
                {
                    NSString* imagePath = [NSString stringWithFormat:@"https://i.imgur.com/%@l.jpg", filebase];
                    NSString* thumbPath = [NSString stringWithFormat:@"https://i.imgur.com/%@s.jpg", filebase];
                    
                    NSMutableDictionary* newData = [data mutableCopy];
                    if (![urlString hasSuffix:@".gif"] && ![urlString hasSuffix:@".gifv"])
                    {
                        [newData setObject:imagePath forKey:REDDIT_URL];
                    }
                    [newData setObject:thumbPath forKey:REDDIT_THUMB];
                    [newImages addObject:newData];
                }
                else
                {
                    [newImages addObject:data];
                }
            }
            else
            {
                // we don't support non-imgur images anymore
            }
        }
        else
        {
            [newImages addObject:data];
        }
    }
    return newImages;
}

+ (BOOL) allowTitle:(NSString*)titleLower
{
    NSRange titleRange = NSMakeRange(0, [titleLower length]);
    
    for (NSString* substring in sToxicSubstrings)
    {
        if ([titleLower rangeOfString:substring].location != NSNotFound)
        {
            return NO;
        }
    }
    
    for (NSRegularExpression *regex in sNonOverridableBlacklistRegexes)
    {
        if ([regex firstMatchInString:titleLower options:0 range:titleRange])
        {
            return NO;
        }
    }
    
    for (NSRegularExpression *regex in sWhitelistRegexes)
    {
        if ([regex firstMatchInString:titleLower options:0 range:titleRange])
        {
            return YES;
        }
    }
    
    for (NSRegularExpression *regex in sOverridableBlacklistRegexes)
    {
        if ([regex firstMatchInString:titleLower options:0 range:titleRange])
        {
            return NO;
        }
    }
    
    return YES;
}

+ (NSDictionary *) topFuzzyInternal:(NSArray*)excludedIDs
{
    if (sLastEntries == nil || sLastEntries.count == 0)
    {
        sLastQueryTime = nil;
        return [[NSDictionary alloc] init];
    }
    for (NSDictionary *entry in sLastEntries)
    {
        NSMutableDictionary* data = [entry valueForKey:@"data"];
        NSString* urlString = [[data valueForKey:REDDIT_URL] componentsSeparatedByString:@"?"][0];
        NSString* titleLower = [[data valueForKey:REDDIT_TITLE] lowercaseString];
        
        // criteria for exclusion
        
        if ([excludedIDs containsObject:[data valueForKey:REDDIT_UNIQUE]])
        {
            continue;
        }
        else if ([urlString rangeOfString:@"/a/"].location != NSNotFound)
        {
            continue; // skip imgur albums
        }
        else if ([urlString rangeOfString:@"/gallery/"].location != NSNotFound)
        {
            continue; // skip imgur galleries
        }
        
        if (![self allowTitle:titleLower])
        {
            continue;
        }
        
        NSURL *url = [NSURL URLWithString:urlString];
        if ([url.host containsString:@"imgur.com"])
        {
            NSString* filebase = [[urlString lastPathComponent] stringByDeletingPathExtension];
            if ([filebase length] == 5 || [filebase length] == 7)
            {
                NSString* imagePath = [NSString stringWithFormat:@"https://i.imgur.com/%@l.jpg", filebase];
                NSString* thumbPath = [NSString stringWithFormat:@"https://i.imgur.com/%@s.jpg", filebase];
                
                if (![urlString hasSuffix:@".gif"] && ![urlString hasSuffix:@".gifv"])
                {
                    [data setObject:imagePath forKey:REDDIT_URL];
                }
                [data setObject:thumbPath forKey:REDDIT_THUMB];
                
                return [self redditToLocal:data];
            }
        }
    }
    sLastQueryTime = nil;
    return nil;
}

+ (void) topFuzzy:(NSArray*)excludedIDs completion:(JSONCompletionHandler)completionHandler
{
    BOOL usingCachedQuery = (sLastQueryTime != nil && [sLastQueryTime timeIntervalSinceNow] < -3600);
    if (usingCachedQuery && completionHandler)
    {
        NSDictionary* fuzzy = [self topFuzzyInternal:excludedIDs];
        if (fuzzy)
        {
            [PictureManager handleOnMain:completionHandler WithDict:fuzzy];
        }
        else
        {
            usingCachedQuery = NO;
        }
    }
    
    if (!usingCachedQuery)
    {
        unsigned long limit = 20 + (excludedIDs.count*2);
        NSString *request = [NSString stringWithFormat:@"http://www.reddit.com/r/aww/hot/.json?limit=%lu", limit];
        [self executeJSONFetch:request completion:^(NSDictionary* results) {
            sLastEntries = [results valueForKeyPath:@"data.children"];
            sLastQueryTime = [NSDate date];
            
            NSDictionary* fuzzy = [self topFuzzyInternal:excludedIDs];
            [PictureManager handleOnMain:completionHandler WithDict:fuzzy];
        }];
    }
}

@end
