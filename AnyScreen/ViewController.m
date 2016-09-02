//
//  ViewController.m
//  AnyScreen
//
//  Created by pcbeta on 15/12/12.
//  Copyright © 2015年 xindawn. All rights reserved.
//

#import "ViewController.h"
#import "CSScreenRecorder.h"
#import "IDFileManager.h"

#include <mach/mach_time.h>
#import <objc/message.h>
#import <dlfcn.h>

#import "RtmpWrapper.h"

@import MediaPlayer;

@interface ViewController ()<CSScreenRecorderDelegate>
{
    BOOL bRecording;
    CSScreenRecorder *_screenRecorder;
    MPVolumeView *volumeView;
}

@property (weak, nonatomic) IBOutlet UIButton *btnRecord;
@property (weak, nonatomic) IBOutlet UIView *mpView;
@property (weak, nonatomic) IBOutlet UILabel *labelTime;

@end



@implementation ViewController

- (NSString*)generateMP4Name
{
    NSDateFormatter *formatter =[[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd-HHmmss"];
    NSString *currentTime = [formatter stringFromDate:[NSDate date]];
    NSString *fname = [NSString stringWithFormat:@"%@", currentTime];
    
    return [IDFileManager inDocumentsDirectory:fname];
    
}
- (void)startRecord
{
    _screenRecorder.videoOutPath = [self generateMP4Name];
    
    [_screenRecorder startRecordingScreen];
    bRecording = YES;
    [self.btnRecord setTitle:NSLocalizedString(@"STR_CANCEL",nil) forState:UIControlStateNormal];
    [self.mpView setHidden:NO];    
}

- (void)stopRecord
{
    [_screenRecorder stopRecordingScreen];
    bRecording = NO;
    [self.btnRecord setTitle:NSLocalizedString(@"STR_PREPARE",nil) forState:UIControlStateNormal];
//    [self.mpView setHidden:NO];
}

- (IBAction)toggleRecord:(id)sender {
    if(bRecording)
    {
        [self stopRecord];
    }
    else
    {
        [self startRecord];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [_screenRecorder setDelegate:self];

//    [self startRecord];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    bRecording = NO;
    [self.btnRecord setTitle:NSLocalizedString(@"STR_PREPARE",nil) forState:UIControlStateNormal];
    _screenRecorder = [CSScreenRecorder sharedCSScreenRecorder];

    [self.labelTime setHidden:YES];
    
#if 0
    MPVolumeView *volumeView = [ [MPVolumeView alloc] init] ;
    
    [self.view addSubview:volumeView];
    [volumeView sizeToFit];     
#endif
    
#if 1
    
    CGRect rect;
    rect = self.mpView.frame;
    rect.origin.x = rect.origin.y = 0;
    
    volumeView = [[MPVolumeView alloc] initWithFrame:rect];
    //MPVolumeView *volumeView = [ [MPVolumeView alloc] init] ;
    
    [volumeView setShowsVolumeSlider:NO];
    
    [volumeView sizeToFit];
    [self.mpView addSubview:volumeView];
    
    [volumeView becomeFirstResponder];
    [volumeView setShowsRouteButton:YES];
    [volumeView setRouteButtonImage:[UIImage imageNamed:@"btn_record.png"] forState:UIControlStateNormal];
    [volumeView setRouteButtonImage:nil forState:UIControlStateNormal];
#if 0
    {
        NSLayoutConstraint* contentViewConstraint =
        [NSLayoutConstraint	 constraintWithItem:volumeView
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.view
                                      attribute:NSLayoutAttributeCenterX
                                     multiplier:1.0
                                       constant:0];
        [self.view addConstraint:contentViewConstraint];
    }
    
    {
        NSLayoutConstraint* contentViewConstraint =
        [NSLayoutConstraint	 constraintWithItem:volumeView
                                      attribute:NSLayoutAttributeWidth
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.view
                                      attribute:NSLayoutAttributeWidth
                                     multiplier:1.0
                                       constant:0];
        [self.view addConstraint:contentViewConstraint];
    }
    
    {
        NSLayoutConstraint* contentViewConstraint =
        [NSLayoutConstraint	 constraintWithItem:volumeView
                                      attribute:NSLayoutAttributeBottom
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.view
                                      attribute:NSLayoutAttributeBottom
                                     multiplier:1.0
                                       constant:0];
        [self.view addConstraint:contentViewConstraint];
    }
#endif

#endif
}

- (void)viewWillLayoutSubviews
{
    
    [super viewWillLayoutSubviews];
    for (UIView *subView in [volumeView subviews])
    {
        if ([subView isKindOfClass:[UIButton class]])
        {
            CGRect rect;
            rect = self.mpView.frame;
            rect.origin.x = rect.origin.y = 0;
            
            [volumeView setFrame:rect];
            
            //NSLog(@"subview==%@",subView);
            NSString *astring = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%@%@",
                                                                  NSLocalizedString(@"STR_SELECT",nil), @AIR_NAME]];
            [(UIButton*)subView setTitle:astring forState:UIControlStateNormal];
//            NSLog(@"%f,%f,%f,%f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
            [(UIButton*)subView setFrame:rect];
            [(UIButton*)subView setBackgroundColor:  [UIColor colorWithRed:00.0/255.0 green:00.0/255.0 blue:100.0/255.0 alpha:1.0]];
            
        }
    }
    

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    

}
- (void)screenRecorderDidStartRecording:(CSScreenRecorder *)recorder
{
    NSLog(@"KDD, DID START");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.btnRecord setTitle:NSLocalizedString(@"STR_STOP",nil) forState:UIControlStateNormal];
        [self.mpView setHidden:YES];
        
        [self.labelTime setText:@""];
        [self.labelTime setHidden:NO];
    });
}

- (void)screenRecorderDidStopRecording:(CSScreenRecorder *)recorder
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.btnRecord setTitle:NSLocalizedString(@"STR_PREPARE",nil) forState:UIControlStateNormal];
//        [self.mpView setHidden:NO];
        
        [self.labelTime setHidden:YES];
    });
   
}


- (void)screenRecorder:(CSScreenRecorder *)recorder recordingTimeChanged:(NSTimeInterval)recordingTime
{// time in seconds since start of capture
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *string = [NSString stringWithFormat:@"%02li:%02li:%02li",
                            lround(floor(recordingTime / 3600.)) % 100,
                            lround(floor(recordingTime / 60.)) % 60,
                            lround(floor(recordingTime)) % 60];
        [self.labelTime setText:string];
        //        [self.mpView setHidden:NO];
    });
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
