//
//  ViewUtils.m
//  DailyFuzzy
//
//  Created by Rego on 5/20/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "ViewUtils.h"

@interface ViewUtils ()


@end

@implementation ViewUtils

static UIAlertView *sAlertView;
static NSMutableDictionary* sSpinners;
static BOOL addingSpinner = NO;
static float sTopBounds = 0;
static float sBottomBounds = 0;

    
+ (void) setTopBounds:(float)topBounds bottomBounds:(float)bottomBounds
{
    sTopBounds = topBounds;
    sBottomBounds = bottomBounds;
}
+ (float) getTopBounds
{
    return sTopBounds;
}

+ (float) getBottomBounds
{
    return sBottomBounds;
}

+ (void) startSpinner:(UIView*)view
{
    if (!sSpinners)
    {
        sSpinners = [[NSMutableDictionary alloc] init];
    }
    NSValue* viewPointer = [NSValue valueWithPointer:(__bridge const void *)(view)];
    if (!addingSpinner && [sSpinners objectForKey:viewPointer] == nil)
    {
        addingSpinner = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            
            CGRect frame = spinner.frame;
            frame.origin.x = view.bounds.size.width / 2 - frame.size.width / 2;
            frame.origin.y = view.bounds.size.height / 2 - frame.size.height / 2;
            spinner.frame = frame;
            [sSpinners setObject:spinner forKey:viewPointer];
            
            [view addSubview:spinner];
            [spinner startAnimating];
            addingSpinner = NO;
        });
    }
}

+ (void) stopSpinner:(UIView*)view
{
    if (sSpinners)
    {
        NSValue* viewPointer = [NSValue valueWithPointer:(__bridge const void *)(view)];
        id spinnerObj = [sSpinners objectForKey:viewPointer];
        if (spinnerObj != nil)
        {
            UIActivityIndicatorView* spinner = (UIActivityIndicatorView*)spinnerObj;
            [spinner stopAnimating];
            [spinner removeFromSuperview];
            [sSpinners removeObjectForKey:viewPointer];
        }
    }
}

+ (void) stopAllSpinners
{
    for (UIActivityIndicatorView* spinner in [sSpinners allValues])
    {
        [spinner stopAnimating];
        [spinner removeFromSuperview];
    }
    [sSpinners removeAllObjects];
}

+ (void) refreshSpinnerPositions:(UIView*)view
{
    for (UIActivityIndicatorView* spinner in [sSpinners allValues])
    {
        CGRect frame = spinner.frame;
        frame.origin.x = view.bounds.size.width / 2 - frame.size.width / 2;
        frame.origin.y = view.bounds.size.height / 2 - frame.size.height / 2;
        spinner.frame = frame;
    }
}

+ (void) alertWithTitle:(NSString*)title message:(NSString*)message
{
    if (!sAlertView)
    {
        sAlertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [sAlertView show];
    }
}

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    sAlertView = nil;
}

@end
