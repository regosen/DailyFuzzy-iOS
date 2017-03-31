//
//  RecentFuzziesController.m
//  DailyFuzzy
//
//  Created by Rego on 5/16/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "RecentFuzziesController.h"
#import "ViewUtils.h"
#import "RedditFetcher.h"
#import "PictureManager.h"

@interface RecentFuzziesController ()

@property (nonatomic, strong) NSArray* photos;
@property (nonatomic, strong) UIBarButtonItem *editButton;
@property (nonatomic, strong) UIBarButtonItem *doneButton;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (atomic, strong) NSMutableArray* loadingRows;

@end

@implementation RecentFuzziesController

#pragma mark - helper methods

-(void)startEdit
{
    [self setEditing:YES];
}

-(void)stopEdit
{
    [self setEditing:NO];
}

- (void)setEditing:(BOOL)editing
{
    [super setEditing:editing];
    [self.tableView setEditing:editing];
    self.navigationItem.leftBarButtonItem = editing ? self.doneButton : self.editButton;
}

- (void)update:(NSArray*)photos
{
    self.photos = photos;
    [self.tableView reloadData];
}

-(void)removePhoto:(NSDictionary*)photo
{
    NSAssert(NO, @"RemovePhoto should not be called on Recents!");
}

#pragma mark - UI callbacks

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    self.editButton          = [[UIBarButtonItem alloc]
                                  initWithTitle:@"Edit" style:UIBarButtonItemStylePlain
                                  target:self action:@selector(startEdit)];
    
    self.doneButton          = [[UIBarButtonItem alloc]
                                initWithTitle:@"Done" style:UIBarButtonItemStylePlain
                                target:self action:@selector(stopEdit)];
    
    self.loadingRows = [[NSMutableArray alloc] init];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    
    self.navigationItem.leftBarButtonItem = self.editButton;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:NO];
    
    [UIView  beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.navigationController.view cache:NO];
    [UIView commitAnimations];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{    
    if ([segue.identifier isEqualToString:@"Picture View"])
    {
        PictureViewController* vc = segue.destinationViewController;
        self.delegate = vc;
        vc.parent = self;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - Table View callbacks

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.photos count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Picture";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    id photo = [self.photos objectAtIndex:indexPath.row];
    NSDictionary* photoInfo = (NSDictionary*)photo;
    
    NSString* title = (NSString*)[photoInfo objectForKey:REDDIT_TITLE];
    
    NSString* imageId = (NSString*)[photoInfo objectForKey:REDDIT_UNIQUE];
    NSString* thumbURLString = (NSString*)[photoInfo objectForKey:REDDIT_THUMB];
    NSURL* thumbURL = [NSURL URLWithString:thumbURLString];
    if (thumbURL == nil || (thumbURLString != nil && [thumbURLString rangeOfString:@"."].location == NSNotFound))
    {
        // thumbnail not available, fallback on full image
        thumbURLString = (NSString*)[photoInfo objectForKey:REDDIT_URL];
        thumbURL = [NSURL URLWithString:thumbURLString];
    }
    
    NSData* thumbData = [PictureManager getCachedThumbWithId:imageId];
    if (thumbData != nil) {
        UIImage *image = [[UIImage alloc] initWithData:thumbData];
        cell.imageView.image = image;
        [self.loadingRows removeObject:thumbURL];
    }
    else if (thumbURL != nil)
    {
        // load image in separate thread
        [self.loadingRows addObject:thumbURL];
        cell.imageView.image = [UIImage imageNamed:@"thumb-placeholder"];
        [PictureManager getThumbWithURL:thumbURL withId:imageId completion:^(NSData * thumbData) {
            // once we've loaded the image, update the cell
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }];
    }
    else
    {
        cell.imageView.image = [UIImage imageNamed:@"thumb-placeholder"];
    }
    
    if ([title length] > 0)
    {
        cell.textLabel.text = title;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.textLabel.numberOfLines = 2;
        }
        else
        {
            cell.textLabel.font = [UIFont systemFontOfSize:12];
            cell.textLabel.numberOfLines = 3;
        }
    }
    else
    {
        cell.textLabel.text = @"Untitled";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id photo = [self.photos objectAtIndex:indexPath.row];
    [self.delegate update:photo slideType:kNoSlide];
}

#pragma mark - Table View edit callbacks

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void) tableView: (UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndex toIndexPath:(NSIndexPath *)toIndex
{
    id photo = [self.photos objectAtIndex:fromIndex.row];
    [PictureManager movePhoto:photo for:RECENTS_KEY to:toIndex.row];
    self.photos = [PictureManager getPhotosFrom:RECENTS_KEY];
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // remove from model
        id photo = [self.photos objectAtIndex:indexPath.row];
        [PictureManager removePhoto:photo from:RECENTS_KEY];
        self.photos = [PictureManager getPhotosFrom:RECENTS_KEY];
        
        // remove from tableView
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        
        // exit edit mode if last photo removed
        if ([self.photos count] == 0)
        {
            [self stopEdit];
        }
    }
}

@end
