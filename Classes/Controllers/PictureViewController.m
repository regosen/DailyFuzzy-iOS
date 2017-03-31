//
//  PictureViewController.m
//  DailyFuzzy
//
//  Created by CS193p Instructor.
//  Copyright (c) 2011 Stanford University. All rights reserved.
//

#import "PictureViewController.h"
#import "RecentFuzziesController.h"
#import "ViewUtils.h"
#import "PictureManager.h"
#import "Utils.h"
#import "RedditFetcher.h"
#import "MKNumberBadgeView.h"
#import "PSTCenteredScrollView.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

@interface PictureViewController() <UIActionSheetDelegate, UIGestureRecognizerDelegate>

@property (strong, nonatomic) PSTCenteredScrollView *scrollView;
@property (strong, nonatomic) UIActionSheet *actionSheet;

@property (nonatomic, strong) NSURL     *imageURL;
@property (nonatomic, strong) NSString  *titleName;
@property (nonatomic, strong) NSString  *imageId;

@property (nonatomic, strong) NSDictionary* photoInfo;
@property (nonatomic, strong) MKNumberBadgeView* badgeView;
@property (nonatomic, strong) UIAlertView* timeoutAlert;

@property (nonatomic) BOOL respondToShareButton;
@property (nonatomic) BOOL missingImage;

@property (atomic) BOOL inTransition;
@property (atomic) BOOL tryingToPurchase;

@end

@implementation PictureViewController

#define SHARE_FACEBOOK @"Share on Facebook"
#define SHARE_SAVE @"Save to Photo Album"

#pragma mark - helper methods

- (BOOL)isVideo
{
    return [[self.imageURL absoluteString] hasSuffix:@".gifv"];
}

- (BOOL)isTodaysView
{
    return [self.parentViewController.title isEqualToString:@"Daily Fuzzy Nav"];
}

- (BOOL)isRecentsView
{
    return [self.parentViewController.title isEqualToString:@"Recents Nav"];
}

- (BOOL)isFavoritesView
{
    return [self.parentViewController.title isEqualToString:@"Favorites Nav"];
}

- (NavType)getDirection:(SlideType)slideType
{
    if ([self isTodaysView])
    {
        return (slideType == kSlideLeft) ? kNext : kPrevGetMore;
    }
    else
    {
        return (slideType == kSlideLeft) ? kNext : kPrev;
    }
}

- (NSString*)getKey
{
    return [self isFavoritesView] ? FAVORITES_KEY : ([self isTodaysView] ? DAILY_KEY : RECENTS_KEY);
}

#pragma mark - refresh helper methods

- (void)refreshTitle:(UIInterfaceOrientation)interfaceOrientation
{
    UILabel* label = (UILabel*)self.navigationItem.titleView;
    BOOL portrait = (interfaceOrientation == UIInterfaceOrientationPortrait ||
                     interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
    
    NSInteger charLimit = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ?
        (portrait ? 86 : 117) :
        (portrait ? 28 : 60);
    
    if ([self.titleName length] > charLimit)
    {
        label.font = [UIFont systemFontOfSize: 12.0f];
    }
    else
    {
        label.font = [UIFont systemFontOfSize: 17.0f];
    }

    label.text = self.titleName;
    self.navigationController.navigationBar.topItem.title = self.titleName;
    [self.navigationController.navigationBar setNeedsDisplay];
}

- (void)update:(NSDictionary *)photoInfo slideType:(SlideType)slideType
{
    NSString* newId = (NSString*)[photoInfo objectForKey:REDDIT_UNIQUE];

    if (self.missingImage || ![self.imageId isEqualToString:newId])
    {
        self.photoInfo = photoInfo;
        
        self.imageId = newId;
        self.imageURL = [NSURL URLWithString:(NSString*)[photoInfo objectForKey:REDDIT_URL]];

        self.titleName = (NSString*)[photoInfo objectForKey:REDDIT_TITLE];
        
        [self performSelectorOnMainThread:@selector(resetTitleBarButtons)
                               withObject:nil
                            waitUntilDone:NO];
        [self resetImage:slideType];
    }
    else
    {
        self.inTransition = NO;
    }
}

- (UIInterfaceOrientation) getScreenOrientation
{
    return [[UIApplication sharedApplication] statusBarOrientation];
}

- (void)resetImage:(SlideType)slideType
{
    if (self.imageURL != nil) {
        NSLog(@"Image: %@", self.imageURL);
        [ViewUtils startSpinner:self.view];
        
        [PictureManager getImageWithURL:self.imageURL withId:self.imageId completion:^(NSData* imageData) {
            
            if (!self.scrollView.image || slideType == kNoSlide)
            {
                [self.scrollView removeFromSuperview];
                self.scrollView = [[PSTCenteredScrollView alloc] initWithFrame:self.view.bounds];
                self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
                if ([self isVideo])
                {
                    self.missingImage = ![self.scrollView setVideo:self.imageURL fromController:self];
                }
                else
                {
                    self.missingImage = ![self.scrollView setImage:imageData url:self.imageURL screenSize:self.view.bounds.size];
                }
                [self.view addSubview:self.scrollView];
                self.inTransition = NO;
            }
            else
            {
                PSTCenteredScrollView* nextView = [[PSTCenteredScrollView alloc] initWithFrame:self.view.bounds];
                nextView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
                if ([self isVideo])
                {
                    self.missingImage = ![nextView setVideo:self.imageURL fromController:self];
                }
                else
                {
                    self.missingImage = ![nextView setImage:imageData url:self.imageURL screenSize:self.view.bounds.size];
                }
                
                CGRect frame = nextView.frame;
                frame.origin.x = (frame.size.width * 1.05) * (slideType == kSlideLeft ? -1 : 1);
                frame.origin.y = 0;
                nextView.frame = frame;
                
                [self.view addSubview:nextView];
                
                [UIView animateWithDuration:.3f animations:^{
                    CGRect oldFrame = self.scrollView.frame;
                    oldFrame.origin.x = (oldFrame.size.width * 1.05) * (slideType == kSlideLeft ? 1 : -1);
                    self.scrollView.frame = oldFrame;
                    
                    CGRect newFrame = nextView.frame;
                    newFrame.origin.x = 0;
                    nextView.frame = newFrame;
                } completion:^(BOOL finished){
                    [self.scrollView removeFromSuperview];
                    self.scrollView = nextView;
                    self.inTransition = NO;
                }];
            }
            if (self.missingImage)
            {
                if ([PictureManager getTimeout] == DEFAULT_IMAGE_TIMEOUT)
                {
                    if (self.timeoutAlert == nil)
                    {
                        self.timeoutAlert = [[UIAlertView alloc] initWithTitle:@"Image timed out" message:@"We're unable to access this fuzzy!  Try waiting longer?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                        [self.timeoutAlert show];
                    }
                }
                else
                {
                    [ViewUtils alertWithTitle:@"Image timed out" message:@"We're still unable to access this fuzzy!  Please check your internet connection."];
                }
            }
            
            [self refreshTitle:[self getScreenOrientation]];
        
            [ViewUtils stopSpinner:self.view];
            
        }];
    }
    else if (self.imageURL == nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.missingImage = YES;
            [ViewUtils alertWithTitle:@"Can't access server" message:@"We're unable to access today's fuzzies!  Please check your internet connection."];
            self.inTransition = NO;
        });
    }
    else
    {
        self.inTransition = NO;
    }
}

- (BOOL)reloadLatestIfNeeded:(BOOL)gotoLatest
{
    if ([self isTodaysView] && (gotoLatest || [Utils isNewDay] || self.missingImage || self.imageURL == nil))
    {
        [ViewUtils startSpinner:self.view];
        
        [PictureManager getDailyPic:YES forceLatest:NO completion:^(NSDictionary * dailyPic) {
            if (dailyPic)
            {
                [self update:dailyPic slideType:kSlideRight];
                [ViewUtils stopSpinner:self.view];
                [self refreshTitle:[self getScreenOrientation]];
            }
            else
            {
                [self refreshTitle:[self getScreenOrientation]];
                [ViewUtils stopSpinner:self.view];
                [ViewUtils alertWithTitle:@"Can't access server" message:@"We're unable to access today's fuzzies!  Please check your internet connection."];
            }

        }];
        return YES;
    }
    return NO;
}

- (void)resetTitleBarButtons
{
    UIImage *backwardImage = [UIImage imageNamed:@"leftArrow"];
    UIButton *backwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backwardButton setBackgroundImage:backwardImage forState:UIControlStateNormal];
    backwardButton.frame = CGRectMake(0, 0, backwardImage.size.width, backwardImage.size.height);
    [backwardButton addTarget:self action:@selector(leftArrowPressed)
             forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithCustomView:backwardButton];
    self.navigationItem.leftBarButtonItem.enabled = [PictureManager picCanChange:[self getDirection:kSlideLeft] from:[self getKey] photo:self.photoInfo];
    
    UIImage *forwardImage = [UIImage imageNamed:@"rightArrow"];
    UIButton *forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [forwardButton setBackgroundImage:forwardImage forState:UIControlStateNormal];
    forwardButton.frame = CGRectMake(0, 0, forwardImage.size.width, forwardImage.size.height);
    [forwardButton addTarget:self action:@selector(rightArrowPressed)
            forControlEvents:UIControlEventTouchUpInside];
    
    BOOL canNavigateRight = [PictureManager picCanChange:[self getDirection:kSlideRight] from:[self getKey] photo:self.photoInfo];

    if (![self isFavoritesView])
    {
        if (!self.badgeView)
        {
            self.badgeView = [[MKNumberBadgeView alloc] initWithFrame:forwardButton.frame];
            self.badgeView.font = [UIFont systemFontOfSize: 10.0f];
            [self.badgeView setCenter:CGPointMake(forwardButton.frame.size.width-5, 2)];
            self.badgeView.hideWhenZero = YES;
            self.badgeView.textFormat = @"!";
            self.badgeView.userInteractionEnabled = NO;
            self.badgeView.exclusiveTouch = NO;
        }
        self.badgeView.value = canNavigateRight ? 0 : 1;
        [forwardButton addSubview:self.badgeView];
    }
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithCustomView:forwardButton];
    
    self.navigationItem.rightBarButtonItem.enabled = canNavigateRight || ![self isFavoritesView];
}


#pragma mark - helper action methods

- (void)removePhotoFromParent:(id <PictureListControllerDelegate>)parent
{
    [parent removePhoto:self.photoInfo];
}

- (void)shareImage:(UIBarButtonItem *)sender {
    if (self.respondToShareButton)
    {
        self.respondToShareButton = NO;
        NSString* photoId = (NSString*)[self.photoInfo objectForKey:REDDIT_UNIQUE];
        NSString* favButton = [PictureManager isFavorite:photoId] ? FAVORITES_DEL : FAVORITES_ADD;
        
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:SHARE_FACEBOOK, favButton, SHARE_SAVE ,nil];
        [self.actionSheet showInView:self.scrollView];
    }
    else
    {
        [self.actionSheet dismissWithClickedButtonIndex:2 animated:YES];
    }
}

- (void)changePic:(SlideType)slideType
{
    NavType direction = [self getDirection:slideType];
    [ViewUtils startSpinner:self.view];
    
    [PictureManager changePic:direction from:[self getKey] photo:self.photoInfo completion:^(NSDictionary* newPic)
     {
         if (newPic != nil && [newPic count] > 0)
         {
             [self update:newPic slideType:slideType];
         }
         else if ([self isTodaysView] && direction == kNext)
         {
             [PictureManager setRecentsTransitionPic:self.photoInfo];
             [[NSNotificationCenter defaultCenter] postNotificationName:@"SwitchToRecents" object:self];
             self.inTransition = NO;
             [ViewUtils stopSpinner:self.view];
         }
         else if ([self isRecentsView] && direction == kPrev)
         {
             [[NSNotificationCenter defaultCenter] postNotificationName:@"SwitchToNewFuzzy" object:self];
             self.inTransition = NO;
             [ViewUtils stopSpinner:self.view];
         }
         else
         {
             self.inTransition = NO;
         }
     }];
}


#pragma mark - UI callbacks

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.timeoutAlert)
    {
        if (buttonIndex == 1)
        {
            [PictureManager setTimeout:LONGER_IMAGE_TIMEOUT];
            [self resetImage:kNoSlide];
        }
        else
        {
            [self.scrollView setImage:nil url:nil screenSize:self.view.bounds.size];
        }
        self.timeoutAlert = nil;
    }
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self isTodaysView])
    {
        [self reloadLatestIfNeeded:NO];
    }
    [self switchToRecents];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:NO];
    
    [UIView  beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.navigationController.view cache:NO];
    [UIView commitAnimations];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelay:0.375];
    [self.navigationController popViewControllerAnimated:NO];
    [UIView commitAnimations];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshTitle:[self getScreenOrientation]];
}

- (void)switchToRecents
{
    NSDictionary* transitionPic = [PictureManager flushRecentsTransitionPic];
    if (transitionPic != nil)
    {
        // 1. immediately show current picture
        [self update:transitionPic slideType:kNoSlide];
        // 2. slide to prev picture
        [self changePic:kSlideLeft];
    }
}

- (void)forceNewFuzzy
{
    [PictureManager getDailyPic:NO forceLatest:YES completion:^(NSDictionary * dailyPic) {
        [self update:dailyPic slideType:kNoSlide];
    }];
    
    [PictureManager getDailyPic:YES forceLatest:NO completion:^(NSDictionary * dailyPic) {
        [self update:dailyPic slideType:kSlideRight];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    self.respondToShareButton = YES;
    self.missingImage = NO;
    self.inTransition = YES;
    if (self.overrideBounds.size.width > 0)
    {
        NSLog(@"OVERRIDE BOUNDS");
        self.view.bounds = self.overrideBounds;
    }
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background-light-small"]];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    NSUserDefaults* userDefs = [NSUserDefaults standardUserDefaults];
    NSNumber* hasLaunchedBefore = [userDefs objectForKey:@"HasLaunched"];
    if (!hasLaunchedBefore)
    {
        /* Present next run loop. Prevents "unbalanced VC display" warnings. */
        double delayInSeconds = 0.1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self performSegueWithIdentifier:@"Splash" sender:self];
        });
        
        [userDefs setObject:[NSNumber numberWithBool:YES] forKey:@"HasLaunched"];
        [userDefs synchronize];
    }
    else
    {
        if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)])
        {
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        }
    }
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 480, 44)];
    label.backgroundColor = [UIColor clearColor];
    label.numberOfLines = 3;
    [label setTextAlignment:NSTextAlignmentCenter];
    label.textColor = [UIColor whiteColor];
    self.navigationItem.titleView = label;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    
    self.navigationItem.titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    self.scrollView = [[PSTCenteredScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    [self resetTitleBarButtons];
    if (![self isTodaysView] && self.imageURL && !self.inTransition)
    {
        [self resetImage:kNoSlide];
    }
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];
    
    UISwipeGestureRecognizer *swipeGestureLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGestureLeft:)];
    swipeGestureLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    swipeGestureLeft.delegate = self;
    [self.view addGestureRecognizer:swipeGestureLeft];
    
    UISwipeGestureRecognizer *swipeGestureRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGestureRight:)];
    swipeGestureRight.direction = UISwipeGestureRecognizerDirectionRight;
    swipeGestureRight.delegate = self;
    [self.view addGestureRecognizer:swipeGestureRight];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(forceNewFuzzy)
                                                 name:@"SwitchToNewFuzzy"
                                               object:nil];
    [self switchToRecents];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
    
    [self.scrollView refreshZoomBounds:self.view.bounds.size force:NO];
    [self resetTitleBarButtons];
    [ViewUtils refreshSpinnerPositions:self.view];
    [self refreshTitle:interfaceOrientation];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

#pragma mark - UI callbacks on user actions

- (void)handleTapGesture:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self shareImage:nil];
    }
}

- (void)handleSwipeGestureLeft:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (self.navigationItem.rightBarButtonItem.enabled)
        {
            [self rightArrowPressed];
        }
    }
}

- (void)handleSwipeGestureRight:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (self.navigationItem.leftBarButtonItem.enabled)
        {
            [self leftArrowPressed];
        }
    }
}

- (void)leftArrowPressed
{
    if (!self.inTransition)
    {
        self.inTransition = YES;
        [self changePic:kSlideLeft];
    }
}

- (void)rightArrowPressed
{
    if (!self.inTransition)
    {
        self.inTransition = YES;
        [self changePic:kSlideRight];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    self.respondToShareButton = YES;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
    if ([choice isEqualToString:FAVORITES_ADD]) {
        [PictureManager addPhoto:self.photoInfo to:FAVORITES_KEY];
    }
    else if ([choice isEqualToString:FAVORITES_DEL]) {
        [PictureManager removePhoto:self.photoInfo from:FAVORITES_KEY];
        if ([self isFavoritesView])
        {
            [self removePhotoFromParent:self.parent];
            [self viewWillDisappear:NO];
        }
    }
    else if ([choice isEqualToString:SHARE_FACEBOOK])
    {
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentTitle = self.titleName;
        content.contentDescription = @"curated by Reddit and shared via Daily Fuzzy, a free iOS app";
        content.contentURL = [NSURL URLWithString:self.imageURL.absoluteString];
        if ([self isVideo])
        {
            NSString* stillVersion = [self.imageURL.absoluteString stringByReplacingOccurrencesOfString:@".gifv" withString:@"l.gif"];
            content.imageURL = [NSURL URLWithString:stillVersion];
        }
        else
        {
            content.imageURL = [NSURL URLWithString:self.imageURL.absoluteString];
        }
        FBSDKShareDialog *dialog = [[FBSDKShareDialog alloc] init];
        dialog.fromViewController = self;
        dialog.shareContent = content;
        dialog.delegate = nil;
        dialog.mode = FBSDKShareDialogModeFeedWeb;
        
        [dialog show];
    }
    else if ([choice isEqualToString:SHARE_SAVE])
    {
        UIImageWriteToSavedPhotosAlbum(self.scrollView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error != nil)
    {
        [ViewUtils alertWithTitle:@"Couldn't save image" message:@"We couldn't save the image to your library!"];
    }
    else
    {
        [ViewUtils alertWithTitle:@"Image saved!" message:@"You can now message, email, or share this image from your photo library."];
    }
}
@end
