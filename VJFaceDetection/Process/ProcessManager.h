//
//  ProcessManager.h
//  VJFaceDetection
//
//  Created by Vincent·Ge on 2018/6/19.
//  Copyright © 2018年 Filelife. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <GPUImage.h>
@interface ProcessManager : NSObject
+ (CGRect)faceRect:(CIFeature*)feature;

- (NSArray<CIFeature *> *)processFaceFeaturesWithPicBuffer:(CMSampleBufferRef)sampleBuffer
                                            cameraPosition:(AVCaptureDevicePosition)currentCameraPosition;
@end
