//
//  ProcessManager.m
//  VJFaceDetection
//
//  Created by Vincent·Ge on 2018/6/19.
//  Copyright © 2018年 Filelife. All rights reserved.
//

#import "ProcessManager.h"
#import "GPUImageBeautifyFilter.h"

// Options that can be used with -[CIDetector featuresInImage:options:]

/* The value for this key is an integer NSNumber from 1..8 such as that found in kCGImagePropertyOrientation.  If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */

typedef NS_ENUM(NSInteger , PHOTOS_EXIF_ENUM) {
    PHOTOS_EXIF_0ROW_TOP_0COL_LEFT          = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
    PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT         = 2, //   2  =  0th row is at the top, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
    PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
    PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
};

@interface ProcessManager()
@property (nonatomic, strong) CIDetector *faceDetector;

@end

@implementation ProcessManager

- (instancetype)init {
    self = [super init];
    [self loadFaceDetector];
    return self;
}

- (void)loadFaceDetector {
    NSDictionary *detectorOptions = @{CIDetectorAccuracy:CIDetectorAccuracyLow,
                                      CIDetectorTracking:@(YES)};
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}

- (NSArray<CIFeature *> *)processFaceFeaturesWithPicBuffer:(CMSampleBufferRef)sampleBuffer
                                            cameraPosition:(AVCaptureDevicePosition)currentCameraPosition {
    return [ProcessManager processFaceFeaturesWithPicBuffer:sampleBuffer
                                               faceDetector:self.faceDetector
                                             cameraPosition:currentCameraPosition];
}

#pragma mark - Category Function
+ (CGRect)faceRect:(CIFeature*)feature {
    CGRect faceRect = feature.bounds;
    CGFloat temp = faceRect.size.width;
    temp = faceRect.origin.x;
    faceRect.origin.x = faceRect.origin.y;
    faceRect.origin.y = temp;
    return faceRect;
}

+ (NSArray<CIFeature *> *)processFaceFeaturesWithPicBuffer:(CMSampleBufferRef)sampleBuffer
                                              faceDetector:(CIDetector *)faceDetector
                                            cameraPosition:(AVCaptureDevicePosition)currentCameraPosition {
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    
    //从帧中获取到的图片相对镜头下看到的会向左旋转90度，所以后续坐标的转换要注意。
    CIImage *convertedImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    
    if (attachments) {
        CFRelease(attachments);
    }
    
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;

    BOOL isUsingFrontFacingCamera = currentCameraPosition != AVCaptureDevicePositionBack;
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:
            if (isUsingFrontFacingCamera) {
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            }else {
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            }
            
            break;
        case UIDeviceOrientationLandscapeRight:
            if (isUsingFrontFacingCamera) {
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            }else {
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            }
            break;
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP; //值为6。确定初始化原点坐标的位置，坐标原点为右上。其中横的为y，竖的为x，表示真实想要显示图片需要顺时针旋转90度
            break;
    }
    
    //exifOrientation的值用于确定图片的方向
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    return [faceDetector featuresInImage:convertedImage options:imageOptions];
}
@end
