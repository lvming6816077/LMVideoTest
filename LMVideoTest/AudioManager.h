//
//  AudioManager.h
//  LMVideoTest
//
//  Created by lvming on 16/5/23.
//  Copyright © 2016年 lvming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "faac.h"

#define kNumberOfRecordBuffers 3
#define Bitrate 200//码率

@interface AudioManager : NSObject
{
    AudioStreamBasicDescription basicDescription;
    AudioQueueRef               queueRef;
    AudioQueueBufferRef         buffer[3];
    
    BOOL                        recording;
    BOOL                        running;
    
    faacEncHandle               audioEncoder;
    unsigned long               inputSamples;
    unsigned long               maxOutputBytes;
    unsigned long               maxInputBytes;
    unsigned char*              outputBuffer;
    
    FILE *fp;
}

+ (instancetype)getInstance;

/**
 *  初始化编码
 */
- (void)initRecording;

/**
 *  开始录制
 */
- (void)startRecording;

/**
 *  暂停录制
 */
- (void)pauseRecording;

/**
 *  结束录制
 */
- (void)stopRecording;

@end
