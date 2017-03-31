//
//  Utils.h
//  DailyFuzzy
//
//  Created by Rego on 5/20/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#ifndef DailyFuzzy_Utils_h
#define DailyFuzzy_Utils_h

#define LAST_DATE_USED @"last_date_used"

@interface Utils : NSObject
    
+ (NSDate*) stripTime:(NSDate*)inDate;
+ (BOOL) isNewDay;
    
#ifdef DEBUG
+ (void)obfuscate:(const unsigned char*)obfuscatedData to:(unsigned char*)convertedData size:(unsigned int)dataSize;
#endif
+ (NSString*)deobfuscate:(const unsigned char*)obfuscatedData size:(unsigned int)dataSize;
    
@end

#endif
