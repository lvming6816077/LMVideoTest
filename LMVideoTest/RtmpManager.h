//
//  RtmpManager.h
//  LMVideoTest
//
//  Created by lvming on 16/5/23.
//  Copyright © 2016年 lvming. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "rtmp.h"

@interface RtmpManager : NSObject
{
    RTMP* rtmp;
    double start_time;
    dispatch_queue_t workQueue;//异步Queue
}

@property (nonatomic,copy) NSString* rtmpUrl;//rtmp服务器流地址

- (RTMP*)getCurrentRtmp;

/**
 *  获取单例
 *
 *  @return 单例
 */
+ (instancetype)getInstance;

/**
 *  开始连接服务器
 *
 *  @return 是否成功
 */
- (BOOL)startRtmpConnect;

/**
 *  停止连接服务器
 *
 *  @return 是否成功
 */
- (BOOL)stopRtmpConnect;

/**
 *  sps and pps帧
 *
 *  @param sps     第一帧
 *  @param sps_len 第一帧长度
 *  @param pps     第二帧
 *  @param pps_len 第二帧长度
 */
- (void)send_video_sps_pps:(unsigned char*)sps andSpsLength:(int)sps_len andPPs:(unsigned char*)pps andPPsLength:(uint32_t)pps_len;

/**
 *  发送视频
 *
 *  @param buf 关键帧或者非关键帧
 *  @param len 长度
 */
- (void)send_rtmp_video:(unsigned char*)buf andLength:(uint32_t)len;

/**
 *  发送音频
 *
 *  @param buf 音频数据（aac）
 *  @param len 音频长度
 */
- (void)send_rtmp_audio:(unsigned char*)buf andLength:(uint32_t)len;

/**
 *  发送音频spec
 *
 *  @param spec_buf spec数据
 *  @param spec_len spec长度
 */
- (void)send_rtmp_audio_spec:(unsigned char *)spec_buf andLength:(uint32_t) spec_len;

@end
