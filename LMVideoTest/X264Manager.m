//
//  X264Manager.m
//  LMVideoTest
//
//  Created by lvming on 16/5/23.
//  Copyright © 2016年 lvming. All rights reserved.
//

#import "x264Manager.h"
#import "rtmpManager.h"


@implementation X264Manager

static X264Manager* _instance = nil;

+(X264Manager*)getInstance
{
    if(!_instance) {
        _instance = [[X264Manager alloc] init];
    }
    return _instance;
}
// 重要参数：

//  i_keyint_max 设置gop长度 单位：间隔帧数
//  m_bitRate 设置码率 单位：bps
//  i_fps_num 设置帧率 单位：fps

- (void)initForX264WithWidth:(int)width height:(int)height
{
    /* 开辟内存空间*/
    self->p264Param = malloc(sizeof(x264_param_t));//video params use for encoding
    self->p264Pic  = malloc(sizeof(x264_picture_t));//raw image data for storing image data
    memset(self->p264Pic,0,sizeof(x264_picture_t));//clear memory
    
    x264_param_default_preset(self->p264Param, "fast", "zerolatency");//set encoder params
    
    
    self->p264Param->i_width   = width;  //set frame width
    self->p264Param->i_height  = height;  //set frame height
    
    /*video 设置*/
    self->p264Param->i_threads = 1;/* encode multiple frames in parallel */
    self->p264Param->b_sliced_threads = 1;
    self->p264Param->i_level_idc = 30;/*编码复杂度*/  /*未知*/
    self->p264Param->analyse.intra = X264_ANALYSE_I4x4;/* 帧间分区*/ /*未知*/
    self->p264Param->analyse.inter = X264_ANALYSE_I4x4; /* 帧内分区 */ /*未知*/
    self->p264Param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_SPATIAL;/*时间空间队运动预测 */
    self->p264Param->analyse.i_weighted_pred = X264_WEIGHTP_NONE; //p帧加权预测 /*未知*/
    self->p264Param->analyse.i_subpel_refine = 4; /* 亚像素运动估计质量 */
    self->p264Param->i_bframe_adaptive = X264_B_ADAPT_FAST;
    self->p264Param->i_bframe_pyramid = X264_B_PYRAMID_NONE; /*允许部分B为参考帧,可选值为0，1，2 */
    self->p264Param->b_intra_refresh = 0; //用周期帧内刷新替代IDR
    self->p264Param->analyse.i_trellis = 1; /* Trellis量化，对每个8x8的块寻找合适的量化值，需要CABAC，默认0 0：关闭1：只在最后编码时使用2：一直使用*/
    self->p264Param->analyse.b_chroma_me = 1;/* 亚像素色度运动估计和P帧的模式选择 */
    self->p264Param->b_interlaced = 0;/* 隔行扫描 */
    self->p264Param->analyse.b_transform_8x8 = 1;/* 帧间分区*/
    self->p264Param->rc.f_qcompress = 0;/* 0.0 => cbr, 1.0 => constant qp */
    self->p264Param->i_frame_reference = 4;/*参考帧的最大帧数。*/
    self->p264Param->i_bframe = 0; /*两个参考帧之间的B帧数目*/
    self->p264Param->analyse.i_me_range = 16;/* 整像素运动估计搜索范围 (from predicted mv) */
    self->p264Param->analyse.i_me_method = X264_ME_DIA;/* 运动估计算法 (X264_ME_*)*/
    self->p264Param->rc.i_lookahead = 0;
    self->p264Param->i_keyint_max = 30;/* GOP 在此间隔设置IDR关键帧(每过多少帧设置一个IDR帧) */
    self->p264Param->b_repeat_headers = 1; //关键帧前面是否放sps跟pps帧
    self->p264Param->i_scenecut_threshold = 40;/*如何积极地插入额外的I帧 */
    self->p264Param->rc.i_qp_min = 10;//关键帧最小间隔
    self->p264Param->rc.i_qp_max = 50; //关键帧最大间隔
    self->p264Param->rc.i_qp_constant = 20;
    
//    self->p264Param－>
    self->p264Param->i_fps_num = 15;/*帧率*/
    self->p264Param->i_fps_den = 1;/*用两个整型的数的比值，来表示帧率*/
    self->p264Param->b_annexb = 1;//如果设置了该项，则在每个NAL单元前加一个四字节的前缀符
    self->p264Param->b_cabac = 0;
    self->p264Param->rc.i_rc_method = X264_RC_ABR;//参数i_rc_method表示码率控制，CQP(恒定质量)，CRF(恒定码率)，ABR(平均码率)
    int m_bitRate = 96000;
    self->p264Param->rc.i_bitrate = m_bitRate / 1000; // 码率(比特率), x264使用的bitrate需要/1000。
    p264Param->rc.i_vbv_max_bitrate=(int)((m_bitRate * 1.2) / 1000) ; // 平均码率模式下，最大瞬时码率，默认0(与-B设置相同)
    
    x264_param_apply_profile(self->p264Param,"baseline");
    if((self->p264Handle =x264_encoder_open(self->p264Param)) == NULL)
    {
        fprintf(stderr, "x264_encoder_open failed/n" );
        return ;
    }
    x264_picture_alloc(self->p264Pic,X264_CSP_I420,self->p264Param->i_width,self->p264Param->i_height);
    self->p264Pic->i_type = X264_TYPE_AUTO;
    
}





- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if(CVPixelBufferLockBaseAddress(pixelBuffer, 0) == kCVReturnSuccess)
    {
        int i264Nal = 0;
        //输出的图片
        x264_picture_t pic_out;
        uint32_t sps_len = 0;
        uint32_t pps_len = 0;

        
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,0);
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,1);
        
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        
        size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer,0);
        size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer,1);
        
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/ 2);//buffer to store YUV with layout YYYYYYYYUUVV
        
        
        /* convert NV12 data to YUV420*/
        UInt8 *pY = bufferPtr ;
        UInt8 *pUV = bufferPtr1;
        UInt8 *pU = yuv420_data + width * height;
        UInt8 *pV = pU + width * height / 4;
        for(int i = 0; i < height; i++)
        {
            memcpy(yuv420_data + i * width, pY + i * bytesrow0, width);
        }
        for(int j = 0;j < height/2; j++)
        {
            for(int i = 0; i < width/2; i++)
            {
                *(pU++) = pUV[i<<1];
                *(pV++) = pUV[(i<<1) + 1];
            }
            pUV += bytesrow1;
        }
        
        p264Pic->img.i_plane = 3;
        p264Pic->img.plane[0] = yuv420_data; // yuv420_data <==> pInFrame
        p264Pic->img.plane[1] = p264Pic->img.plane[0] + p264Param->i_width * p264Param->i_height;
        p264Pic->img.plane[2] = p264Pic->img.plane[1] + (p264Param->i_width * p264Param->i_height / 4);
        p264Pic->img.i_stride[0] = p264Param->i_width;
        p264Pic->img.i_stride[1] = p264Param->i_width / 2;
        p264Pic->img.i_stride[2] = p264Param->i_width / 2;
        
        int i_frame_size = x264_encoder_encode(p264Handle, &p264Nal, &i264Nal,p264Pic ,&pic_out);
        if(i_frame_size  < 0)//帧总数
        {
            fprintf(stderr, "x264_encoder_encode failed/n" );
            return;
        }
        free(yuv420_data);
        yuv420_data = NULL;
        
        if (i264Nal > 0)//解析出帧来了
        {
            for (int i = 0,last = 0; i < i264Nal; i++)
            {


                if (self->p264Nal[i].i_type == NAL_SPS)
                {
                    sps_len = self->p264Nal[i].i_payload - 4;
                    memcpy(sps,self->p264Nal[i].p_payload + 4,sps_len);
                }
                else if (self->p264Nal[i].i_type == NAL_PPS)
                {
                    pps_len = self->p264Nal[i].i_payload - 4;
                    memcpy(pps,self->p264Nal[i].p_payload + 4,pps_len);
                    [[RtmpManager getInstance] send_video_sps_pps:sps andSpsLength:sps_len andPPs:pps andPPsLength:pps_len];/*发送sps pps*/
                }
                else
                {
                    [[RtmpManager getInstance] send_rtmp_video:self->p264Nal[i].p_payload andLength:i_frame_size - last];/*发送普通帧*/
                    break;
                }
                last += self->p264Nal[i].i_payload;
            }
            
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)stopEncoding
{
    fclose(self->fp);
}
@end
