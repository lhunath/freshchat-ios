//
//  HLViewController.m
//  HotlineSDK
//
//  Created by Hrishikesh on 05/02/16.
//  Copyright © 2016 Freshdesk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FCViewController.h"
#import "FCTheme.h"
#import "FCMacros.h"
#import "FCBarButtonItem.h"
#import "FCControllerUtils.h"
#import "FCJWTAuthValidator.h"
#import "FCAutolayoutHelper.h"

@implementation FCViewController : UIViewController

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (self.navigationController == nil) {
        ALog(@"Warning: Use Hotline controllers inside navigation controller");
    }
    else {
        self.navigationController.navigationBar.barStyle = [[FCTheme sharedInstance]statusBarStyle] == UIStatusBarStyleLightContent ?
                                                                    UIBarStyleBlack : UIBarStyleDefault; // barStyle has a different enum but same values .. so hack to clear the update.
        self.navigationController.navigationBar.tintColor = [[FCTheme sharedInstance] navigationBarButtonColor];
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [FCControllerUtils configureGestureDelegate:[self gestureDelegate] forController:self withEmbedded:self.embedded];
}

-(UIViewController<UIGestureRecognizerDelegate> *) gestureDelegate {
    return nil;
}

-(void)configureBackButton{
    [FCControllerUtils configureBackButtonForController:self withEmbedded:self.embedded];
}

- (UIStatusBarStyle)preferredStatusBarStyle{
    return [[FCTheme sharedInstance]statusBarStyle];
}

-(void) addJWTObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jwtStateChange)
                                                 name:JWT_EVENT
                                               object:nil];
}

-(void) removeJWTObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:JWT_EVENT object:nil];
}

-(void) jwtStateChange {
    // Just a skeleton method
}

@end
