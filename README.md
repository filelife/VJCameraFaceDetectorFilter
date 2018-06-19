## 简述
### GPUImage+CIDetector

GPUImage作为目前各大美颜类AppiOS端的主要的相机框架，具有良好的扩展性与定制性。常见实时面部贴图功能，都可以基于GPUImage+人脸识别库来进行完成。 但是在不具高效的有人脸边缘检测库的时候，个人开发者主要可以采用的是苹果爸爸提供给的CoreImage库。Ps：其实CoreImage也不是特别好用，因为对人脸边缘的检测还是有些不足，iPhoneX+Vision Framework）。  

本仓库完成的效果如下图，对实时采集画面中的人脸进行跟踪并且进行局部滤镜渲染。
![1529406072280.gif](https://upload-images.jianshu.io/upload_images/1647887-901a78038daede7c.gif?imageMogr2/auto-orient/strip)

#### GPUImage 
鉴于部分开发内容需要用到GPUImage基础的滤镜功能，如果没有基础可以移步：
[GPUImage图像处理](https://www.jianshu.com/p/f19830a56a23)  
本文中，我们会使用GPUImageVideoCamera来进行实时采集，使用GPUImageView作为预览view展示效果。

#### CoreImage
CoreImage在本次使用中，主要用了他的CIDetector类来检测人脸特征。其处理后的产物，主要是CIFeature，其中就包含我们最关注的人脸数据的bounds。

## GPUImage的滤镜视频实时采集

导入GPUImage库
```
pod 'GPUImage'
```
工程Targets->Info->Custom iOS Target Properties中别忘记配置权限：
```
Privacy - Microphone Usage Description
Privacy - Camera Usage Description
```

#### 创建相机
GPUImage提供的GPUImageVideoCamera类，为我们封装了一个可以录像相机，也就是视频输入设备。通过这个类我们可以简单配置相机的摄像头、采集分辨率。如下的是简单的创建方法：
```
- (GPUImageVideoCamera *)camera {
if (!_camera) {
_camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
_camera.outputImageOrientation = UIInterfaceOrientationPortrait;  
_camera.horizontallyMirrorFrontFacingCamera = YES;
[_camera addAudioInputsAndOutputs];
_camera.delegate = self;  //最关键的一步，通过代理方法，获取视频传过来的每一帧的图像。
}
return _camera;
}
```
#### 创建预览View
相机采集到视频后，可以直接输出展示在这个view上，适当布局就可以满足我们的预览需求了。
```
- (GPUImageView *)videoView {
if (!_videoView) {
_videoView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
[self.view addSubview:_videoView];
}
return _videoView;
}
```

#### 创建滤镜
由于一般的滤镜，都会有多种效果叠加的需求，所以此处后续了会用Pipline管道复合滤镜的方案，让后续大家在拓展的时候，可以支持多种滤镜叠加。此处只需要把做好的滤镜添加到数组中即可。
```
NSMutableArray * filters = [NSMutableArray array];
GPUImageBeautifyFilter *beautyFilter = [[GPUImageBeautifyFilter alloc]init];
[filters addObject:beautyFilter];
```
此处可以用一些GPUImage提供的现成滤镜玩一下。比如：
```
//卡通描边滤镜

GPUImageToonFilter* toonFilter = [GPUImageToonFilternew];toonFilter.threshold=0.1;

//拉升变形滤镜

GPUImageStretchDistortionFilter* stretchDistortionFilter = [GPUImageStretchDistortionFilternew];

stretchDistortionFilter.center=CGPointMake(0.5,0.5);
```

#### 关联相机和预览的view
将上文提到的相机、预览View、滤镜数组，通过GPUImageFilterPipeline关联后，基本工作就完成了。
```
GPUImageFilterPipeline *pipline = [[GPUImageFilterPipeline alloc] initWithOrderedFilters:filters
input:self.camera
output:self.videoView];
```

#### 启动相机
在viewWillAppear之类的入口处，启动你的相机，就可以看到采集后的数据了：
```
[self.camera startCameraCapture];
```
#### 实时获取返回帧willOutputSampleBuffer
在声明<GPUImageVideoCameraDelegate>的类中，绑定GPUImageVideoCamera *camera的camera.delegate = self后，我们就可以通过回调函数willOutputSampleBuffer，获取到采集到的每一帧数据。在进行图像操作时，可以使用Copy内存的方案，将buffer copy一份出来进行识别操作等。processWithSampleBuffer：方法会在下文中解释。
```
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
CMSampleBufferRef picCopy;// 避免内存问题产生，此处Copy一份Buffer用作处理；
CMSampleBufferCreateCopy(CFAllocatorGetDefault(), sampleBuffer, &picCopy);
[self processWithSampleBuffer:(__bridge CMSampleBufferRef)(CFBridgingRelease(picCopy))];
}
```

## CoreImage的逐帧数据监测

#### CIDetector 人脸检测器初始化
CIDetector其实很强大，除了常见的用来识别二维码之外，我们还可以使用它来进行人脸检测。
在配置DetectorOfType的时候，我们选择CIDetectorTypeFace，即可用它来检测人脸特征数据。并且在配置options时，我们可以通过选择CIDetectorAccuracy的value值，来适配我们具体的业务。  
- CIDetectorAccuracyLow - 精度较低，性能更高;(电耗较低)
- CIDetectorAccuracyHigh - 性能较低，精度更高;(电耗较高)  

配置CIDetectorTracking后，Detector能够在视频帧之间跟踪的面孔。
```
- (void)loadFaceDetector {
// Detector 的配置初始化：
NSDictionary *detectorOptions = @{CIDetectorAccuracy:CIDetectorAccuracyLow,
CIDetectorTracking:@(YES)};
self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}
```
#### 传入SampleBuffer 返回识别后的人脸特征

处理图片我们会用到上文提到的GPUImage视频采集返回的CMSampleBufferRef，将其处理成CIImage后，使用CIDetector进行处理,便可获取到我们需要的CIFeature数据，他的Bounds就是我们需要的人脸位置。  
由于图像在处理的时候，需要为图像的EXIF信息进行一个方位的矫正。所以我们会传递相机的position，以及当前的设备orientation，来确定图片的朝向。  
另外，返回的数据是CIFeature，此处如果没有特殊特征值配置，那么仅会返回我们所需的人脸Feature。
```
/* The value for this key is an integer NSNumber from 1..8 such as that found in kCGImagePropertyOrientation.  
If present, the detection will be done based on that orientation but the coordinates 
in the returned features will still be based on those of the image. */

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
```

#### 对实时返回的人脸Position Rect的做出响应(此处可以做个贴图)
大家可以看到我们的self.beautyFilter是基于GPUImage自定义的一个滤镜，这部分内容大家可以去看看源码进行补充。但是反过来，此处假如大家有关于简单贴图的需求，那么看到这一段就可以完成了。在函数updateFaceMask中获取到的CGRect就是人脸在获取到的帧图像中的位置。
```
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
```

## GPUImage定制Filter进行人脸追踪绘制
我们在这部分内容中，拿常见的GPUImageBeautifyFilter定制滤镜为例。(有自己研究过GPUImage滤镜的捧油一定不陌生，这是一个5毛的美颜滤镜。)  
GPUImageBeautifyFilter的不足之处，在于他是对全幅的数据进行美颜处理，虽然有保留边缘，但是大家都是糊化的物体了。  
那么我们一起看看如何对定制Filter进行CGRect入参传入。并且可以通过kGPUImageBeautifyFragmentShaderString来进行特殊GL操作。

GPUImageFilter是支持对GL部分进行传参,我们可以GPUImageBeautifyFilter的Group成员之一的GPUImageCombinationFilter进行操作：

```
GPUImageFilter:
- (void)setVec4:(GPUVector4)vectorValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
```
为GPUImageCombinationFilter添加Mask。(intensity是GPUImageBeautifyFilter中原有的)  
在init时声明mask在GL操作中的uniformIndex。
```
@interface GPUImageCombinationFilter : GPUImageThreeInputFilter {
GLint _smoothDegreeUniform;
GLint _maskUniform;
}

@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) CGRect mask;

@end

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
```
完成以上步骤后，我们就可以在FragmentShaderString中，直接获取到Mask传入的Rect位置了，如下：
```
uniform lowp vec4 mask;
```
之后，通过划分边界，来对局部进行着色处理，就可以实现局部美颜的功能了。
```
if(gl_FragCoord.x < (mask.x + mask.z) && gl_FragCoord.y < (mask.y + mask.w) && gl_FragCoord.x > mask.x && gl_FragCoord.y > mask.y) {
gl_FragColor = smooth;
}else {
gl_FragColor = origin;
}
```
整段局部美颜偏远着色器代码如下：
```
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
```

