//
//  CSScreenRecorder.h
//  RecordMyScreen
//
//  Created by Aditya KD on 02/04/13.
//  Copyright (c) 2013 CoolStar Organization. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "VCSimpleSession.h"

#define AIR_NAME "Xindawn"

#define kFileAddedNotification  @"fileCompleted"

@protocol CSScreenRecorderDelegate;


@interface CSScreenRecorder : NSObject <AVAudioRecorderDelegate>

// All these properties must be set before -startRecordingScreen is called, or defaults will be used.
@property (nonatomic, strong) VCSimpleSession *simpleSession;

// the path where the video/audio is saved whilst being recorded.
@property(nonatomic, copy) NSString *videoOutPath;

@property(nonatomic, copy) NSNumber *audioSampleRate;
@property(nonatomic, copy) NSNumber *numberOfAudioChannels;

@property(nonatomic, assign) id<CSScreenRecorderDelegate> delegate;

- (void)startRecordingScreen;
- (void)stopRecordingScreen;
- (void)setDelegate:(id<CSScreenRecorderDelegate>)delegate;
+ (CSScreenRecorder *) sharedCSScreenRecorder;

@end

@protocol CSScreenRecorderDelegate <NSObject>
@optional
- (void)screenRecorderDidStartRecording:(CSScreenRecorder *)recorder;
- (void)screenRecorderDidStopRecording:(CSScreenRecorder *)recorder;
// Called every second.
- (void)screenRecorder:(CSScreenRecorder *)recorder recordingTimeChanged:(NSTimeInterval)recordingTime; // time in seconds since start of capture

- (void)screenRecorder:(CSScreenRecorder *)recorder videoContextSetupFailedWithError:(NSError *)error;
- (void)screenRecorder:(CSScreenRecorder *)recorder audioSessionSetupFailedWithError:(NSError *)error;
- (void)screenRecorder:(CSScreenRecorder *)recorder audioRecorderSetupFailedWithError:(NSError *)error;

@end
