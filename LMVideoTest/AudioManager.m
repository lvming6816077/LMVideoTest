//
//  AudioManager.m
//  LMVideoTest
//
//  Created by lvming on 16/5/23.
//  Copyright © 2016年 lvming. All rights reserved.
//

#import "AudioManager.h"
#import "RtmpManager.h"

#define SAMPLERATE      44100
#define NUMBERCHANNEL   2
#define BUFFERBYTESIZE  16000

@implementation AudioManager

static AudioManager* shareInstace = nil;
+ (instancetype)getInstance
{
    static dispatch_once_t instance;
    dispatch_once(&instance, ^{
        shareInstace = [[self alloc] init];
    });
    return shareInstace;
}

static void OnInputBufferCallback(void *inUserData,
                             AudioQueueRef inAQ,
                             AudioQueueBufferRef inBuffer,
                             const AudioTimeStamp *inStartTime,
                             UInt32 inNumPackets,
                             const AudioStreamPacketDescription *inPacketDesc)
{
    AudioManager * manager = (__bridge AudioManager*)inUserData;
    if (manager == NULL || manager->recording == NO)
    {
        return;
    }
    //编码
    int nRet = faacEncEncode(manager->audioEncoder, inBuffer->mAudioData, manager->inputSamples, manager->outputBuffer, manager->maxOutputBytes);
    
    if (nRet > 0)
    {
        [[RtmpManager getInstance] send_rtmp_audio:manager->outputBuffer andLength:nRet];
//        fwrite(manager->outputBuffer, 1, nRet, manager->fp);
        
    }
    AudioQueueEnqueueBuffer(manager->queueRef, inBuffer, 0, NULL);
}

static void OnIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    AudioManager * manager = (__bridge AudioManager*)inUserData;
    if (manager == NULL)
    {
        return;
    }
    
    UInt32 size = sizeof(manager->running);
    AudioQueueGetProperty(manager->queueRef, kAudioQueueProperty_IsRunning, &manager->running, &size);
    
    if (!manager->running)
    {
        [manager stopRecording];
    }
}

- (void)initRecording
{
    [self openEncoder];
    
//    [self initForFilePath];
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error: nil];
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride);
    [audioSession setActive:YES error: nil];
    
    basicDescription.mFormatID = kAudioFormatLinearPCM;
    basicDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    basicDescription.mSampleRate = SAMPLERATE;
    basicDescription.mChannelsPerFrame = NUMBERCHANNEL;
    basicDescription.mBitsPerChannel = 16;
    basicDescription.mBytesPerPacket = self->basicDescription.mBytesPerFrame = (basicDescription.mBitsPerChannel / 8) * basicDescription.mChannelsPerFrame;
    basicDescription.mFramesPerPacket = 1;
    
    OSStatus status = AudioQueueNewInput(&basicDescription, OnInputBufferCallback, (__bridge void*)self, CFRunLoopGetMain(), kCFRunLoopDefaultMode, 0, &queueRef);
    if (status)
    {
        NSLog(@"Could not establish new queue");
        return;
    }
    
    AudioQueueSetParameter(queueRef, kAudioQueueParam_Volume, 1.0f);
    for(int i = 0; i != kNumberOfRecordBuffers; ++i)
    {
        AudioQueueAllocateBuffer(queueRef, (UInt32)maxInputBytes, &(buffer[i]));
        AudioQueueEnqueueBuffer(queueRef, buffer[i], 0, NULL);
    }
    
     //AudioQueueAddPropertyListener(self->queueRef, kAudioQueueProperty_IsRunning, OnIsRunningCallback, (__bridge void*)self);
    
    UInt32 trueValue = true;
    AudioQueueSetProperty(queueRef, kAudioQueueProperty_EnableLevelMetering, &trueValue, sizeof(trueValue));
    
}

- (void)startRecording
{
    OSStatus rst = AudioQueueStart(queueRef, NULL);
    
    if (rst != 0)
    {
        AudioQueueStart(queueRef, NULL);
    }
    recording = YES;
}

- (void)pauseRecording
{
    AudioQueuePause(queueRef);
    recording = NO;
}

- (void)stopRecording
{
    AudioQueueStop(queueRef, true);
    AudioQueueDispose(queueRef, false);
    queueRef = NULL;
    
    [self stopEncoder];
}


- (void)openEncoder
{
    audioEncoder = faacEncOpen(SAMPLERATE, NUMBERCHANNEL, &inputSamples, &maxOutputBytes);
    maxInputBytes = inputSamples*16/8;
    
    faacEncConfigurationPtr ptr = faacEncGetCurrentConfiguration(audioEncoder);
    
    // 设置配置参数
    ptr->inputFormat = FAAC_INPUT_16BIT;
    ptr->outputFormat = 1; ////输出是否包含ADTS头，默认1,如果要写文件本地播放则需要加ADTS头
    ptr->useTns = true; //时域噪音控制,大概就是消爆音
    ptr->useLfe = false;
    ptr->aacObjectType = LOW;//LC编码
    ptr->shortctl = SHORTCTL_NORMAL;
    ptr->quantqual = 50;
    ptr->bandWidth = 0;//频宽
    ptr->bitRate = 0;
    
    faacEncSetConfiguration(audioEncoder, ptr);
    
    printf("\ninputSamples:%ld maxInputBytes:%ld maxOutputBytes:%ld\n", inputSamples, maxInputBytes,maxOutputBytes);
    unsigned char *tmp;
    unsigned long spec_len;
    faacEncGetDecoderSpecificInfo(audioEncoder, &tmp, &spec_len);
    [[RtmpManager getInstance] send_rtmp_audio_spec:tmp andLength:(UInt32)spec_len];
    //如果现在释放，可能还没发送就释放了，导致发送的数据不对，因为发送是异步队列发送的。
    //如果free的时候同时设置为NULL，那么再引用数据的时候就会报错也能定位到问题了。
    //所以以后free的时候也要设置为NULL。
    //    free(tmp);
    //    tmp = nil;
    
    outputBuffer = malloc(maxOutputBytes);
}


- (void)stopEncoder
{
    faacEncClose(audioEncoder);
}


- (void)initForFilePath
{
    char *path = [self GetFilePathByfileName:"IOSCamDemo.aac"];
    NSLog(@"%s",path);
    fp = fopen(path,"wb");
}


- (char*)GetFilePathByfileName:(char*)filename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *strName = [NSString stringWithFormat:@"%s",filename];
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:strName];
    
    NSUInteger len = [writablePath length];
    
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    [writablePath getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}

@end
