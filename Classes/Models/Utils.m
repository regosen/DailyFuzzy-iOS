//
//  Utils.m
//  DailyFuzzy
//
//  Created by Rego on 5/20/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "Utils.h"
#include <CommonCrypto/CommonCrypto.h>  // for obfuscate

@implementation Utils
    
+ (NSDate*) stripTime:(NSDate*)inDate
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:inDate];
    return [cal dateFromComponents:components];
}
    
+ (BOOL) isNewDay
{
    NSDate *today = [self stripTime:[NSDate date]];
    
    id lastDateUsedObj = [[NSUserDefaults standardUserDefaults] objectForKey:LAST_DATE_USED];
    if (lastDateUsedObj != nil)
    {
        NSDate *lastUsed = [self stripTime:(NSDate*)lastDateUsedObj];
        return ![today isEqualToDate:lastUsed];
    }
    return YES;
}

// based on http://www.splinter.com.au/2014/09/16/storing-secret-keys/
+ (void)obfuscate:(const unsigned char*)obfuscatedData to:(unsigned char*)convertedData size:(unsigned int)dataSize
{
    // Get the SHA512 of a class name, to form the obfuscator.
    unsigned char obfuscator[CC_SHA512_DIGEST_LENGTH];
    NSData *className = [NSStringFromClass([self class])
                         dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA512(className.bytes, (CC_LONG)className.length, obfuscator);
    
    // XOR the class name against the obfuscated key, to form the real key.
    for (int i=0; i<dataSize; i++) {
        convertedData[i] = obfuscatedData[i] ^ obfuscator[i];
    }
}
    
+ (NSString*)deobfuscate:(const unsigned char*)obfuscatedData size:(unsigned int)dataSize
{
    unsigned char deobfuscatedData[dataSize+1];
    [self obfuscate:obfuscatedData to:deobfuscatedData size:dataSize];
    deobfuscatedData[dataSize] = 0;
    return [NSString stringWithFormat:@"%s", deobfuscatedData];
}

@end
