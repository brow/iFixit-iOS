//
//  FeaturedViewController.m
//  iFixit
//
//  Created by David Patierno on 11/7/11.
//  Copyright (c) 2011 iFixit. All rights reserved.
//

#import "FeaturedViewController.h"
#import "PastFeaturesViewController.h"
#import "DMPGridViewController.h"
#import "GuideViewController.h"
#import "iFixitAPI.h"
#import "Config.h"
#import "UIImageView+WebCache.h"
#import "WBProgressHUD.h"
#import "GANTracker.h"
#import <QuartzCore/QuartzCore.h>

@implementation FeaturedViewController
@synthesize poc, pvc, gvc;
@synthesize collection = _collection;
@synthesize guides = _guides;
@synthesize loading;

- (void)showLoading {
    if (loading.superview) {
        [loading showInView:self.gvc.view];
        return;
    }
    
    CGRect frame = CGRectMake(self.view.frame.size.width / 2.0 - 60, 400.0, 120.0, 120.0);
    self.loading = [[[WBProgressHUD alloc] initWithFrame:frame] autorelease];
    self.loading.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [loading showInView:self.gvc.view];
}

- (void)loadCollections {
    [self showLoading];
    self.gvc.navigationItem.rightBarButtonItem = nil;
    [[iFixitAPI sharedInstance] getCollectionsWithLimit:200 andOffset:0 forObject:self withSelector:@selector(gotCollections:)];
}

- (id)init {
    if ((self = [super init])) {
        self.pvc = [[[PastFeaturesViewController alloc] init] autorelease];
        self.pvc.delegate = self;

        UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:pvc];
        self.poc = [[[UIPopoverController alloc] initWithContentViewController:nvc] autorelease];
        poc.popoverContentSize = CGSizeMake(320.0, 500.0);
        [nvc release];
        
        self.gvc = [[[DMPGridViewController alloc] initWithDelegate:nil] autorelease];
        self.viewControllers = [NSArray arrayWithObject:gvc];
        self.gvc.delegate = self;
        
        [self loadCollections];
    }
    return self;
}

- (void)gotCollections:(NSArray *)collections {
    if (![collections count]) {
        [self.loading hide];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Could not load featured collections."
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Retry", nil];
        alert.tag = 1;
        [alert show];
        [alert release];
        return;
    }
    
    // Grab the most recent collection to populate our display.
    self.collection = [collections objectAtIndex:0];
    
    // Pass the whole list onto the popover view.
    pvc.collections = [NSMutableArray arrayWithArray:collections];
    
    // Analytics
    [[GANTracker sharedTracker] trackPageview:[NSString stringWithFormat:@"/collection/%d", [[self.collection valueForKey:@"collectionid"] intValue]] withError:NULL];
}

- (void)loadGuides {    
    [self showLoading];
    self.gvc.navigationItem.rightBarButtonItem = nil;
    [[iFixitAPI sharedInstance] getGuidesByIds:[_collection objectForKey:@"guideids"] forObject:self withSelector:@selector(gotGuides:)];
}

// Run this method both when we set the collection and on viewDidLoad, in case we're coming back from a low memory condition.
- (void)updateTitleAndHeader {
    if (!_collection)
        return;
    
    self.gvc.title = [_collection valueForKey:@"title"];
    
    // Create the header container view with a drop shadow.
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, 256.0)];
    headerView.layer.masksToBounds = NO;
    headerView.layer.shadowOffset = CGSizeZero;
    headerView.layer.shadowRadius = 6.0;
    headerView.layer.shadowOpacity = 1;
    headerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:headerView.bounds].CGPath;
    
    // Add the image
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:headerView.frame];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.backgroundColor = [UIColor lightGrayColor];
    [imageView setImageWithURL:[NSURL URLWithString:[[_collection objectForKey:@"image"] objectForKey:@"large"]]];
    [headerView addSubview:imageView];
    [imageView release];

    // Add a gradient overlay.
    UIImageView *gradientView = [[UIImageView alloc] initWithFrame:headerView.frame];
    gradientView.alpha = 0.80;
    gradientView.image = [UIImage imageNamed:@"collectionsHeaderGradient.png"];
    gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    gradientView.contentMode = UIViewContentModeScaleToFill;
    gradientView.clipsToBounds = YES;
    [headerView addSubview:gradientView];
    [gradientView release];
    
    // Add the giant text.
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(120.0, 150.0, self.view.frame.size.width - 130.0, 106.0)];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumFontSize = 70.0;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if ([Config currentConfig].dozuki)
        titleLabel.font = [UIFont fontWithName:@"Lobster" size:120.0];
    else
        titleLabel.font = [UIFont fontWithName:@"TrebuchetMS-Italic" size:120.0];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textAlignment = UITextAlignmentRight;
    titleLabel.text = [_collection valueForKey:@"title"];
    [headerView addSubview:titleLabel];
    [titleLabel release];
    
    // Apply!
    self.gvc.tableView.tableHeaderView = headerView;
    [headerView release];
}

- (void)setCollection:(NSDictionary *)collection {
    // Save the collection.
    [_collection release];
    _collection = [collection retain];
    
    // Reset the guides list.
    self.guides = nil;
    
    // Dismiss the popover
    [poc dismissPopoverAnimated:YES];
    
    // Update the title and header image.
    [self updateTitleAndHeader];
    
    // Scroll to the top.
    [self.gvc.tableView scrollRectToVisible:CGRectMake(0.0, 0.0, 1.0, 1.0) animated:NO];
    
    // Reload the grid.
    [self.gvc.tableView reloadData];
    
    // Retrieve guide data.    
    [self loadGuides];
}

- (void)gotGuides:(NSArray *)guides {
    if (![guides count]) {
        [self.loading hide];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Could not load collection."
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Retry", nil];
        alert.tag = 2;
        [alert show];
        [alert release];
        return;
    }
    
    self.guides = guides;
    [self.gvc.tableView reloadData];
    [self.loading hide];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (!buttonIndex) {
        UIBarButtonItem *refreshItem;

        if (alertView.tag == 1) {
            refreshItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                        target:self
                                                                        action:@selector(loadCollections)];
        }
        else if (alertView.tag == 2) {
            refreshItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                        target:self
                                                                        action:@selector(loadGuides)];            
        }
        
        self.gvc.navigationItem.rightBarButtonItem = refreshItem;
        [refreshItem release];
        return;
    }
    
    if (alertView.tag == 1) {
        [self loadCollections];
    }
    else if (alertView.tag == 2) {
        [self loadGuides];
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Add a 10px bottom margin.
    self.gvc.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 10.0, 0.0);
    
    self.navigationBar.barStyle = UIBarStyleBlackOpaque;
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"concreteBackground.png"]];
    self.gvc.view.backgroundColor = [UIColor clearColor];
    
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:@"Past Features"
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(showPastFeatures:)];
    self.gvc.navigationItem.leftBarButtonItem = button;
    [button release];
    
    [self updateTitleAndHeader];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	return YES;
}

- (void)dealloc {
    [poc release];
    [pvc release];
    [gvc release];
    [_collection release];
    [_guides release];
    [loading release];
    
    [super dealloc];
}

- (void)showPastFeatures:(id)sender {
    if (poc.popoverVisible)
        [poc dismissPopoverAnimated:YES];
    else
        [poc presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
}

- (NSInteger)numberOfCellsForGridViewController:(DMPGridViewController *)gridViewController {
    return [[_collection objectForKey:@"guideids"] count];
}
- (NSString *)gridViewController:(DMPGridViewController *)gridViewController imageURLForCellAtIndex:(NSUInteger)index {
    if (![_guides count])
        return nil;
    return [[[_guides objectAtIndex:index] valueForKey:@"image_url"] stringByAppendingString:@".medium"];
}
- (NSString *)gridViewController:(DMPGridViewController *)gridViewController titleForCellAtIndex:(NSUInteger)index {
    if (![_guides count])
        return @"Loading...";
    
    NSDictionary *guide = [_guides objectAtIndex:index];
    if ([guide objectForKey:@"title"] != [NSNull null])
        return [guide objectForKey:@"title"];
    return [NSString stringWithFormat:@"%@ %@", [guide valueForKey:@"device"], [guide valueForKey:@"thing"]];
}
- (void)gridViewController:(DMPGridViewController *)gridViewController tappedCellAtIndex:(NSUInteger)index {
    NSInteger guideid = [[[_collection objectForKey:@"guideids"] objectAtIndex:index] intValue];
    GuideViewController *vc = [[GuideViewController alloc] initWithGuideid:guideid];
    [self presentModalViewController:vc animated:YES];
    [vc release];
}

@end
