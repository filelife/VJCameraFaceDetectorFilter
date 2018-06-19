//
//  GPUImageBeautifyFilter.h
//  VJFaceDetection
//
//  Created by Vincent·Ge on 2018/6/14.
//  Copyright © 2018年 Filelife. All rights reserved.

#import <GPUImage/GPUImage.h>

@class GPUImageCombinationFilter;

@interface GPUImageBeautifyFilter : GPUImageFilterGroup {
}
@property (nonatomic, strong)GPUImageBilateralFilter *bilateralFilter;
@property (nonatomic, strong)GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
@property (nonatomic, strong)GPUImageCombinationFilter *combinationFilter;
@property (nonatomic, strong)GPUImageHSBFilter *hsbFilter;
- (void)updateMask:(CGRect)mask;

@end
