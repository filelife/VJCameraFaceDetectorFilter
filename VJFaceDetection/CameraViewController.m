//
//  CameraViewController.m
//  MBBeautifyFace
//
//  Created by Vincent·Ge on 2018/5/18.
//  Copyright © 2018年 Filelife. All rights reserved.
//
#import <Vision/Vision.h>
#import "CameraViewController.h"
#import <CoreImage/CoreImage.h>
#import <GPUImage.h>
#import "GPUImageBeautifyFilter.h"
#import "ProcessManager.h"
@interface CameraViewController ()<GPUImageVideoCameraDelegate>
@property (nonatomic, strong) GPUImageView *videoView;
@property (nonatomic, strong) GPUImageVideoCamera *camera;
@property (nonatomic, strong) GPUImageFilterPipeline * pipline;
@property (nonatomic, strong) GPUImageBeautifyFilter * beautyFilter;
@property (nonatomic, strong) ProcessManager * processManager;
@end

@implementation CameraViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadFilter];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startCamera];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self stopCamera];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Getter
- (GPUImageView *)videoView {
    if (!_videoView) {
        _videoView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [self.view addSubview:_videoView];
    }
    return _videoView;
}

- (GPUImageVideoCamera *)camera {
    if (!_camera) {
        _camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionBack];
        _camera.outputImageOrientation = UIInterfaceOrientationPortrait;  
        _camera.horizontallyMirrorFrontFacingCamera = YES;
        [_camera addAudioInputsAndOutputs];
        _camera.delegate = self;  //最关键的一步，通过代理方法，获取视频传过来的每一帧的图像。
    }
    return _camera;
}

#pragma mark - Load
- (void)loadFilter {
    NSMutableArray * filters = [NSMutableArray array];
    self.beautyFilter = [[GPUImageBeautifyFilter alloc]init];
    [filters addObject:self.beautyFilter];
    self.pipline = [[GPUImageFilterPipeline alloc]initWithOrderedFilters:filters
                                                                   input:self.camera
                                                                  output:self.videoView];
    self.processManager = [[ProcessManager alloc]init];
}

- (void)startCamera {
    [self.camera startCameraCapture];
}

- (void)stopCamera {
    [self.camera stopCameraCapture];
}

#pragma mark - GPUImageVideoCameraDelegate
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMSampleBufferRef picCopy;// 避免内存问题产生，此处Copy一份Buffer用作处理；
    CMSampleBufferCreateCopy(CFAllocatorGetDefault(), sampleBuffer, &picCopy);
    [self processWithSampleBuffer:(__bridge CMSampleBufferRef)(CFBridgingRelease(picCopy))];
}

#pragma mark - Face Detection
- (void)processWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NSArray * faceFeatures = [self.processManager processFaceFeaturesWithPicBuffer:sampleBuffer
                                                                    cameraPosition:self.camera.cameraPosition];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setFaceRectWithFilter:faceFeatures];
    });
    
}

- (void)setFaceRectWithFilter:(NSArray*)featureArray {
    if(featureArray.count == 0) {
        [self removeFaceMask];
        return;
    }
    for (CIFeature *feature in featureArray) {
        [self updateFaceMask:[ProcessManager faceRect:feature]];
    }
}

- (void)updateFaceMask:(CGRect)faceMaskRect {
    [self.beautyFilter updateMask:faceMaskRect];
}

- (void)removeFaceMask {
    [self.beautyFilter updateMask:CGRectZero];
}
@end
