//
//  GPUImageBeautifyFilter.m
//  VJFaceDetection
//
//  Created by Vincent·Ge on 2018/6/14.
//  Copyright © 2018年 Filelife. All rights reserved.
#import "GPUImageBeautifyFilter.h"

// Internal CombinationFilter(It should not be used outside)
@interface GPUImageCombinationFilter : GPUImageThreeInputFilter {
    GLint _smoothDegreeUniform;
    GLint _maskUniform;
}

@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) CGRect mask;

@end

NSString *const kGPUImageBeautifyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 varying highp vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 uniform mediump float smoothDegree;
 
 uniform lowp vec4 mask;
 
 void main() {
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    highp vec4 bilateral = texture2D(inputImageTexture, textureCoordinate);
    highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);
    highp vec4 origin = texture2D(inputImageTexture3,textureCoordinate3);
    highp vec4 smooth;
    lowp float r = origin.r;
    lowp float g = origin.g;
    lowp float b = origin.b;
    if (canny.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > b && (max(max(r, g), b) - min(min(r, g), b)) > 0.0588 && abs(r-g) > 0.0588) {
        smooth = (1.0 - smoothDegree) * (origin - bilateral) + bilateral;
    } else {
        smooth = origin;
    }
    smooth.r = log(1.0 + 0.5 * smooth.r)/log(1.2);
    smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
    smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
     
     if(gl_FragCoord.x < (mask.x + mask.z) && gl_FragCoord.y < (mask.y + mask.w) && gl_FragCoord.x > mask.x && gl_FragCoord.y > mask.y) {
         gl_FragColor = smooth;
     }else {
         gl_FragColor = origin;
     }
 }
);

@implementation GPUImageCombinationFilter

- (id)init {
    if (self = [super initWithFragmentShaderFromString:kGPUImageBeautifyFragmentShaderString]) {
        _smoothDegreeUniform = [filterProgram uniformIndex:@"smoothDegree"];
        _maskUniform = [filterProgram uniformIndex:@"mask"];
    }
    self.intensity = 0.8;
    return self;
}

- (void)setIntensity:(CGFloat)intensity {
    _intensity = intensity;
    [self setFloat:intensity forUniform:_smoothDegreeUniform program:filterProgram];
}

- (void)setMask:(CGRect)mask {
    _mask = mask;
    GPUVector4 maskVector4 = {mask.origin.x, mask.origin.y, mask.size.width, mask.size.height};
    [self setVec4:maskVector4 forUniform:_maskUniform program:filterProgram];
}

@end

@interface GPUImageBeautifyFilter()
@end

@implementation GPUImageBeautifyFilter

- (id)init {
    if (!(self = [super init])) {
        return nil;
    }
    
    
    // First pass: face smoothing filter
    self.bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    self.bilateralFilter.distanceNormalizationFactor = 4.0;
    [self addFilter:self.bilateralFilter];
    
    // Second pass: edge detection
    self.cannyEdgeFilter = [[GPUImageCannyEdgeDetectionFilter alloc] init];
    [self addFilter:self.cannyEdgeFilter];
    
    // Third pass: combination bilateral, edge detection and origin
    self.combinationFilter = [[GPUImageCombinationFilter alloc] init];
    [self addFilter:self.combinationFilter];
    
    // Adjust HSB
    self.hsbFilter = [[GPUImageHSBFilter alloc] init];
    [self.hsbFilter adjustBrightness:1.3];
    [self.hsbFilter adjustSaturation:1.1];
    
    
    [self.bilateralFilter addTarget:self.combinationFilter];
    [self.cannyEdgeFilter addTarget:self.combinationFilter];
    [self.combinationFilter addTarget:self.hsbFilter];
    
    self.initialFilters = [NSArray arrayWithObjects:self.bilateralFilter,self.cannyEdgeFilter,self.combinationFilter,nil];
    self.terminalFilter = self.hsbFilter;
    
    return self;
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates) {
            if (currentFilter == self.combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter == self.combinationFilter) {
            textureIndex = 2;
        }
        [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
    }
}

- (void)updateMask:(CGRect)mask {
    [self.combinationFilter setMask:mask];
}
@end
