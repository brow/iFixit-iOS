//
//  GuideCatchingWebView.m
//  iFixit
//
//  Created by David Patierno on 4/21/11.
//  Copyright 2011 iFixit. All rights reserved.
//

#import "GuideCatchingWebView.h"
#import "iFixitAppDelegate.h"
#import "Config.h"
#import "RegexKitLite.h"

@implementation GuideCatchingWebView

@synthesize externalDelegate, externalURL, formatter;

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        self.delegate = self;
        self.formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    }
    return self;
}

- (void)setDelegate:(id<UIWebViewDelegate>)newDelegate {
    if (newDelegate == self) {
        super.delegate = self;
    }
    else {
        self.externalDelegate = newDelegate;
    }
}

- (NSInteger)parseGuideURL:(NSString *)url {
	/*
	 (
	 "http:",
	 "",
	 "www.ifixit.com",
	 Guide,
	 "Installing-iPhone-4-Speaker-Enclosure",
	 3149,
	 1
	 )
	 */
    
    
    NSString *regexString = [NSString stringWithFormat:@"https?://%@/(Guide|Teardown|Project)/(.*?)/([0-9]+)/([0-9]+)", [Config currentConfig].host];
    NSString *guideidString = [url stringByMatching:regexString capture:3];
    NSNumber *guideid = guideidString ? [formatter numberFromString:guideidString] : [NSNumber numberWithInt:-1];

    return [guideid intValue];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSString *host = [[request URL] host];
    
	// Open guides with the native viewer.
	NSInteger guideid = [self parseGuideURL:[[request URL] absoluteString]];

	if (guideid != -1) {
		[(iFixitAppDelegate *)[[UIApplication sharedApplication] delegate] showGuideid:guideid];
		return NO;
	}
    
    BOOL shouldStart = YES;
    if ([externalDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)])
        shouldStart = [externalDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    
    if (shouldStart) {
        // Open all other URLs with Safari.
        if (![host isEqual:[Config host]] && navigationType == UIWebViewNavigationTypeLinkClicked) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Open with Safari?"
                                                            message:@"You are now leaving the native app experience. Following this link will open a new window in Safari.\n\nWould you like to continue?"
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:@"Okay", nil];
            self.externalURL = [request URL];
            [alert show];
            [alert release];
            
            return NO;
        }
    }
	
	// Add custom headers if needed, and restart the request.
    /*
    if ([host isEqual:[Config host]]) {
        NSDictionary *headers = [request allHTTPHeaderFields];
        BOOL hasCustomHeader = NO; 
        for (NSString *key in [headers allKeys]) {
            if ([key isEqualToString:@"Mobile-Client"]) {
                hasCustomHeader = YES;
                break;
            }   
        }
        
        if (!hasCustomHeader) {
            NSString *device = [iFixitAppDelegate isIPad] ? @"Wide iFixit" : @"Thin iFixit";
            NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];	
            NSString *mobileClient = [NSString stringWithFormat:@"%@ %@", device, version];
            
            NSMutableURLRequest *newRequest = [request mutableCopy];
            [newRequest setValue:mobileClient forHTTPHeaderField:@"Mobile-Client"];
            [webView loadRequest:newRequest];
            return NO;
        }
    }
     */
    
	return shouldStart;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex)
		[[UIApplication sharedApplication] openURL:externalURL];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if ([externalDelegate respondsToSelector:@selector(webViewDidFinishLoad:)])
        [externalDelegate webViewDidFinishLoad:webView];
}
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if ([externalDelegate respondsToSelector:@selector(webViewDidStartLoad:)])
        [externalDelegate webViewDidStartLoad:webView];
}

- (void)dealloc {
    self.externalDelegate = nil;
    self.formatter = nil;
    self.externalURL = nil;
    
    [super dealloc];
}
@end