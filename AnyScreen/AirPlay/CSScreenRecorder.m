//
//  CSScreenRecorder.m
//  RecordMyScreen
//
//  Created by Aditya KD on 02/04/13.
//  Copyright (c) 2013 CoolStar Organization. All rights reserved.
//

#import "CSScreenRecorder.h"

#import <CoreVideo/CVPixelBuffer.h>
#import <QuartzCore/QuartzCore.h>

#include <sys/time.h>

#include "Utilities.h"
#include "mediaserver.h"
#include "mp4v2/mp4v2.h"
#include <pthread.h>
#import "IDFileManager.h"

#import "RtmpWrapper.h"
#include "rtmp.h"
#include <time.h>

#include "VideoFileParser.h"
#import "H264ViewController.h"
#import "BysBufferShower.h"

static AVAudioRecorder    *_audioRecorder=nil ;

@interface CSScreenRecorder ()
@property (nonatomic, strong) RtmpWrapper *rtmpWrapper;
@property (nonatomic, strong) H264ViewController *h264ViewController;
- (void)_setupAudio;
- (void)_finishEncoding;


@end

@implementation CSScreenRecorder

static CSScreenRecorder * _sharedCSScreenRecorder;

+ (CSScreenRecorder *) sharedCSScreenRecorder
{
    
    if (_sharedCSScreenRecorder != nil) {
        return _sharedCSScreenRecorder;
    }
    _sharedCSScreenRecorder = [[CSScreenRecorder alloc] init];
    
   
    return _sharedCSScreenRecorder;
}

- (void)setDelegate:(id<CSScreenRecorderDelegate>)delegate{
    @synchronized(self)
    {
        _delegate = delegate;
    }
}


- (instancetype)init
{
    if ((self = [super init])) {
        
    }
    return self;
}

- (void)dealloc
{
    
    
    _audioRecorder = nil;
    
}
- (VCSimpleSession *)simpleSession {
    if (!_simpleSession) {
        _simpleSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(640, 1136) frameRate:60 bitrate:60];
    }
    return _simpleSession;
}
- (RtmpWrapper *)rtmpWrapper {
    if (!_rtmpWrapper) {
        _rtmpWrapper = [[RtmpWrapper alloc] init];
    }
    return _rtmpWrapper;
}
- (H264ViewController *)h264ViewController {
    if (!_h264ViewController) {
        _h264ViewController = [[H264ViewController alloc] init];
    }
    return _h264ViewController;
}
static NSString *_videoName = nil;

NSString *fileName;
NSString *exportFileName;
NSString* audioOutPath;

MP4FileHandle hMp4file = MP4_INVALID_FILE_HANDLE;
MP4TrackId    m_videoId = MP4_INVALID_TRACK_ID;
MP4TrackId    m_audioId = MP4_INVALID_TRACK_ID;
static int    mp4_init_flag = 0;
pthread_mutex_t write_mutex;

#define SAVE_264_ENABLE 1


#if SAVE_264_ENABLE

#endif

FILE  *m_handle = NULL;

NSString *tmpFile1;

unsigned char *sps;
int spscnt;
int spsnalsize;

unsigned char *pps;
int ppscnt;
int ppsnalsize;

/*定义包头长度,RTMP_MAX_HEADER_SIZE为rtmp.h中定义值为18*/

#define RTMP_HEAD_SIZE   (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

RTMP *rtmp;
double lastTime = 0;

void video_open(void *cls, int width, int height, const void *buffer, int buflen, int payloadtype, double timestamp)
{
    printf("open---\n");
    
    unsigned    char *data;
    
    //rLen = 0;
    data = (unsigned char *)buffer ;
    
    spscnt = data[5] & 0x1f;
    spsnalsize = ((uint32_t)data[6] << 8) | ((uint32_t)data[7]);
    ppscnt = data[8 + spsnalsize];
    ppsnalsize = ((uint32_t)data[9 + spsnalsize] << 8) | ((uint32_t)data[10 + spsnalsize]);
    
    sps = (unsigned char *)malloc(spsnalsize );
    pps = (unsigned char *)malloc(ppsnalsize);
    
    memcpy(sps, data + 8, spsnalsize);
    memcpy(pps, data + 11 + spsnalsize, ppsnalsize);
    
    _videoName = [CSScreenRecorder sharedCSScreenRecorder].videoOutPath;
    
    //[[NSTemporaryDirectory() stringByAppendingString:@"tmp1.mov"] UTF8String];
    fileName = [NSString stringWithFormat:@"%@tmp000000.mov", NSTemporaryDirectory()];

    
    printf("width: %d   height: %d \n", width, height);
    
    hMp4file = MP4Create([fileName cStringUsingEncoding: NSUTF8StringEncoding],0);
    
    MP4SetTimeScale(hMp4file, 90000);

    m_videoId = MP4AddH264VideoTrack (hMp4file,
                                      90000,
                                      90000 / 60,
                                      width, // width
                                      height,// height
                                      sps[1], // sps[1] AVCProfileIndication
                                      sps[2], // sps[2] profile_compat
                                      sps[3], // sps[3] AVCLevelIndication
                                      3);           // 4 bytes length before each NAL unit
    
    if (m_videoId == MP4_INVALID_TRACK_ID) {
        printf("add video track failed.\n");
        //return false;
    }
    MP4SetVideoProfileLevel(hMp4file, 0x7f); //  Simple Profile @ Level 3
    
    // write sps
    MP4AddH264SequenceParameterSet(hMp4file, m_videoId, sps, spsnalsize);
    
    
    // write pps
    MP4AddH264PictureParameterSet(hMp4file, m_videoId, pps, ppsnalsize);
    
//    free(sps);
//    free(pps);
    
    unsigned char eld_conf[2] = { 0x12, 0x10 };
    
    m_audioId = MP4AddAudioTrack(hMp4file, 44100, 1024, MP4_MPEG4_AUDIO_TYPE);  //sampleDuration.
    
    if (m_audioId == MP4_INVALID_TRACK_ID) {
        printf("add video track failed.\n");
        //return false;
    }

    MP4SetAudioProfileLevel(hMp4file, 0x0F);
    MP4SetTrackESConfiguration(hMp4file, m_audioId, &eld_conf[0], 2);
    
#if SAVE_264_ENABLE
    {
        tmpFile1 = [Utilities documentsPath:@"tmp1.h264"];
        
        m_handle = fopen([tmpFile1 cStringUsingEncoding: NSUTF8StringEncoding], "wb");
        
        unsigned char *head = (unsigned  char *)buffer;
        
        spscnt = head[5] & 0x1f;
        spsnalsize = ((uint32_t)head[6] << 8) | ((uint32_t)head[7]);
        ppscnt = head[8 + spsnalsize];
        ppsnalsize = ((uint32_t)head[9 + spsnalsize] << 8) | ((uint32_t)head[10 + spsnalsize]);
        
        unsigned char *data = (unsigned char *)malloc(4 + spsnalsize + 4 + ppsnalsize);
        
        data[0] = 0;
        data[1] = 0;
        data[2] = 0;
        data[3] = 1;
        
        memcpy(data + 4, head + 8, spsnalsize);
        
        data[4 + spsnalsize] = 0;
        data[5 + spsnalsize] = 0;
        data[6 + spsnalsize] = 0;
        data[7 + spsnalsize] = 1;
        
        memcpy(data + 8 + spsnalsize, head + 11 + spsnalsize, ppsnalsize);
        
        fwrite(data,1,4 + spsnalsize + 4 + ppsnalsize,m_handle);
//        [[CSScreenRecorder sharedCSScreenRecorder].simpleSession sendVideoData:[NSData dataWithBytes:data length:4 + spsnalsize + 4 + ppsnalsize] length:(4 + spsnalsize + 4 + ppsnalsize)];
        
        showbuffer(data, 4 + spsnalsize + 4 + ppsnalsize);
        free(data);
    }
#endif
    pthread_mutex_init(&write_mutex, NULL);
    
    mp4_init_flag = 1;
    
//kdd
    int rec = initRtmp();
    if (rec == 1) {
        printf("链接成功！\n");
        sendDataFrame(width, height);
        //setChunkSize();
        send_video_sps_pps();
    }
    
    [[CSScreenRecorder sharedCSScreenRecorder].delegate screenRecorderDidStartRecording:[CSScreenRecorder sharedCSScreenRecorder]];
    
    [[AVAudioSession sharedInstance]  setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [[AVAudioSession sharedInstance]  setMode:AVAudioSessionModeVoiceChat error:nil];
    [[AVAudioSession sharedInstance]  overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    //[_audioRecorder setDelegate:self];
     [_audioRecorder prepareToRecord];
    
    // Start recording :P
      [_audioRecorder record];
}

void video_process(void *cls,const void *buffer, int buflen, int payloadtype, double timestamp)
{
    while (!mp4_init_flag) {
        usleep(1000);
    }
    
    if (payloadtype == 0) {
        lastTime += 16;
        //showbuffer(buffer, buflen);
        pthread_mutex_lock(&write_mutex);
//        if (hMp4file) {
//            MP4WriteSample(hMp4file, m_videoId, buffer, buflen, MP4_INVALID_DURATION, 0, 0);
//        }
        pthread_mutex_unlock(&write_mutex);
        
#if SAVE_264_ENABLE
        {
            int		    rLen, lastNalLength;
            unsigned    char *head;
            
            unsigned char *data = (unsigned char *)malloc(buflen);
            memcpy(data, buffer, buflen);
            
            rLen = 0;
            lastNalLength = 0;
            head = (unsigned char *)data + rLen;

            while (rLen < buflen) {
                rLen += 4;
                rLen += (((uint32_t)head[0] << 24) | ((uint32_t)head[1] << 16) | ((uint32_t)head[2] << 8) | (uint32_t)head[3]);
                
                head[0] = 0;
                head[1] = 0;
                head[2] = 0;
                head[3] = 1;

                head = (unsigned char *)data + rLen;
            }
            //fwrite(data,1,buflen,m_handle);
            
            int type = data[4] & 0x1F;
            
            if (type == 7) {
                spsnalsize = buflen-4;
                memcpy(sps, data+4, spsnalsize);
            } else if (type == 8) {
                ppsnalsize = ppsnalsize-4;
                memcpy(pps, data+4, ppsnalsize);
                /*发送sps pps*/
                send_video_sps_pps();
            } else {
                /*发送普通帧*/
                send_rtmp_video(data, buflen, timestamp);
            }
            
//            showbuffer(data, buflen);

            free(data);
        }
#endif
        
    } else {
        printf("=====buflen====%d====\n", buflen);
    }
    // printf("=====video====%f====\n",timestamp);
    //kdd
    [[CSScreenRecorder sharedCSScreenRecorder].delegate screenRecorder:[CSScreenRecorder sharedCSScreenRecorder] recordingTimeChanged:timestamp];
    
}
int initRtmp()
{
    /*分配与初始化*/
    rtmp = RTMP_Alloc();
    RTMP_Init(rtmp);
    
    /*设置URL*/
    if (RTMP_SetupURL(rtmp, "推流地址") == FALSE) {
        printf("RTMP_SetupURL() failed!");
        RTMP_Free(rtmp);
        return -1;
    }
    
    /*设置可写,即发布流,这个函数必须在连接前使用,否则无效*/
    RTMP_EnableWrite(rtmp);
    
    /*连接服务器*/
    if (RTMP_Connect(rtmp, NULL) == FALSE) {
        printf("RTMP_Connect() failed!");
        RTMP_Free(rtmp);
        return -1;
    }
    
    /*连接流*/
    if (RTMP_ConnectStream(rtmp,0) == FALSE) {
        printf("RTMP_ConnectStream() failed!");
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        return -1;
    }
    lastTime = [[NSDate new] timeIntervalSince1970];
    return 1;
}
void sendDataFrame(int width, int height)
{
    RTMPPacket *packet;
    unsigned char * body;
    
    packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE+1024);
    memset(packet,0,RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
    body = (unsigned char *)packet->m_body;
    
    packet->m_nChannel = 0x06;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet->m_nTimeStamp = 0;
    packet->m_nInfoField2 = rtmp->m_stream_id;
    packet->m_hasAbsTimestamp = 0;
    
    char * szTmp=(char *)body;
    packet->m_packetType = RTMP_PACKET_TYPE_INFO;
    szTmp=put_byte(szTmp, AMF_STRING );
    szTmp=put_amf_string(szTmp, "@setDataFrame" );
    szTmp=put_byte(szTmp, AMF_STRING );
    szTmp=put_amf_string(szTmp, "onMetaData" );
    szTmp=put_byte(szTmp, AMF_OBJECT );
    szTmp = put_amf_string(szTmp, "duration");
    szTmp = put_amf_double(szTmp, 0);
    szTmp = put_amf_string(szTmp, "width" );
    szTmp = put_amf_double(szTmp, 640.0 );//p264Param->i_width );
    szTmp = put_amf_string(szTmp, "height" );
    szTmp = put_amf_double(szTmp, 1136.0 );//p264Param->i_height );
    szTmp = put_amf_string(szTmp, "framerate" );
    szTmp = put_amf_double(szTmp, 60.0 );//(double)p264Param->i_fps_num / p264Param->i_fps_den );
    szTmp = put_amf_string(szTmp, "videocodecid" );
    szTmp = put_amf_double(szTmp, 7);
    szTmp=put_amf_string( szTmp, "" );
    szTmp=put_byte( szTmp, AMF_OBJECT_END );
    packet->m_nBodySize=szTmp-(char *)body;
    
    printf( "sending %d as header\n", packet->m_nBodySize );
    
    //hex_dump_internal(packet.m_body, packet.m_nBodySize);
    
    RTMP_SendPacket(rtmp, packet,1);
}
void setChunkSize()
{
    RTMPPacket *packet;
    unsigned char * body;
    
    packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE+1024);
    memset(packet,0,RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
    body = (unsigned char *)packet->m_body;
    
    packet->m_nChannel = 0x06;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet->m_nTimeStamp = 0;
    packet->m_nInfoField2 = rtmp->m_stream_id;
    packet->m_hasAbsTimestamp = 0;
    
    char * szTmp=(char *)body;
    packet->m_packetType = RTMP_PACKET_TYPE_CHUNK_SIZE;
    
    szTmp = put_be32(szTmp, 4096);
    
    packet->m_nBodySize=szTmp-(char *)body;
    
    printf( "setChunkSize");
    
    //hex_dump_internal(packet.m_body, packet.m_nBodySize);
    
    RTMP_SendPacket(rtmp, packet,1);
}
void send_video_sps_pps()
{
    RTMPPacket * packet;
    unsigned char * body;
    int i;
    
    packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE+1024);
    memset(packet,0,RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
    body = (unsigned char *)packet->m_body;
    
    i = 0;
    body[i++] = 0x17;
    body[i++] = 0x00;
    
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    
    /*AVCDecoderConfigurationRecord*/
    body[i++] = 0x01;
    body[i++] = sps[1];
    body[i++] = sps[2];
    body[i++] = sps[3];
    body[i++] = 0x03;
    
    /*sps*/
    body[i++]   = 0xe1;
    
    body[i++] = spsnalsize >> 8;
    body[i++] = spsnalsize & 0xff;
    
    memcpy(&body[i], sps, spsnalsize);
    i +=  spsnalsize;
    
    /*pps*/
    body[i++] = 0x01;
    
    body[i++] = ppsnalsize >> 8;
    body[i++] = (ppsnalsize) & 0xff;
    
    memcpy(&body[i], pps, ppsnalsize);
    i +=  ppsnalsize;
    
    printf("spscnt: %d \n", spscnt);
    printf("ppscnt: %d \n", ppscnt);
    printf("spsnalsize: %d \n", spsnalsize);
    printf("ppsnalsize: %d \n", ppsnalsize);
    printf("sps[1]: %d \n", sps[1]);
    printf("sps[2]: %d \n", sps[2]);
    printf("sps[3]: %d \n", sps[3]);
    
    packet->m_packetType = RTMP_PACKET_TYPE_VIDEO;
    packet->m_nBodySize = i;
    packet->m_nChannel = 0x06;
    packet->m_nTimeStamp = 0;
    packet->m_hasAbsTimestamp = 0;
    packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet->m_nInfoField2 = rtmp->m_stream_id;
    
    /*调用发送接口*/
    int rec = RTMP_SendPacket(rtmp,packet,TRUE);
    if (rec) {
        printf("send sps and pps \n");
    }
    free(packet);
}
void send_rtmp_video(unsigned char *buf, int len, double timestamp)
{
    int type;
    long timeoffset;
    RTMPPacket * packet;
    unsigned char * body;
    
    //timeoffset = [[NSDate new] timeIntervalSince1970]-lastTime;  /*start_time为开始直播时的时间戳*/
    
    //printf("timeoffset: %ld", timeoffset);
    
    /*去掉帧界定符*/
    if (buf[2] == 0x00) { /*00 00 00 01*/
        buf += 4;
        len -= 4;
    } else if (buf[2] == 0x01){ /*00 00 01*/
        buf += 3;
        len -= 3;
    }
    type = buf[0]&0x1f;
    
    packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE+len+9);
    memset(packet,0,RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
    packet->m_nBodySize = len + 9;
    
    /*send video packet*/
    body = (unsigned char *)packet->m_body;
    memset(body,0,len+9);
    
    /*key frame*/
    body[0] = 0x27;
    if (type == 5) {
        body[0] = 0x17;
    }
    
    body[1] = 0x01;   /*nal unit*/
    body[2] = 0x00;
    body[3] = 0x00;
    body[4] = 0x00;
    
    body[5] = (len >> 24);
    body[6] = (len >> 16);
    body[7] = (len >>  8);
    body[8] = (len ) & 0xff;
    
    /*copy data*/
    memcpy(&body[9],buf,len);
    
    packet->m_hasAbsTimestamp = 1;
    packet->m_packetType = RTMP_PACKET_TYPE_VIDEO;
    packet->m_nInfoField2 = rtmp->m_stream_id;
    packet->m_nChannel = 0x06;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet->m_nTimeStamp = lastTime;
    
    /*调用发送接口*/
    RTMP_SendPacket(rtmp, packet, TRUE);
    free(packet);
}
void video_stop(void *cls)
{
    pthread_mutex_lock(&write_mutex);
    if (hMp4file)
    {
        MP4Close(hMp4file,0);
        hMp4file = NULL;
    }
    pthread_mutex_unlock(&write_mutex);
    
    pthread_mutex_destroy(&write_mutex);
    mp4_init_flag = 0;
    
    
#if SAVE_264_ENABLE
    fclose(m_handle);
#endif
    
    printf("=====video_stop========\n");
    
    //kdd
    [[CSScreenRecorder sharedCSScreenRecorder].delegate screenRecorderDidStopRecording:[CSScreenRecorder sharedCSScreenRecorder]];
    
}

void audio_open(void *cls, int bits, int channels, int samplerate, int isaudio)
{
    
    
}


void audio_setvolume(void *cls,int volume)
{
    printf("=====audio====%d====\n",volume);
}


void audio_process(void *cls,const void *buffer, int buflen, double timestamp, uint32_t seqnum)
{
    while (!mp4_init_flag)
    {
        usleep(1000);
    }
    
    pthread_mutex_lock(&write_mutex);
    if (hMp4file)
    {
        MP4WriteSample(hMp4file, m_audioId, buffer, buflen, MP4_INVALID_DURATION, 0, 1);
    }
    pthread_mutex_unlock(&write_mutex);
    //printf("=====audio====%f====\n",timestamp);
}


void audio_stop(void *cls)
{
    printf("=====audio_stop========\n");
}






- (void)startRecordingScreen
{
    
    [self _setupAudio];
    
    
    
    airplay_callbacks_t ao;
    memset(&ao,0,sizeof(airplay_callbacks_t));
    ao.cls                          = (__bridge void *)self;
    
    
    
    ao.AirPlayMirroring_Play     = video_open;
    ao.AirPlayMirroring_Process  = video_process;
    ao.AirPlayMirroring_Stop     = video_stop;
    
    ao.AirPlayAudio_Init         = audio_open;
    ao.AirPlayAudio_SetVolume    = audio_setvolume;
    ao.AirPlayAudio_Process      = audio_process;
    ao.AirPlayAudio_destroy      = audio_stop;
    
    
    
    
    int ret = XinDawn_StartMediaServer("Xindawn",1920, 1080, 60, 47000,7100,"000000000", &ao);
    
    
    printf("=====ret=%d========\n",ret);
    
    
}

- (void)stopRecordingScreen
{
    
    [self _finishEncoding];
    
    
    XinDawn_StopMediaServer();
    
    
    [self mergeAudio];
   
    

}






- (void)_setupAudio
{
    // Setup to be able to record global sounds (preexisting app sounds)
   
    NSError *sessionError = nil;

    
    [[AVAudioSession sharedInstance] setActive:YES error:&sessionError];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&sessionError];
    
    
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeDefault error:nil];
    
    
     [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    
    self.audioSampleRate  = @44100;
    self.numberOfAudioChannels = @2;
    
    // Set the number of audio channels, using defaults if necessary.
    NSNumber *audioChannels = (self.numberOfAudioChannels ? self.numberOfAudioChannels : @2);
    NSNumber *sampleRate    = (self.audioSampleRate       ? self.audioSampleRate       : @44100.f);
    
    NSDictionary *audioSettings = @{
                                    AVNumberOfChannelsKey : (audioChannels ? audioChannels : @2),
                                    AVSampleRateKey       : (sampleRate    ? sampleRate    : @44100.0f)
                                    };
    
    
    // Initialize the audio recorder
    // Set output path of the audio file
    NSError *error = nil;

    audioOutPath = [NSString stringWithFormat:@"%@audio.caf",  NSTemporaryDirectory()];
     _audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:audioOutPath] settings:audioSettings error:&error];
    if (error && [self.delegate respondsToSelector:@selector(screenRecorder:audioRecorderSetupFailedWithError:)]) {
        // Let the delegate know that shit has happened.
        [self.delegate screenRecorder:self audioRecorderSetupFailedWithError:error];
        
            //kdd      [_audioRecorder release];
        _audioRecorder = nil;
        
        return;
    }
    
   // [_audioRecorder setDelegate:self];
   // [_audioRecorder prepareToRecord];
    
    // Start recording :P
  //  [_audioRecorder record];
}




- (void)mergeAudio {
    NSString *videoPath = fileName;
    NSString *audioPath = audioOutPath;
    
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    NSURL *audioURL = [NSURL fileURLWithPath:audioPath];
    
    NSError *error = nil;
    NSDictionary *options = nil;
    
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:options];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:options];
    
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        NSArray *assetArray = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        if ([assetArray count] > 0) {
            assetVideoTrack = assetArray[0];
        }
    }
    
   if ([[NSFileManager defaultManager] fileExistsAtPath:audioPath])
    {
        NSArray *assetArray = [audioAsset tracksWithMediaType:AVMediaTypeAudio];
        if ([assetArray count] > 0) {
            assetAudioTrack = assetArray[0];
        }
    }
    
    AVMutableComposition *mixComposition = [AVMutableComposition composition];
    
    if (assetVideoTrack != nil) {
        AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:assetVideoTrack atTime:kCMTimeZero error:&error];
        if (assetAudioTrack != nil) {
            [compositionVideoTrack scaleTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) toDuration:audioAsset.duration];
        }
    }
    
    if (assetAudioTrack != nil) {
        AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) ofTrack:assetAudioTrack atTime:kCMTimeZero error:&error];
    }
    
  
    
    exportFileName = [NSString stringWithFormat:@"%@.mp4", _videoName];
    NSURL *exportURL = [NSURL fileURLWithPath:exportFileName];
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    [exportSession setOutputFileType:AVFileTypeMPEG4];
    [exportSession setOutputURL:exportURL];
    [exportSession setShouldOptimizeForNetworkUse:NO];
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                
#if 1//kdd
                //kdd
                [[NSNotificationCenter defaultCenter] postNotificationName:kFileAddedNotification object:nil];
                [self removeTemporaryFiles];
#endif
                
                break;
                
            case AVAssetExportSessionStatusFailed:
                NSLog(@"Failed: %@", exportSession.error);
                break;
                
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Canceled: %@", exportSession.error);
                break;
                
            default:
                break;
        }
    }];
}


#pragma mark - Encoding


- (void)_finishEncoding
{
    
    // Stop the audio recording
    [_audioRecorder stop];
    _audioRecorder = nil;
    
    [self addAudioTrackToRecording];
    
    //NSError *sessionError = nil;
    //[[AVAudioSession sharedInstance] setActive:NO error:&sessionError];
    

  
}

- (void)addAudioTrackToRecording {
    
    
    [self.delegate screenRecorderDidStopRecording:self];
}



- (void)removeTemporaryFiles {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *oldVideoPath = fileName;
    NSString *oldaudioPath = audioOutPath;
    
    if ([defaultManager fileExistsAtPath:oldaudioPath]) {
        NSError *error = nil;
        [defaultManager removeItemAtPath:oldaudioPath error:&error];
    }
    if ([defaultManager fileExistsAtPath:oldVideoPath]) {
        NSError *error = nil;
        [defaultManager removeItemAtPath:oldVideoPath error:&error];
    }
}

char * put_byte( char *output, uint8_t nVal )
{
    output[0] = nVal;
    return output+1;
}
char * put_be16(char *output, uint16_t nVal )
{
    output[1] = nVal & 0xff;
    output[0] = nVal >> 8;
    return output+2;
}

char * put_be24(char *output,uint32_t nVal )
{
    output[2] = nVal & 0xff;
    output[1] = nVal >> 8;
    output[0] = nVal >> 16;
    return output+3;
}

char * put_be32(char *output, uint32_t nVal )
{
    output[3] = nVal & 0xff;
    output[2] = nVal >> 8;
    output[1] = nVal >> 16;
    output[0] = nVal >> 24;
    return output+4;
}

//char *  put_be64( char *output, uint64_t nVal )
//{
//    output=put_be32( output, nVal >> 32 );
//    output=put_be32( output, nVal );
//    return output;
//}

char * put_amf_string( char *c, const char *str )
{
    uint16_t len = strlen( str );
    c=put_be16( c, len );
    memcpy(c,str,len);
    return c+len;
}


char * put_amf_double( char *c, double d )
{
    *c++ = AMF_NUMBER;
    {
        unsigned char *ci, *co;
        ci = (unsigned char *)&d;
        co = (unsigned char *)c;
        co[0] = ci[7];
        co[1] = ci[6];
        co[2] = ci[5];
        co[3] = ci[4];
        co[4] = ci[3];
        co[5] = ci[2];
        co[6] = ci[1];
        co[7] = ci[0];
    }
    return c+8;
}
@end
