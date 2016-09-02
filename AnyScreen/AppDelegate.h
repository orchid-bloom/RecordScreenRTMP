//
//  AppDelegate.h
//  AnyScreen
//
//  Created by pcbeta on 15/12/12.
//  Copyright © 2015年 xindawn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVPlayerViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void)setViewControllerToBeObserved:(AVPlayerViewController*)vc;

@end

