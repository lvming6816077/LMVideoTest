//
//  ViewController.m
//  VideoTest
//
//  Created by lvming on 16/5/19.
//  Copyright © 2016年 lvming. All rights reserved.
//

#import "ViewController.h"
#import "X264Manager.h"
#import "RtmpManager.h"
#import "AudioManager.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *preViewLayer;
@property(nonatomic,strong) UIButton *btn;
@end

@implementation ViewController{
    AVCaptureConnection *_videoConnection;
    AVCaptureConnection *_audioConnection;

    RtmpManager *_rtmpManager;
    
    BOOL _runningFlag;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 推流
    _rtmpManager = [RtmpManager getInstance];
    _rtmpManager.rtmpUrl = @"rtmp://192.168.1.104:1935/hls/mystream";
    [_rtmpManager startRtmpConnect];
    
    //音频
    [[AudioManager getInstance] initRecording];
    
    
    //视频
    [[X264Manager getInstance] initForX264WithWidth:480 height:640];
    

    [self setupCaptureSession];
    
    [self initUI];
    
    
}

- (void)setupCaptureSession
{
    NSError *error = nil;
    self.session = [[AVCaptureSession alloc] init];
    
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        NSLog(@"error input:%@", error.description);
    }
    if ([_session canAddInput:input]) {
        [self.session addInput:input];
    }
    
    AVCaptureVideoDataOutput *outPut = [[AVCaptureVideoDataOutput alloc] init];
    
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    
    
    [outPut setSampleBufferDelegate:self queue:queue];
    
    
    outPut.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    
    
    //表示丢弃延迟的帧
    outPut.alwaysDiscardsLateVideoFrames = YES;
    
    //开启session 执行录制
    [self startRunning];
    
    
    if ([_session canAddOutput:outPut]) {
        [self.session addOutput:outPut];
    }
    
    [self setSession:self.session];
    
    
    _videoConnection = [outPut connectionWithMediaType:AVMediaTypeVideo];
    
    _videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    

    
    // 设置视频预览界面
    self.preViewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.preViewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [self.view.layer addSublayer:_preViewLayer];
    
    
    
}
-(void) initUI {
    _runningFlag = YES;
    self.btn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btn.frame = CGRectMake(10, 510, 50, 50);
    [self.btn setTitle:@"暂停" forState:UIControlStateNormal];
    [self.btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.btn addTarget:self action:@selector(toggleRunning:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btn];
}
-(void) toggleRunning:(UIGestureRecognizer*)reg{
    if (_runningFlag) {
        [self stopRunning];
        [self.btn setTitle:@"开始" forState:UIControlStateNormal];
    } else {
        [self startRunning];
        [self.btn setTitle:@"暂停" forState:UIControlStateNormal];
    }
    
    _runningFlag = !_runningFlag;
}
- (void)startRunning
{
    NSLog(@"startRunning");
    [self.session startRunning];

    [[AudioManager getInstance] startRecording];
    
}

- (void)stopRunning
{
    NSLog(@"stopRunning");
    [self.session stopRunning];
    [[AudioManager getInstance] pauseRecording];
}

// 关键方法，捕获摄像头每一帧的画面并编码
-(void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    
    if (connection == _videoConnection) {
        
        [[X264Manager getInstance] encoderToH264:sampleBuffer];

    }
    
    if (connection == _audioConnection) {
        NSLog(@"yy");
    }
}

// 选择是前摄像头还是后摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}


- (AVCaptureDevice *)frontCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *)backCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
