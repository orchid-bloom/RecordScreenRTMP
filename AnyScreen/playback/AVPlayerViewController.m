//
//  AVPlayerViewController.m
//  xiaotang1
//
//  Created by pcbeta on 15/10/14.
//  Copyright (c) 2015年 kz. All rights reserved.
//

#import "AVPlayerViewController.h"
#import "AppDelegate.h"
#import "RtmpWrapper.h"

#import "VCSimpleSession.h"


#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>


#define PAUSE_ICON @"pause.png"
#define PLAY_ICON @"play.png"


@interface AVPlayerViewController ()<VCSessionDelegate>
{
     AVPlayerLayer* playerLayer;
     BOOL bInBackground;
     BOOL bInInit;
}
@property (nonatomic, strong) VCSimpleSession *simpleSession;
- (IBAction)playOrPause:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *btnPlay;
@property (weak, nonatomic) IBOutlet UILabel *totalTime;
@property (weak, nonatomic) IBOutlet UILabel *currentTime;
@property (weak, nonatomic) IBOutlet UIView *controlBarView;
@property (weak, nonatomic) IBOutlet UISlider *videoSlider;
- (IBAction)videoSliderValueChanged:(id)sender;
- (IBAction)videoSliderTouchUpInside:(id)sender;

@property (nonatomic ,strong) id playbackTimeObserver;
- (IBAction)videoSliderTouchDragExit:(id)sender;
- (IBAction)videoSliderTouchUpOutside:(id)sender;
- (IBAction)videoSliderTouchCancel:(id)sender;

@end

@implementation AVPlayerViewController

@synthesize stringName;

- (VCSimpleSession *)simpleSession {
    if (!_simpleSession) {
        _simpleSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(640, 1136) frameRate:60 bitrate:60];
    }
    return _simpleSession;
}
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}
- (void)viewDidLoad {
//     NSLog(@"kdd: viewDidLoad");
     [super viewDidLoad];
}
- (void) connectionStatusChanged:(VCSessionState) state
{

}
- (void)customUI
{
     
    UIBarButtonItem* leftBar = [[UIBarButtonItem alloc]initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(homeBack)];
     self.navigationItem.leftBarButtonItem = leftBar;
//     self.navigationItem.backBarButtonItem = leftBar;
    
     [leftBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor blueColor], NSForegroundColorAttributeName, /*[UIFont systemFontOfSize:self.fontSize*2/3], NSFontAttributeName,*/ nil] forState:UIControlStateNormal];
     
     [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
     
     [[UINavigationBar appearance] setTintColor:[UIColor clearColor]];
     
#if 1
     CGSize titleSize = self.navigationController.navigationBar.bounds.size;
 //    NSLog(@"ttt w:%f, h:%f", titleSize.width, titleSize.height);
     //自定义标题
     UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.navigationController.navigationBar.frame.origin.x, self.navigationController.navigationBar.frame.origin.y , titleSize.width, titleSize.height)];
     titleLabel.backgroundColor = [UIColor clearColor];  //设置Label背景透明
//     titleLabel.font = [UIFont boldSystemFontOfSize:self.fontSize*4/4];  //设置文本字体与大小
     titleLabel.textColor = [UIColor colorWithRed:(24.0/255.0) green:(24.0 / 255.0) blue:(48.0 / 255.0) alpha:1];  //设置文本颜色
     titleLabel.textAlignment = NSTextAlignmentCenter;
     titleLabel.text = self.movieName;  //设置标题
     self.navigationItem.titleView = titleLabel;
#endif
     
     [self showOrHideControlBar:1];
}

- (void)homeBack
{
     [self.navigationController popViewControllerAnimated:YES];
}

- (UIImage *)scaleToSize:(UIImage *)img size:(CGSize)size{
     // 创建一个bitmap的context
     // 并把它设置成为当前正在使用的context
     UIGraphicsBeginImageContext(size);
     // 绘制改变大小的图片
     [img drawInRect:CGRectMake(0, 0, size.width, size.height)];
     // 从当前context中创建一个改变大小后的图片
     UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
     // 使当前的context出堆栈
     UIGraphicsEndImageContext();
     // 返回新的改变大小后的图片
     return scaledImage;
}

-(void)viewWillAppear:(BOOL)animated
{
     [super viewWillAppear:animated];
////     NSLog(@"kdd:viewWillAppear");
   
     // Do any additional setup after loading the view, typically from a nib.
     [self initMovie];
     
     /*kdd:如果view的背景选了clear color，此view上面又没有其他控件，直接是透明的，则没法响应点击动作*/
     UITapGestureRecognizer*tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(Actiondo:)];
     
     [self.view addGestureRecognizer:tapGesture];
     
     UITapGestureRecognizer*tapGestureNone = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(ActiondoNothing:)];
     
     [self.controlBarView addGestureRecognizer:tapGestureNone];
     self.title = self.movieName;  //设置标题
////     [self customUI];
}

- (void)viewDidAppear:(BOOL)animated
{
//     NSLog(@"kdd:viewDidAppear");
     [super viewDidAppear:animated];
     
#if 1
     AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
     [appDelegate setViewControllerToBeObserved:self];
#endif
     
     bInBackground = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
     [super viewWillDisappear:animated];
//     NSLog(@"kdd: viewWillDisappear");
     
     [self cleanupVidoPlay];
 
}

- (void)viewDidDisappear:(BOOL)animated
{
     [super viewDidDisappear:animated];
     
//     NSLog(@"kdd:viewDidDisappear");
     
////disappear后，必须设置appdelegate的这个指针为nil，否则会导致本view controller有一个指针被AppDelegate记住了，这样，退出本view的时候，本view的dealloc函数不会被调用，因为该指针还有一个引用计数器。
     AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
     [appDelegate setViewControllerToBeObserved:nil];

}

- (void)didReceiveMemoryWarning {
     [super didReceiveMemoryWarning];
     // Dispose of any resources that can be recreated.
}

- (void)initMovie
{
     NSString *movieFile = self.stringName;

     // Setup a PlayerItem and a Player
     NSURL* movieURL = [NSURL fileURLWithPath:movieFile];
     
     AVURLAsset* movieAsset = [AVURLAsset assetWithURL:movieURL];
     AVPlayerItem* playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
     AVPlayer* player = [AVPlayer playerWithPlayerItem:playerItem];
     
     bInInit = YES;
    
    
     NSError *error = nil;
     [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    
     // setup the layer so you can see it
     playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
     playerLayer.frame = self.view.bounds;
     
 //    [self.view.layer addSublayer:playerLayer];
     [self.view.layer insertSublayer:playerLayer atIndex:0];
     playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;

     [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];// 监听status属性
     // 添加视频播放结束通知
     [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];

//     [player play];
     
     // Verify our assumptions, in production code you should do something better
     //    NSAsset(player.currentItem.canStepForward, @"Assume this format can step forward");
     //   NSAsset(player.currentItem.canStepBackward, @"Assume this format can step backward");
     
     //    [player play];
     //    [player.currentItem stepByCount:1];  // step forward a frame
     
     //    [player.currentItem stepByCount:-1];  // step backward a frame


}


- (void)cleanupVidoPlay
{
     // 取消监听
     [playerLayer.player pause];
     
//     NSLog(@"kdd: cleanup video play");
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//     NSLog(@"视图旋转完成之后自动调用");
     
     playerLayer.frame = self.view.bounds;
}


- (IBAction)playOrPause:(id)sender
{
     if(playerLayer.player.rate == 0)
     {
//          NSLog(@"AVPlayerStatus is paused, To Play");
          [playerLayer.player play];
 //        self.controlBarView.hidden =YES;
          [self updatePlayPauseButton:1];
     }
     else
     {
//          NSLog(@"AVPlayerStatus is playing, To pause");
          [playerLayer.player pause];
          [self updatePlayPauseButton:0];
    }
     
     [self showOrHideControlBar:1];
}

- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
     
     __weak typeof(self) weakSelf = self;
     self.playbackTimeObserver = [playerLayer.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
          CGFloat currentSecond = playerItem.currentTime.value/playerItem.currentTime.timescale;// 计算当前在第几秒
          weakSelf.currentTime.text = [NSString stringWithFormat:@"%02li:%02li:%02li",
                                     lround(floor(currentSecond / 3600.)),
                                     lround(floor(currentSecond / 60.)) % 60,
                                     lround(floor(currentSecond)) % 60];
     
          [weakSelf.videoSlider setValue:currentSecond animated:YES];
          
          [weakSelf showOrHideControlBar:2];

          }];
}

// KVO方法
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
     AVPlayerItem *playerItem = (AVPlayerItem *)object;
     if ([keyPath isEqualToString:@"status"]) {
          if ([playerItem status] == AVPlayerStatusReadyToPlay) {
//               NSLog(@"AVPlayerStatusReadyToPlay");
               
               if(bInInit)
               {
                    CMTime duration = playerItem.duration;// 获取视频总长度
                    CGFloat totalSecond = duration.value / duration.timescale;// 转换成秒
                    self.totalTime.text = [NSString stringWithFormat:@"%02li:%02li:%02li",
                                      lround(floor(totalSecond / 3600.)),
                                      lround(floor(totalSecond / 60.)) % 60,
                                      lround(floor(totalSecond)) % 60];
               
                    [self customVideoSlider:duration];// 自定义UISlider外观
               
                    [self monitoringPlayback:playerItem];// 监听播放状态
               
                    [playerLayer.player play];
                    
                    [self updatePlayPauseButton:1];
                    
                    bInInit = NO;
               }
               
          } else if ([playerItem status] == AVPlayerStatusFailed) {
               NSLog(@"AVPlayerStatusFailed");
          }
     }
}

- (void)updatePlayPauseButton:(int)bPause
{
     if(bPause)
     {
          [self.btnPlay setBackgroundImage:[UIImage imageNamed:PAUSE_ICON] forState:UIControlStateNormal];
     }
     else
     {
          [self.btnPlay setBackgroundImage:[UIImage imageNamed:PLAY_ICON] forState:UIControlStateNormal];
     }
     
}

- (void)updateVideoSlider:(CGFloat)currentSecond {
     [self.videoSlider setValue:currentSecond animated:YES];
}

- (void)customVideoSlider:(CMTime)duration {
     self.videoSlider.maximumValue = CMTimeGetSeconds(duration);

#if 0
     UIGraphicsBeginImageContextWithOptions((CGSize){ 1, 1 }, NO, 0.0f);
     UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
     UIGraphicsEndImageContext();
     
     [self.videoSlider setMinimumTrackImage:transparentImage forState:UIControlStateNormal];
     [self.videoSlider setMaximumTrackImage:transparentImage forState:UIControlStateNormal];
#endif
}

- (void)enterBackground
{
     bInBackground = YES;
     
     [playerLayer.player pause];
//     NSLog(@"kdd: enterBackground");
}

- (void)enterForeground
{
//     NSLog(@"kdd: enterForeground");
     bInBackground = NO;
     
     if(playerLayer.player.rate == 0)
     {//is pausing
          //set button to "play"
          [self updatePlayPauseButton:0];
          //show control bar
          [self showOrHideControlBar:1];
     }
     else
     {//is playing
          
     }
}

- (void)registerObservers
{
     
}

- (void)releaseObservers
{
     [playerLayer.player.currentItem removeObserver:self forKeyPath:@"status" context:nil];
     [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:playerLayer.player.currentItem];
     [playerLayer.player removeTimeObserver:self.playbackTimeObserver];
     
//     NSLog(@"kdd: release observers");
}

- (void)dealloc {
//     NSLog(@"kdd: dealloc");
     [self releaseObservers];
     
#if 1
     AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
     [appDelegate setViewControllerToBeObserved:nil];
#endif
}

- (void)moviePlayDidEnd:(NSNotification *)notification {
//     NSLog(@"Play end");
 CMTime startTime = CMTimeMakeWithSeconds(1, 15);
     [playerLayer.player seekToTime:startTime/*kCMTimeZero*/ completionHandler:^(BOOL finished) {
          [self.videoSlider setValue:0.0 animated:YES];
          [self updatePlayPauseButton:0];
          [self showOrHideControlBar:1];
     }];
}


-(void)Actiondo:(id)sender
{
     if(self.controlBarView.hidden == NO)
          [self showOrHideControlBar:0];
     else
          [self showOrHideControlBar:1];
}

-(void)ActiondoNothing:(id)sender
{
}

/**
     \brief    if mode=auto, should be called every 1 second
     \param    mode 0, hide
                    1, show
                    2, auto
 */
- (void)showOrHideControlBar:(int)mode
{
     static int count = 0;
     
     if(mode == 0)
     {
          [self.navigationController setNavigationBarHidden:YES animated:YES];
          [self.controlBarView setHidden:YES];
          count = 0;
//          NSLog(@"--TO HIDE");
     }
     else if(mode == 1)
     {
          [self.navigationController setNavigationBarHidden:NO animated:YES];
          [self.controlBarView setHidden:NO];
          count = 0;
//          NSLog(@"--TO SHOW");
     }
     else
     {
          if(self.controlBarView.hidden == YES)
          {
//               NSLog(@"-- HIDING");
              count = 0;
          }
          else
          {
//               NSLog(@"--COUNT ++");
               count ++;
          }
     
          if(count > 8)
          {
               [self.navigationController setNavigationBarHidden:YES animated:YES];
               [self.controlBarView setHidden:YES];
               count = 0;
//               NSLog(@"--TO HIDE AUTO");
          }
     }
}

-(void)replayAfterSlider
{
     [playerLayer.player play];
     [self updatePlayPauseButton:1];
     [self showOrHideControlBar:1];
}

- (IBAction)videoSliderTouchDragExit:(id)sender {
//     NSLog(@"kdd: videoSliderTouchDragExit");
}

- (IBAction)videoSliderValueChanged:(id)sender {
     UISlider *slider = (UISlider *)sender;
//     NSLog(@"kdd: videoSliderValueChanged:%f",slider.value);
     CMTime changedTime = CMTimeMakeWithSeconds(slider.value, 1);
     
     [playerLayer.player pause];
     [playerLayer.player seekToTime:changedTime completionHandler:^(BOOL finished) {
          //  [playerLayer.player play];
          
     }];
     
     [self showOrHideControlBar:1];
}

- (IBAction)videoSliderTouchUpInside:(id)sender {
//     NSLog(@"kdd:videoSliderTouchUpInside:%f",slider.value);
     
     [self replayAfterSlider];
}

- (IBAction)videoSliderTouchUpOutside:(id)sender {
//     NSLog(@"kdd: videoSliderTouchUpOutside");
     [self replayAfterSlider];
}

- (IBAction)videoSliderTouchCancel:(id)sender {
//     NSLog(@"kdd: videoSliderTouchCancel");
     [self replayAfterSlider];
}
@end
