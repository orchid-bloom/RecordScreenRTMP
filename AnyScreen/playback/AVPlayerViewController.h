//
//  AVPlayerViewController.h
//  xiaotang1
//
//  Created by pcbeta on 15/10/14.
//  Copyright (c) 2015年 kz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface AVPlayerViewController : UIViewController

@property (nonatomic, strong) NSString *stringName;
@property (nonatomic, strong) NSString *movieName;
@property  int fontSize;

@property (strong, nonatomic) MPMoviePlayerController *moviePlayer;

- (void)enterBackground;
- (void)enterForeground;

@end
