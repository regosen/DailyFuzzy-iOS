//
//  SettingsViewController.m
//  DailyFuzzy
//
//  Created by Rego on 7/8/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "SettingsViewController.h"
#import "AlertManager.h"
#import "ViewUtils.h"

@interface SettingsViewController () <UIAlertViewDelegate, UIActionSheetDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIActionSheet *actionSheet;
@property (strong, nonatomic) UIPopoverController* popover;
@property (strong, nonatomic) UIDatePicker* datePicker;
@property (nonatomic) BOOL respondToHelpButton;

@end

@implementation SettingsViewController

#define ID_NOTIFICATION_TIME @"Notification Time"
#define ID_NOTIFICATION_PICKER @"Time Picker"

#define HELP_SPLASH @"Show Instruction Page"
#define HELP_HOW_TO_POST @"How To Post Photos"
#define HELP_EMAIL @"Email Developer"

#pragma mark - helper methods

- (void) refreshView
{
    if (self.tableView)
    {
        [self.tableView reloadData];
    }
}

#pragma mark - UI methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"http://www.reddit.com"]];
    }
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] animated:NO];
    return YES;
}

- (void)dismissDate
{
    [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] animated:NO];
    
    if (self.popover)
    {
        [self.popover dismissPopoverAnimated:YES];
    }
    if (self.actionSheet)
    {
        [self.actionSheet dismissWithClickedButtonIndex:0 animated:YES];
    }
}

- (void)chooseDate
{
    [AlertManager setAlertTime:self.datePicker.date];
    [self refreshView];
    [self dismissDate];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:NO];
    
    if (self.datePicker)
    {
        [self.datePicker removeFromSuperview];
        self.datePicker = nil;
        [self refreshView];
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.respondToHelpButton = YES;
    UIBarButtonItem * aboutButton = [[UIBarButtonItem alloc] initWithTitle:@"About" style:UIBarButtonItemStylePlain target:self action:@selector(aboutTapped:)];
    UIBarButtonItem * helpButton = [[UIBarButtonItem alloc] initWithTitle:@"Help" style:UIBarButtonItemStylePlain target:self action:@selector(helpTapped:)];
    
    aboutButton.tintColor = [UIColor whiteColor];
    helpButton.tintColor = [UIColor whiteColor];

    self.navigationItem.leftBarButtonItem = aboutButton;
    self.navigationItem.rightBarButtonItem = helpButton;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case 1:
        {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && [UIAlertController class])
            {
                if ( self.datePicker != nil )
                {
                    return 2;
                }
                else
                {
                    return 1;
                }
            }
            else
            {
                return 1;
            }
        }
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return @"You'll be notified of a new fuzzy at the time below each day:";
    }
    return nil;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = nil;
    switch (indexPath.section) {
        case 1:
        {
            if (indexPath.row == 0)
            {
                cell = [self.tableView dequeueReusableCellWithIdentifier:ID_NOTIFICATION_TIME];
                if(!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ID_NOTIFICATION_TIME];
                }
                
                NSDateFormatter *newFormatter = [[NSDateFormatter alloc] init];
                [newFormatter setDateStyle:NSDateFormatterNoStyle];
                [newFormatter setTimeStyle:NSDateFormatterShortStyle];
                cell.textLabel.text = [newFormatter stringFromDate:[AlertManager getAlertTime]];
                
                
                UISwitch* switchBtn = [[UISwitch alloc] init];
                switchBtn.on = [AlertManager getAlertStatus];
                [switchBtn addTarget:self action:@selector(onSwitchBtn:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchBtn;
            }
            else
            {
                cell = [self.tableView dequeueReusableCellWithIdentifier:ID_NOTIFICATION_PICKER];
                if(!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ID_NOTIFICATION_PICKER];
                }
                [cell addSubview:self.datePicker];
            }
        }
            break;
            
        default:
            break;
    }
    return cell;
}

- (void)timeChanged:(id)sender{
    [AlertManager setAlertTime:self.datePicker.date];
    [self refreshView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && [UIAlertController class])
        {
            if (self.datePicker)
            {
                [self.datePicker removeFromSuperview];
                self.datePicker = nil;
            }
            else
            {
                self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 0, 320, 216)];
                CGRect pickerFrame = self.datePicker.frame;
                [self.datePicker setFrame:pickerFrame];
                [self.datePicker setDatePickerMode:UIDatePickerModeTime];
                [self.datePicker setDate:[AlertManager getAlertTime]];
                [self.datePicker addTarget:self action:@selector(timeChanged:) forControlEvents:UIControlEventValueChanged];
            }
            [self refreshView];
        }
        else
        {
            [self showAction];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - UI callbacks on user actions

- (void)aboutTapped:(id)sender {
    id versionNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString* message = @"\nPicture selection is powered by Reddit, with additional meta-filtering to maximize quality. More fuzzies are added each day. Tap a picture for options.\n\nI originally made this app for my wife, who thought it should be shared with the world.\n\n\u00A9 2014 Regaip Sen. All rights reserved.";
    [ViewUtils alertWithTitle:[NSString stringWithFormat:@"Daily Fuzzy v.%@", versionNumber] message:message];
}

- (void)howToPostTapped {
    NSString* message = @"\nOur photos are posted and curated by Reddit users.  To contribute your own photos, you must become a Reddit user and post to the r/aww subreddit.\n\n(Once you post a photo, it will be voted up or down by the Reddit community.  Posts must reach the top before getting automatically featured on Daily Fuzzy.)";
    
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"How Do I Post Photos?" message:message delegate:self cancelButtonTitle:@"See Reddit" otherButtonTitles:@"OK", nil];
    [alertView show];
}


- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    self.respondToHelpButton = YES;
}

- (void)helpTapped:(id)sender {
    if (self.respondToHelpButton)
    {
        self.respondToHelpButton = NO;
        
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:HELP_SPLASH, HELP_HOW_TO_POST, HELP_EMAIL, nil];
        [self.actionSheet showInView:self.view];
    }
    else
    {
        [self.actionSheet dismissWithClickedButtonIndex:2 animated:YES];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    dispatch_async(dispatch_get_main_queue(),
       ^{
           NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
           if ([choice isEqualToString:HELP_SPLASH]) {
               [self performSegueWithIdentifier:@"Splash" sender:self];
           }
           else if ([choice isEqualToString:HELP_HOW_TO_POST]) {
               [self howToPostTapped];
           }
           else if ([choice isEqualToString:HELP_EMAIL]) {
               [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:rego@dailyfuzzy.com"]];
           }
       });
}

- (void)onSwitchBtn:(id) sender
{
    UISwitch* switchBtn = (UISwitch*)sender;
    [AlertManager setAlertStatus:switchBtn.on];
}

#pragma mark - Alert time picker

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] animated:NO];
}

-(void) showAction
{
    // some of this is taken from http://stackoverflow.com/questions/7974475/uiactionsheet-on-ipad-frame-too-small
    
    // title "button" for toolbar
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 23)];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor clearColor];
    label.text = @"New Time";
    label.font = [UIFont boldSystemFontOfSize:20.0];
    
    // toolbar
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    toolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(dismissDate)];
    UIBarButtonItem *titleButton = [[UIBarButtonItem alloc] initWithCustomView:label];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Set" style:UIBarButtonItemStylePlain target:self action:@selector(chooseDate)];
    UIBarButtonItem *fixed1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *fixed2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [doneButton setTintColor:[UIColor blueColor]];
    [toolbar setItems:[NSArray arrayWithObjects:cancelButton, fixed1, titleButton, fixed2, doneButton, nil]];
    
    // date picker
    self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 44, 320, 216)];
    CGRect pickerFrame = self.datePicker.frame;
    pickerFrame.origin.y = toolbar.frame.size.height;
    [self.datePicker setFrame:pickerFrame];
    [self.datePicker setDatePickerMode:UIDatePickerModeTime];
    [self.datePicker setDate:[AlertManager getAlertTime]];
    
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        // using UIPopoverController
        UIView *view = [[UIView alloc] init];
        [view addSubview:self.datePicker];
        [view addSubview:toolbar];
        
        UIViewController *vc = [[UIViewController alloc] init];
        [vc setView:view];
        [vc setPreferredContentSize:CGSizeMake(320, 260)];
        
        self.popover = [[UIPopoverController alloc] initWithContentViewController:vc];
        
        [self.popover presentPopoverFromRect:CGRectMake(0, self.actionSheet.frame.origin.y-175, 320, 300) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        self.popover.delegate = self;
        [self.popover setPopoverContentSize:CGSizeMake(320, 260)];
    }
    else
    {
        // using UIActionSheet
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:@"Choose a time to be notified:" delegate:self cancelButtonTitle:@"" destructiveButtonTitle:nil otherButtonTitles:nil, nil];
        [self.actionSheet showFromTabBar:self.tabBarController.tabBar];
        [self.actionSheet setFrame:CGRectMake(0, self.actionSheet.frame.origin.y-175, 320, 300)];
        self.actionSheet.backgroundColor = [UIColor whiteColor];
        
        [self.actionSheet addSubview:self.datePicker];
        [self.actionSheet addSubview:toolbar];
    }
}

@end
