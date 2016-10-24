//
//  X264Manager.h
//  LMVideoTest
//
//  Created by lvming on 16/5/23.
//  Copyright © 2016年 lvming. All rights reserved.
//


#import <Foundation/Foundation.h>
#include "x264.h"
#import <CoreMedia/CoreMedia.h>

@interface X264Manager : NSObject {
    x264_param_t * p264Param;
    x264_picture_t * p264Pic;
    x264_t *p264Handle;
    x264_nal_t  *p264Nal;
    FILE *fp;
    unsigned char sps[30];
    unsigned char pps[10];
}

- (void)initForX264WithWidth:(int)width height:(int)height;




- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer;

+(X264Manager*)getInstance;

- (void)stopEncoding;

@end
