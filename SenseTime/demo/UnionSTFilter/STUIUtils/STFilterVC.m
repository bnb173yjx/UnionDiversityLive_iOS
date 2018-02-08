//
//  ViewController.m
//
//  Created by HaifengMay on 16/11/7.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import "STFilterVC.h"
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "STMobileLog.h"
#import "STTriggerView.h"
#import "STScrollTitleView.h"
#import "STCollectionView.h"
#import "STParamUtil.h"
#import "STSliderView.h"
#import "STFilterView.h"
#import "STButton.h"
#import <sys/utsname.h>
#import <libunionmediaengine.h>

//ST_MOBILE
#import "st_mobile_sticker.h"
#import "st_mobile_beautify.h"
#import "st_mobile_license.h"
#import "st_mobile_face_attribute.h"
#import "st_mobile_filter.h"
#import "st_mobile_object.h"

// 两种 check license 的方式 , 一种是根据 license 文件的路径 , 另一种是 license 文件的缓存选择应用场景合适的即可
#define CHECK_LICENSE_WITH_PATH 1


#define SLIDER_HEIGHT (CGRectGetHeight(_level2Beautify.frame) - CGRectGetHeight(_btnCloseBeautify.frame)) / 6.0

#define DRAW_FACE_KEY_POINTS 0
#define ENABLE_DYNAMIC_ADD_AND_REMOVE_MODELS 0

#define USE_GLKVIEW 0

typedef NS_ENUM(NSInteger, STViewTag) {
    
    STViewTagSpecialEffectsBtn = 1,
    STViewTagBeautyBtn,
    
    STViewTagBeautyShapeView,
    STViewTagBeautyBaseView,
    
    STViewTagShrinkFaceSlider,
    STViewTagEnlargeEyeSlider,
    STViewTagShrinkJawSlider,
    STViewTagSmoothSlider,
    STViewTagReddenSlider,
    STViewTagWhitenSlider
};

@interface STFilterVC () <STCommonObjectContainerViewDelegate, STViewButtonDelegate>
{
    st_handle_t _hSticker;  // sticker句柄
    st_handle_t _hDetector; // detector句柄
    st_handle_t _hBeautify; // beautify句柄
    st_handle_t _hAttribute;// attribute句柄
    st_handle_t _hFilter;   // filter句柄
    st_handle_t _hTracker;  // 通用物体跟踪句柄
    
    st_rect_t _rect;  // 通用物体位置
    float _result_score; //通用物体置信度
    
    CVOpenGLESTextureCacheRef _cvTextureCache;
    
    CVOpenGLESTextureRef _cvTextureOrigin;
    CVOpenGLESTextureRef _cvTextureBeautify;
    CVOpenGLESTextureRef _cvTextureSticker;
    CVOpenGLESTextureRef _cvTextureFilter;

    
    CVPixelBufferRef _cvBeautifyBuffer;
    CVPixelBufferRef _cvStickerBuffer;
    CVPixelBufferRef _cvFilterBuffer;

    GLuint _textureOriginInput;
    GLuint _textureBeautifyOutput;
    GLuint _textureStickerOutput;
    GLuint _textureFilterOutput;
}

//bottom tab bar
@property (nonatomic, readwrite, strong) STViewButton *specialEffectsBtn;
@property (nonatomic, readwrite, strong) STViewButton *beautyBtn;

@property (nonatomic, readwrite, strong) UIView *specialEffectsContainerView;
@property (nonatomic, readwrite, strong) UIView *beautyContainerView;
@property (nonatomic, readwrite, strong) UIView *filterCategoryView;
@property (nonatomic, readwrite, strong) UIView *filterSwitchView;
@property (nonatomic, readwrite, strong) STFilterView *filterView;

@property (nonatomic, readwrite, strong) UIView *beautyShapeView;
@property (nonatomic, readwrite, strong) UIView *beautyBaseView;

@property (nonatomic, readwrite, strong) UIView *filterStrengthView;

@property (nonatomic, readwrite, strong) STScrollTitleView *scrollTitleView;
@property (nonatomic, readwrite, strong) STScrollTitleView *beautyScrollTitleView;

@property (nonatomic, readwrite, strong) STCollectionView *collectionView;
@property (nonatomic, readwrite, strong) STCollectionView *objectTrackCollectionView;
@property (nonatomic, readwrite, strong) STFilterCollectionView *filterCollectionView;

@property (nonatomic, strong) STTriggerView *triggerView;

@property (nonatomic, copy) NSString *strStickerPath;

@property (nonatomic, readwrite, strong) NSMutableArray *arrBeautyViews;
@property (nonatomic, readwrite, strong) NSMutableArray<STViewButton *> *arrFilterCategoryViews;

@property (nonatomic, readwrite, assign) BOOL specialEffectsContainerViewIsShow;
@property (nonatomic, readwrite, assign) BOOL beautyContainerViewIsShow;

@property (nonatomic, readwrite, assign) unsigned long long iCurrentAction;

@property (nonatomic, readwrite, assign) BOOL isAppActive;

@property (nonatomic, readwrite, assign) CGFloat imageWidth;
@property (nonatomic, readwrite, assign) CGFloat imageHeight;

//bottom tab bar status
@property (nonatomic, readwrite, assign) BOOL bBeauty;
@property (nonatomic, readwrite, assign) BOOL bSticker;
@property (nonatomic, readwrite, assign) BOOL bTracker;
@property (nonatomic, readwrite, assign) BOOL bFilter;

//beauty value
@property (nonatomic, assign) float fSmoothStrength;
@property (nonatomic, assign) float fReddenStrength;
@property (nonatomic, assign) float fWhitenStrength;
@property (nonatomic, assign) float fEnlargeEyeStrength;
@property (nonatomic, assign) float fShrinkFaceStrength;
@property (nonatomic, assign) float fShrinkJawStrength;
//filter value
@property (nonatomic, assign) float fFilterStrength;

@property (nonatomic, strong) UILabel *lblFilterStrength;

@property (nonatomic, readwrite, strong) UILabel *resolutionLabel;
@property (nonatomic, readwrite, strong) UILabel *attributeLabel;

@property (nonatomic, strong) EAGLContext *glContext;

@property (nonatomic, readwrite, strong) NSMutableArray *normalImages;
@property (nonatomic, readwrite, strong) NSMutableArray *selectedImages;

@property (nonatomic, assign) CGFloat scale;  //视频充满全屏的缩放比例
@property (nonatomic, assign) int margin;
@property (nonatomic, assign, getter=isCommonObjectViewAdded) BOOL commonObjectViewAdded;
@property (nonatomic, assign, getter=isCommonObjectViewSetted) BOOL commonObjectViewSetted;

@property (nonatomic, strong) NSMutableArray *arrPersons;
@property (nonatomic, strong) NSMutableArray *arrPoints;

@property (nonatomic, assign) double lastTimeAttrDetected;

@property (nonatomic, readwrite, strong) NSArray *arr2DStickers;
@property (nonatomic, readwrite, strong) NSArray *arr3DStickers;
@property (nonatomic, readwrite, strong) NSArray *arrGestureStickers;
@property (nonatomic, readwrite, strong) NSArray *arrSegmentStickers;
@property (nonatomic, readwrite, strong) NSArray *arrFacedeformationStickers;
@property (nonatomic, readwrite, strong) NSArray *arrObjectTrackers;
@property (nonatomic, readwrite, strong) NSArray *arrFaceChangeStickers;

@property (nonatomic, readwrite, strong) STSliderView *thinFaceView;
@property (nonatomic, readwrite, strong) STSliderView *enlargeEyesView;
@property (nonatomic, readwrite, strong) STSliderView *smallFaceView;
@property (nonatomic, readwrite, strong) STSliderView *dermabrasionView;
@property (nonatomic, readwrite, strong) STSliderView *ruddyView;
@property (nonatomic, readwrite, strong) STSliderView *whitenView;

@property (nonatomic, readwrite, strong) UIImageView *noneStickerImageView;

@property (nonatomic, readwrite, assign) BOOL isNullSticker;
@property (nonatomic, readwrite, assign) BOOL filterStrengthViewHiddenState;

@property (nonatomic, readwrite, strong) UISlider *filterStrengthSlider;
@property (nonatomic, readwrite, strong) STCollectionViewDisplayModel *currentSelectedFilterModel;

@property (nonatomic, strong) NSMutableArray *faceArray;

@property (nonatomic) dispatch_queue_t changeModelQueue;
@property (nonatomic) dispatch_queue_t changeStickerQueue;

@property (nonatomic, copy) NSString *preFilterModelPath;
@property (nonatomic, copy) NSString *curFilterModelPath;

@property (nonatomic, copy) NSString *strBodyAction;

@property (nonatomic, readwrite, strong) UIView *view;

@property (nonatomic, strong) UnionGPUPicOutput *textureOutput;
@property (nonatomic, strong) GPUImageTextureInput *textureInput;

@end

@implementation STFilterVC

#pragma mark - life cycle

- (void) addview:(UIView*)view {
    [self setupSubviews:view];
    self.view = view;
    self.commonObjectContainerView = [[STCommonObjectContainerView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    self.commonObjectContainerView.delegate = self;
    [self.view insertSubview:self.commonObjectContainerView atIndex:0];
    [self resetSettings];
}

- (void)setFilter:(CGSize)previewDimension
{
    self.imageWidth = previewDimension.width;
    self.imageHeight = previewDimension.height;
    [self setDefaultValue];
    [self initResource];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}


- (void)releaseResources
{
    [EAGLContext setCurrentContext:self.glContext];
    
    if (_hSticker) {
        
        st_mobile_sticker_destroy(_hSticker);
        _hSticker = NULL;
    }
    if (_hBeautify) {
        
        st_mobile_beautify_destroy(_hBeautify);
        _hBeautify = NULL;
    }
    
    if (_hDetector) {
        
        st_mobile_human_action_destroy(_hDetector);
        _hDetector = NULL;
    }
    
    if (_hAttribute) {
        
        st_mobile_face_attribute_destroy(_hAttribute);
        _hAttribute = NULL;
    }
    
    if (_hFilter) {
        
        st_mobile_gl_filter_destroy(_hFilter);
        _hFilter = NULL;
    }
    
    if (_hTracker) {
        st_mobile_object_tracker_destroy(_hTracker);
        _hTracker = NULL;
    }
    
    [self releaseResultTexture];
    
    if (_cvTextureCache) {

        CFRelease(_cvTextureCache);
        _cvTextureCache = NULL;
    }
    
    //glFinish();

    [EAGLContext setCurrentContext:nil];
    
    self.glContext = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.commonObjectContainerView removeFromSuperview];
        self.commonObjectContainerView = nil;
        
    });
}

- (void)initResource
{
    EAGLContext *preContext = [self getPreContext];
    
    self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                                 sharegroup:[GPUImageContext sharedImageProcessingContext].context.sharegroup];
    
    [self setCurrentContext:self.glContext];
    
    // 初始化结果文理及纹理缓存
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.glContext, NULL, &_cvTextureCache);
    
    if (err) {

        NSLog(@"CVOpenGLESTextureCacheCreate %d" , err);
    }
    
    [self initResultTexture];
    
    ///ST_MOBILE：初始化句柄之前需要验证License
    if ([self checkActiveCode]) {
        ///ST_MOBILE：初始化相关的句柄
        [self setupHandle];
    }
    // 需要设为之前的渲染环境防止与其他需要 GPU 资源的模块冲突.
    [self setCurrentContext:preContext];
    
    [[GPUImageContext sharedFramebufferCache]purgeAllUnassignedFramebuffers];
    
    _textureOutput = [[UnionGPUPicOutput alloc] initWithOutFmt:kCVPixelFormatType_32RGBA];

    __weak typeof(self) weakSelf = self;
    _textureOutput.videoProcessingCallback = ^(CVPixelBufferRef pixelBuffer, CMTime timeInfo){
        [weakSelf uploadRGBPixel:pixelBuffer time:timeInfo];
    };
    
    _textureInput = [[GPUImageTextureInput alloc] initWithTexture:_textureFilterOutput size:CGSizeMake(self.imageWidth, self.imageHeight)];
}

- (EAGLContext *)getPreContext
{
    return [EAGLContext currentContext];
}

- (void)setCurrentContext:(EAGLContext *)context
{
    if ([EAGLContext currentContext] != context) {
        
        [EAGLContext setCurrentContext:context];
    }
}

- (void)uploadRGBPixel:(CVPixelBufferRef)pixelBuffer
                  time:(CMTime)timeInfo {
    self.bBeauty = YES;
    self.bFilter = YES;
    self.bSticker = YES;
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CFRetain(pixelBuffer);
    unsigned char * pBGRAImageIn = CVPixelBufferGetBaseAddress(pixelBuffer);

    int iBytesPerRow = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);

    int iWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int iHeight = (int)CVPixelBufferGetHeight(pixelBuffer);

    size_t iTop , iBottom , iLeft , iRight;
    CVPixelBufferGetExtendedPixels(pixelBuffer, &iLeft, &iRight, &iTop, &iBottom);

    iWidth = iWidth + (int)iLeft + (int)iRight;
    iHeight = iHeight + (int)iTop + (int)iBottom;
    iBytesPerRow = iBytesPerRow + (int)iLeft + (int)iRight;

    _scale = MAX(SCREEN_HEIGHT / iHeight, SCREEN_WIDTH / iWidth);
    _margin = (iWidth * _scale - SCREEN_WIDTH) / 2;

    st_rotate_type stMobileRotate = [self getRotateType];

    st_result_t iRet = ST_OK;
    st_mobile_human_action_t detectResult;
    memset(&detectResult, 0, sizeof(st_mobile_human_action_t));
    int iFaceCount = 0;

    _faceArray = [NSMutableArray array];

    // 如果需要做属性,每隔一秒做一次属性
    double dTimeNow = CFAbsoluteTimeGetCurrent();
    BOOL isAttributeTime = (dTimeNow - self.lastTimeAttrDetected) >= 1.0;

    if (isAttributeTime) {

        self.lastTimeAttrDetected = dTimeNow;
    }
    ///ST_MOBILE 以下为通用物体跟踪部分
    if (_bTracker && _hTracker) {

        if (self.isCommonObjectViewAdded) {

            if (!self.isCommonObjectViewSetted) {

                iRet = st_mobile_object_tracker_set_target(_hTracker, pBGRAImageIn, ST_PIX_FMT_BGRA8888, iWidth, iHeight, iBytesPerRow, &_rect);

                if (iRet != ST_OK) {
                    NSLog(@"st mobile object tracker set target failed: %d", iRet);
                    _rect.left = 0;
                    _rect.top = 0;
                    _rect.right = 0;
                    _rect.bottom = 0;
                } else {
                    self.commonObjectViewSetted = YES;
                }
            }

            if (self.isCommonObjectViewSetted) {

                TIMELOG(keyTracker);
                iRet = st_mobile_object_tracker_track(_hTracker, pBGRAImageIn, ST_PIX_FMT_BGRA8888, iWidth, iHeight, iBytesPerRow, &_rect, &_result_score);
                NSLog(@"tracking, result_score: %f,rect.left: %d, rect.top: %d, rect.right: %d, rect.bottom: %d", _result_score, _rect.left, _rect.top, _rect.right, _rect.bottom);
                TIMEPRINT(keyTracker, "st_mobile_object_tracker_track time:");

                if (iRet != ST_OK) {

                    NSLog(@"st mobile object tracker track failed: %d", iRet);
                    _rect.left = 0;
                    _rect.top = 0;
                    _rect.right = 0;
                    _rect.bottom = 0;
                }

                CGRect rectDisplay = CGRectMake(_rect.left * _scale - _margin,
                                                _rect.top * _scale,
                                                _rect.right * _scale - _rect.left * _scale,
                                                _rect.bottom * _scale - _rect.top * _scale);
                CGPoint center = CGPointMake(rectDisplay.origin.x + rectDisplay.size.width / 2,
                                             rectDisplay.origin.y + rectDisplay.size.height / 2);

                dispatch_async(dispatch_get_main_queue(), ^{

                    if (self.commonObjectContainerView.currentCommonObjectView.isOnFirst) {
                        //用作同步,防止再次改变currentCommonObjectView的位置

                    } else if (_rect.left == 0 && _rect.top == 0 && _rect.right == 0 && _rect.bottom == 0) {

                        self.commonObjectContainerView.currentCommonObjectView.hidden = YES;

                    } else {
                        self.commonObjectContainerView.currentCommonObjectView.hidden = NO;
                        self.commonObjectContainerView.currentCommonObjectView.center = center;
                    }
                });
            }
            if(_viewUpdateCallback) {
                _viewUpdateCallback();
            }
        }
    }

    ///ST_MOBILE 人脸信息检测部分
    if (_hDetector) {

        BOOL needFaceDetection = ((self.fEnlargeEyeStrength > 0 || self.fShrinkFaceStrength > 0 || self.fShrinkJawStrength > 0) && _hBeautify) || (isAttributeTime && _hAttribute);

        unsigned long long iConfig = self.iCurrentAction;

        if (needFaceDetection) {
            iConfig = self.iCurrentAction | ST_MOBILE_FACE_DETECT;
        }

        if (iConfig > 0) {

            TIMELOG(keyDetect);

            iRet = st_mobile_human_action_detect(_hDetector,
                                                 pBGRAImageIn,
                                                 ST_PIX_FMT_BGRA8888,
                                                 iWidth,
                                                 iHeight,
                                                 iBytesPerRow,
                                                 stMobileRotate,
                                                 iConfig,
                                                 &detectResult);

            TIMEPRINT(keyDetect, "st_mobile_human_action_detect time:");

#if DRAW_FACE_KEY_POINTS
            if (detectResult.p_bodys && detectResult.body_count > 0) {

                NSLog(@"body action: %llx", detectResult.p_bodys[0].body_action);

                if (CHECK_FLAG(detectResult.p_bodys[0].body_action, ST_MOBILE_BODY_ACTION1)) {
                    self.strBodyAction = @"龙拳";
                } else if (CHECK_FLAG(detectResult.p_bodys[0].body_action, ST_MOBILE_BODY_ACTION2)) {
                    self.strBodyAction = @"一休";
                } else if (CHECK_FLAG(detectResult.p_bodys[0].body_action, ST_MOBILE_BODY_ACTION3)) {
                    self.strBodyAction = @"摊手";
                } else if (CHECK_FLAG(detectResult.p_bodys[0].body_action, ST_MOBILE_BODY_ACTION4)) {
                    self.strBodyAction = @"蜘蛛侠";
                } else if (CHECK_FLAG(detectResult.p_bodys[0].body_action, ST_MOBILE_BODY_ACTION5)) {
                    self.strBodyAction = @"动感超人";
                } else {
                    self.strBodyAction = @"";
                }

            } else {
                self.strBodyAction = @"";
            }
#endif

            if(iRet == ST_OK) {
                iFaceCount = detectResult.face_count;
            }else{
                STLog(@"st_mobile_human_action_detect failed %d" , iRet);
            }
        }
    }
    // 记录之前的渲染环境
    EAGLContext *preContext = [self getPreContext];
    // 设置 SDK 的渲染环境
    [self setCurrentContext:self.glContext];
    
    // 当图像尺寸发生改变时需要对应改变纹理大小
    if (iWidth != self.imageWidth || iHeight != self.imageHeight) {
        
        [self releaseResultTexture];
        
        self.imageWidth = iWidth;
        self.imageHeight = iHeight;
        
        [self initResultTexture];
    }

    // 原图纹理
    BOOL isTextureOriginReady = [self setupOriginTextureWithPixelBuffer:pixelBuffer];
    GLuint textureResult = _textureOriginInput;
    CVPixelBufferRef resultPixelBufffer = pixelBuffer;
    if (isTextureOriginReady) {

        ///ST_MOBILE 以下为美颜部分
        if (_bBeauty && _hBeautify) {

            TIMELOG(keyBeautify);

            iRet = st_mobile_beautify_process_texture(_hBeautify,
                                                      _textureOriginInput,
                                                      iWidth,
                                                      iHeight,
                                                      &detectResult,
                                                      _textureBeautifyOutput,
                                                      &detectResult);

            TIMEPRINT(keyBeautify, "st_mobile_beautify_process_texture time:");

            if (ST_OK != iRet) {

                STLog(@"st_mobile_beautify_process_texture failed %d" , iRet);

            }

            textureResult = _textureBeautifyOutput;
            resultPixelBufffer = _cvBeautifyBuffer;
        }

    }
    if (self.isNullSticker) {
        iRet = st_mobile_sticker_change_package(_hSticker, NULL);

        if (ST_OK != iRet) {
            NSLog(@"st_mobile_sticker_change_package error %d", iRet);
        }
    }

#if DRAW_FACE_KEY_POINTS

    [self drawKeyPoints:detectResult];
#endif


    ///ST_MOBILE 以下为贴纸部分
    if (_bSticker && _hSticker) {

        //调整贴纸最小帧处理间隔，单位ms。
        st_result_t iRet = st_mobile_sticker_set_min_interval(_hSticker, 1);
        if (iRet != ST_OK) {
            NSLog(@"st_mobile_sticker_set_min_interval failed: %d", iRet);
        }

        TIMELOG(stickerProcessKey);

        iRet = st_mobile_sticker_process_texture(_hSticker, textureResult, iWidth, iHeight, stMobileRotate, ST_CLOCKWISE_ROTATE_0, false, &detectResult, item_callback, _textureStickerOutput);

        TIMEPRINT(stickerProcessKey, "st_mobile_sticker_process_texture time:");

        if (ST_OK != iRet) {

            STLog(@"st_mobile_sticker_process_texture %d" , iRet);

        }

        textureResult = _textureStickerOutput;
        resultPixelBufffer = _cvStickerBuffer;
    }


    ///ST_MOBILE 以下为滤镜部分
    if (_bFilter && _hFilter) {

        if (self.curFilterModelPath != self.preFilterModelPath) {
            iRet = st_mobile_gl_filter_set_style(_hFilter, self.curFilterModelPath.UTF8String);
            self.preFilterModelPath = self.curFilterModelPath;
        }

        TIMELOG(keyFilter);

        iRet = st_mobile_gl_filter_process_texture(_hFilter, textureResult, iWidth, iHeight, _textureFilterOutput);

        if (ST_OK != iRet) {

            STLog(@"st_mobile_gl_filter_process_texture %d" , iRet);

        }

        TIMEPRINT(keyFilter, "st_mobile_gl_filter_process_texture time:");

        textureResult = _textureFilterOutput;
        resultPixelBufffer = _cvFilterBuffer;
    }
    [_textureInput processTextureWithFrameTime:timeInfo];
    [self setCurrentContext:preContext];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CFRelease(pixelBuffer);
    CVOpenGLESTextureCacheFlush(_cvTextureCache, 0);
    
    if (_cvTextureOrigin) {
        CFRelease(_cvTextureOrigin);
        _cvTextureOrigin = NULL;
    }
}

- (void)addTarget:(id<GPUImageInput>)newTarget{
    [_textureInput addTarget:newTarget];
}
- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation{
    [_textureInput addTarget:newTarget atTextureLocation:textureLocation];
}

-(void)removeAllTargets{
    [_textureInput removeAllTargets];
}

#pragma GPUImageInput
- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    [_textureOutput newFrameReadyAtTime:frameTime atIndex:textureIndex];
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex {
    [_textureOutput setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
}

- (NSInteger)nextAvailableTextureIndex {
    return 0;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex {
    [_textureOutput setInputSize:newSize atIndex:textureIndex];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation
                 atIndex:(NSInteger)textureIndex {
    [_textureOutput setInputRotation:newInputRotation atIndex:textureIndex];
}

- (GPUImageRotationMode)  getInputRotation {
    return [_textureOutput getInputRotation];
}

- (CGSize)maximumOutputSize  {
    return [_textureOutput maximumOutputSize];
}

- (void)endProcessing {
    
}
- (BOOL)shouldIgnoreUpdatesToThisTarget {
    return NO;
}

- (BOOL)wantsMonochromeInput {
    return NO;
}
- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue {
    
}

#pragma mark - setup subviews

- (void)setupSubviews:(UIView*)view {
    
    [view addSubview:self.triggerView];
    [view addSubview:self.specialEffectsContainerView];
    [view addSubview:self.beautyContainerView];
    [view addSubview:self.filterStrengthView];
    [view addSubview:self.specialEffectsBtn];
    [view addSubview:self.beautyBtn];
}

- (void)setDefaultValue {
    
    self.bBeauty = YES;
    self.bFilter = NO;
    self.bSticker = NO;
    self.bTracker = NO;
    
    self.isNullSticker = NO;
    
    self.fFilterStrength = 1.0;
    
    self.iCurrentAction = 0;
    
    self.isAppActive = YES;
    
    self.changeModelQueue = dispatch_queue_create("com.sensetime.changemodelqueue", NULL);
    self.changeStickerQueue = dispatch_queue_create("com.sensetime.changestickerqueue", NULL);
    self.filterStrengthViewHiddenState = YES;
    
    self.preFilterModelPath = nil;
    self.curFilterModelPath = nil;
}

#pragma mark - setup handle

- (void)setupHandle {
    
    st_result_t iRet = ST_OK;
    
    [EAGLContext setCurrentContext:self.glContext];
    
    //初始化检测模块句柄
    NSString *strModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Action_5.2.0" ofType:@"model"];
    
    uint32_t config = ST_MOBILE_HUMAN_ACTION_DEFAULT_CONFIG_VIDEO;
    
    TIMELOG(key);
    
    iRet = st_mobile_human_action_create(strModelPath.UTF8String,
                                         config,
                                         &_hDetector);
    
    TIMEPRINT(key,"human action create time:");
    
    if (ST_OK != iRet || !_hDetector) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"算法SDK初始化失败，可能是模型路径错误，SDK权限过期，与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        
        [alert show];
    } else {
        
        NSString *strFaceExtraModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Face_Extra_5.1.0" ofType:@"model"];
        iRet = st_mobile_human_action_add_sub_model(_hDetector, strFaceExtraModelPath.UTF8String);
        if (iRet != ST_OK) {
            NSLog(@"human action add face extra model failed: %d", iRet);
        }
    }
    
    //初始化贴纸模块句柄 , 默认开始时无贴纸 , 所以第一个路径参数传空
    TIMELOG(keySticker);
    
    iRet = st_mobile_sticker_create(NULL , &_hSticker);
    
    TIMEPRINT(keySticker, "sticker create time:");
    
    if (ST_OK != iRet || !_hSticker) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"贴纸SDK初始化失败 , SDK权限过期，或者与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        
        [alert show];
    }
    
    //初始化美颜模块句柄
    iRet = st_mobile_beautify_create(&_hBeautify);
    
    if (ST_OK != iRet || !_hBeautify) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"美颜SDK初始化失败，可能是模型路径错误，SDK权限过期，与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        
        [alert show];
    }else{
        
        // 设置默认红润参数
        iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_REDDEN_STRENGTH, self.fReddenStrength);
        
        if (ST_OK != iRet){
            
            STLog(@"st_mobile_beautify_setparam REDDEN:error %d" ,iRet);
        }
        
        // 设置默认磨皮参数
        iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_SMOOTH_STRENGTH, self.fSmoothStrength);
        
        if (ST_OK != iRet) {
            
            STLog(@"st_mobile_beautify_setparam SMOOTH:error %d" ,iRet);
        }
        
        // 设置默认大眼参数
        iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_ENLARGE_EYE_RATIO, self.fEnlargeEyeStrength);
        
        if (ST_OK != iRet) {
            
            STLog(@"st_mobile_beautify_setparam ENLARGE_EYE:error %d" , iRet);
        }
        
        // 设置默认瘦脸参数
        iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_SHRINK_FACE_RATIO, self.fShrinkFaceStrength);
        
        if (ST_OK != iRet) {
            
            STLog(@"st_mobile_beautify_setparam SHRINK_FACE:error %d" , iRet);
        }
        
        // 设置小脸参数
        iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_SHRINK_JAW_RATIO, self.fShrinkJawStrength);
        
        if (ST_OK != iRet) {
            
            STLog(@"st_mobile_beautify_setparam SHRINK_JAW %d" , iRet);
        }
        
        // 设置美白参数
        iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_WHITEN_STRENGTH, self.fWhitenStrength);
        
        if (ST_OK != iRet) {
            
            STLog(@"st_mobile_beautify_setparam WHITEN:error %d" , iRet);
        }
    }
    
    // 初始化滤镜句柄
    iRet = st_mobile_gl_filter_create(&_hFilter);
    
    if (ST_OK != iRet || !_hFilter) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"滤镜SDK初始化失败，可能是SDK权限过期或与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        
        [alert show];
    }
    
    // 初始化通用物体追踪句柄
    iRet = st_mobile_object_tracker_create(&_hTracker);
    
    if (ST_OK != iRet || !_hTracker) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"通用物体跟踪SDK初始化失败，可能是SDK权限过期或与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        
        [alert show];
    }
    
}

#pragma mark - check license
//验证license
- (BOOL)checkActiveCode
{
    NSString *strLicensePath = [[NSBundle mainBundle] pathForResource:@"SENSEME" ofType:@"lic"];
    NSData *dataLicense = [NSData dataWithContentsOfFile:strLicensePath];
    
    NSString *strKeySHA1 = @"SENSEME";
    NSString *strKeyActiveCode = @"ACTIVE_CODE";
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *strStoredSHA1 = [userDefaults objectForKey:strKeySHA1];
    NSString *strLicenseSHA1 = [self getSHA1StringWithData:dataLicense];
    
    st_result_t iRet = ST_OK;
    
    
    if (strStoredSHA1.length > 0 && [strLicenseSHA1 isEqualToString:strStoredSHA1]) {
        
        // Get current active code
        // In this app active code was stored in NSUserDefaults
        // It also can be stored in other places
        NSData *activeCodeData = [userDefaults objectForKey:strKeyActiveCode];
        
        // Check if current active code is available
#if CHECK_LICENSE_WITH_PATH
        
        // use file
        iRet = st_mobile_check_activecode(
                                          strLicensePath.UTF8String,
                                          (const char *)[activeCodeData bytes],
                                          (int)[activeCodeData length]
                                          );
        
#else
        
        // use buffer
        NSData *licenseData = [NSData dataWithContentsOfFile:strLicensePath];
        
        iRet = st_mobile_check_activecode_from_buffer(
                                                      [licenseData bytes],
                                                      (int)[licenseData length],
                                                      [activeCodeData bytes],
                                                      (int)[activeCodeData length]
                                                      );
#endif
        
        
        if (ST_OK == iRet) {
            
            // check success
            return YES;
        }
    }
    
    /*
     1. check fail
     2. new one
     3. update
     */
    
    char active_code[1024];
    int active_code_len = 1024;
    
    // generate one
#if CHECK_LICENSE_WITH_PATH
    
    // use file
    iRet = st_mobile_generate_activecode(
                                         strLicensePath.UTF8String,
                                         active_code,
                                         &active_code_len
                                         );
    
#else
    
    // use buffer
    NSData *licenseData = [NSData dataWithContentsOfFile:strLicensePath];
    
    iRet = st_mobile_generate_activecode_from_buffer(
                                                     [licenseData bytes],
                                                     (int)[licenseData length],
                                                     active_code,
                                                     &active_code_len
                                                     );
#endif
    
    if (ST_OK != iRet) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"使用 license 文件生成激活码时失败，可能是授权文件过期。" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        
        [alert show];
        
        return NO;
        
    } else {
        
        // Store active code
        NSData *activeCodeData = [NSData dataWithBytes:active_code length:active_code_len];
        
        [userDefaults setObject:activeCodeData forKey:strKeyActiveCode];
        [userDefaults setObject:strLicenseSHA1 forKey:strKeySHA1];
        
        [userDefaults synchronize];
    }
    
    return YES;
}

- (NSString *)getSHA1StringWithData:(NSData *)data
{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *strSHA1 = [NSMutableString string];
    
    for (int i = 0 ; i < CC_SHA1_DIGEST_LENGTH ; i ++) {
        
        [strSHA1 appendFormat:@"%02x" , digest[i]];
    }
    
    return strSHA1;
}

#pragma mark - handle texture

- (void)initResultTexture {
    // 创建结果纹理
    [self setupTextureWithPixelBuffer:&_cvBeautifyBuffer
                                    w:self.imageWidth
                                    h:self.imageHeight
                            glTexture:&_textureBeautifyOutput
                            cvTexture:&_cvTextureBeautify];
    
    [self setupTextureWithPixelBuffer:&_cvStickerBuffer
                                    w:self.imageWidth
                                    h:self.imageHeight
                            glTexture:&_textureStickerOutput
                            cvTexture:&_cvTextureSticker];
    
    
    [self setupTextureWithPixelBuffer:&_cvFilterBuffer
                                    w:self.imageWidth
                                    h:self.imageHeight
                            glTexture:&_textureFilterOutput
                            cvTexture:&_cvTextureFilter];
}

- (BOOL)setupTextureWithPixelBuffer:(CVPixelBufferRef *)pixelBufferOut
                                  w:(int)iWidth
                                  h:(int)iHeight
                          glTexture:(GLuint *)glTexture
                          cvTexture:(CVOpenGLESTextureRef *)cvTexture {
    CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault,
                                               NULL,
                                               NULL,
                                               0,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                             1,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
    
    CVReturn cvRet = CVPixelBufferCreate(kCFAllocatorDefault,
                                         iWidth,
                                         iHeight,
                                         kCVPixelFormatType_32BGRA,
                                         attrs,
                                         pixelBufferOut);
    
    if (kCVReturnSuccess != cvRet) {
        
        NSLog(@"CVPixelBufferCreate %d" , cvRet);
    }
    
    cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         _cvTextureCache,
                                                         *pixelBufferOut,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_RGBA,
                                                         self.imageWidth,
                                                         self.imageHeight,
                                                         GL_BGRA,
                                                         GL_UNSIGNED_BYTE,
                                                         0,
                                                         cvTexture);
    
    CFRelease(attrs);
    CFRelease(empty);
    
    if (kCVReturnSuccess != cvRet) {
        
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        
        return NO;
    }
    
    *glTexture = CVOpenGLESTextureGetName(*cvTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(*cvTexture), *glTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return YES;
}

- (BOOL)setupOriginTextureWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVReturn cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                  _cvTextureCache,
                                                                  pixelBuffer,
                                                                  NULL,
                                                                  GL_TEXTURE_2D,
                                                                  GL_RGBA,
                                                                  self.imageWidth,
                                                                  self.imageHeight,
                                                                  GL_BGRA,
                                                                  GL_UNSIGNED_BYTE,
                                                                  0,
                                                                  &_cvTextureOrigin);
    
    if (!_cvTextureOrigin || kCVReturnSuccess != cvRet) {
        
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        
        return NO;
    }
    
    _textureOriginInput = CVOpenGLESTextureGetName(_cvTextureOrigin);
    glBindTexture(GL_TEXTURE_2D , _textureOriginInput);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return YES;
}

- (void)releaseResultTexture {
    _textureBeautifyOutput = 0;
    _textureStickerOutput = 0;
    _textureFilterOutput = 0;
    
    if (_cvTextureOrigin) {
        
        CFRelease(_cvTextureOrigin);
        _cvTextureOrigin = NULL;
    }
    
    CVPixelBufferRelease(_cvTextureBeautify);
    CVPixelBufferRelease(_cvTextureSticker);
    CVPixelBufferRelease(_cvTextureFilter);

    CVPixelBufferRelease(_cvBeautifyBuffer);
    CVPixelBufferRelease(_cvStickerBuffer);
    CVPixelBufferRelease(_cvFilterBuffer);
}

- (NSString *)getDescriptionOfAttribute:(st_mobile_attributes_t)attribute {
    NSString *strAge , *strGender , *strAttricative = nil;
    
    for (int i = 0; i < attribute.attribute_count; i ++) {
        
        // 读取一条属性
        st_mobile_attribute_t attributeOne = attribute.p_attributes[i];
        
        // 获取属性类别
        const char *attr_category = attributeOne.category;
        const char *attr_label = attributeOne.label;
        
        // 年龄
        if (0 == strcmp(attr_category, "age")) {
            
            strAge = [NSString stringWithUTF8String:attr_label];
        }
        
        // 颜值
        if (0 == strcmp(attr_category, "attractive")) {
            
            strAttricative = [NSString stringWithUTF8String:attr_label];
        }
        
        // 性别
        if (0 == strcmp(attr_category, "gender")) {
            
            if (0 == strcmp(attr_label, "male") ) {
                
                strGender = @"男";
            }
            
            if (0 == strcmp(attr_label, "female") ) {
                
                strGender = @"女";
            }
        }
    }
    
    NSString *strAttrDescription = [NSString stringWithFormat:@"颜值:%@ 性别:%@ 年龄:%@" , strAttricative , strGender , strAge];
    
    return strAttrDescription;
}

#pragma mark - sticker callback

void item_callback(const char* material_name, st_material_status status) {
    
    switch (status){
        case ST_MATERIAL_BEGIN:
            STLog(@"begin %s" , material_name);
            break;
        case ST_MATERIAL_END:
            STLog(@"end %s" , material_name);
            break;
        case ST_MATERIAL_PROCESS:
            STLog(@"process %s", material_name);
            break;
        default:
            STLog(@"error");
            break;
    }
}


- (void)filterSliderValueChanged:(UISlider *)sender {
    
    _lblFilterStrength.text = [NSString stringWithFormat:@"%d", (int)(sender.value * 100)];
    
    if (_hFilter) {
        
        st_result_t iRet = st_mobile_gl_filter_set_param(_hFilter, ST_GL_FILTER_STRENGTH, sender.value);
        
        if (ST_OK != iRet) {
            
            STLog(@"st_mobile_gl_filter_set_param %d" , iRet);
        }
    }
}

#pragma mark - handle beauty value

- (void)beautifySliderValueChanged:(UISlider *)sender {
    
    if (_hBeautify) {
        
        st_result_t iRet = ST_OK;
        
        switch (sender.tag) {
                
            case STViewTagShrinkFaceSlider:
            {
                self.fShrinkFaceStrength = sender.value / 100;
                self.thinFaceView.maxLabel.text = [NSString stringWithFormat:@"%d", (int)(sender.value)];
                iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_SHRINK_FACE_RATIO, self.fShrinkFaceStrength);
                if (ST_OK != iRet) {
                    STLog(@"ST_BEAUTIFY_SHRINK_FACE_RATIO: %d", iRet);
                }
            }
                break;
            case STViewTagEnlargeEyeSlider:
            {
                self.fEnlargeEyeStrength = sender.value / 100;
                self.enlargeEyesView.maxLabel.text = [NSString stringWithFormat:@"%d", (int)(sender.value)];
                iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_ENLARGE_EYE_RATIO, self.fEnlargeEyeStrength);
                if (ST_OK != iRet) {
                    STLog(@"ST_BEAUTIFY_ENLARGE_EYE_RATIO: %d", iRet);
                }
            }
                break;
                
            case STViewTagShrinkJawSlider:
            {
                self.fShrinkJawStrength = sender.value / 100;
                self.smallFaceView.maxLabel.text = [NSString stringWithFormat:@"%d", (int)(sender.value)];
                iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_SHRINK_JAW_RATIO, self.fShrinkJawStrength);
                if (ST_OK != iRet) {
                    STLog(@"ST_BEAUTIFY_SHRINK_JAW_RATIO: %d", iRet);
                }
            }
                break;
                
            case STViewTagSmoothSlider:
            {
                self.fSmoothStrength = sender.value / 100;
                self.dermabrasionView.maxLabel.text = [NSString stringWithFormat:@"%d", (int)(sender.value)];
                iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_SMOOTH_STRENGTH, self.fSmoothStrength);
                if (ST_OK != iRet) {
                    STLog(@"ST_BEAUTIFY_SMOOTH_STRENGTH: %d", iRet);
                }
            }
                break;
                
            case STViewTagReddenSlider:
            {
                self.fReddenStrength = sender.value / 100;
                self.ruddyView.maxLabel.text = [NSString stringWithFormat:@"%d", (int)(sender.value)];
                iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_REDDEN_STRENGTH, self.fReddenStrength);
                if (ST_OK != iRet) {
                    STLog(@"ST_BEAUTIFY_REDDEN_STRENGTH: %d", iRet);
                }
            }
                break;
                
            case STViewTagWhitenSlider:
            {
                self.fWhitenStrength = sender.value / 100;
                self.whitenView.maxLabel.text = [NSString stringWithFormat:@"%d", (int)(sender.value)];
                iRet = st_mobile_beautify_setparam(_hBeautify, ST_BEAUTIFY_WHITEN_STRENGTH, self.fWhitenStrength);
                if (ST_OK != iRet) {
                    STLog(@"ST_BEAUTIFY_WHITEN_STRENGTH: %d", iRet);
                }
            }
                break;
                
        }
        
        
        if (self.fShrinkFaceStrength == 0 &&
            self.fEnlargeEyeStrength == 0 &&
            self.fShrinkJawStrength == 0 &&
            self.fSmoothStrength == 0 &&
            self.fReddenStrength == 0 &&
            self.fWhitenStrength == 0) {
            
            self.bBeauty = NO;
            
        } else {
            
            self.bBeauty = YES;
        }
        
    }
}

#pragma mark - draw points

- (void)drawKeyPoints:(st_mobile_human_action_t)detectResult {
    
    for (int i = 0; i < detectResult.face_count; ++i) {
        
        for (int j = 0; j < 106; ++j) {
            [_faceArray addObject:@{
                                    POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_faces[i].face106.points_array[j]]]
                                    }];
        }
        
        if (detectResult.p_faces[i].p_extra_face_points && detectResult.p_faces[i].extra_face_points_count > 0) {
            
            for (int j = 0; j < detectResult.p_faces[i].extra_face_points_count; ++j) {
                [_faceArray addObject:@{
                                        POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_faces[i].p_extra_face_points[j]]]
                                        }];
            }
        }
        
        if (detectResult.p_faces[i].p_eyeball_contour && detectResult.p_faces[i].eyeball_contour_points_count > 0) {
            
            for (int j = 0; j < detectResult.p_faces[i].eyeball_contour_points_count; ++j) {
                [_faceArray addObject:@{
                                        POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_faces[i].p_eyeball_contour[j]]]
                                        }];
            }
        }
        
    }
    
    if (detectResult.p_bodys && detectResult.body_count > 0) {
        
        for (int j = 0; j < detectResult.p_bodys[0].key_points_count; ++j) {
            
            if (detectResult.p_bodys[0].p_key_points_score[j] > 0.15) {
                [_faceArray addObject:@{
                                        POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_bodys[0].p_key_points[j]]]
                                        }];
            }
        }
    }
    
    self.commonObjectContainerView.faceArray = [_faceArray copy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.commonObjectContainerView setNeedsDisplay];
    });
}

- (CGPoint)coordinateTransformation:(st_pointf_t)point {
    
    return CGPointMake(_scale * point.x - _margin, _scale * point.y);
}

#pragma mark -

- (st_rotate_type)getRotateType
{
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    switch (deviceOrientation) {
            
        case UIDeviceOrientationPortrait:
            return ST_CLOCKWISE_ROTATE_0;
            
        case UIDeviceOrientationPortraitUpsideDown:
            return ST_CLOCKWISE_ROTATE_180;
            
        case UIDeviceOrientationLandscapeLeft:
            return ST_CLOCKWISE_ROTATE_90;
            
        case UIDeviceOrientationLandscapeRight:
            return ST_CLOCKWISE_ROTATE_270;
            
        default:
            return ST_CLOCKWISE_ROTATE_0;
    }
}

#pragma mark - handle system notifications

- (void)appWillResignActive {
    
    self.isAppActive = NO;
    
}

- (void)appDidEnterBackground {

    self.isAppActive = NO;
}

- (void)appWillEnterForeground {

    self.isAppActive = YES;
}

- (void)appDidBecomeActive {

    self.isAppActive = YES;
}

#pragma mark - lazy load views

- (STViewButton *)specialEffectsBtn {
    if (!_specialEffectsBtn) {
        
        _specialEffectsBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        [_specialEffectsBtn setExclusiveTouch:YES];
        
        UIImage *image = [UIImage imageNamed:@"btn_special_effects.png"];
        
        _specialEffectsBtn.frame = CGRectMake([self layoutWidthWithValue:143], SCREEN_HEIGHT - 50, image.size.width, 50);
        _specialEffectsBtn.center = CGPointMake(_specialEffectsBtn.center.x, 622);
        _specialEffectsBtn.backgroundColor = [UIColor clearColor];
        _specialEffectsBtn.imageView.image = [UIImage imageNamed:@"btn_special_effects.png"];
        _specialEffectsBtn.imageView.highlightedImage = [UIImage imageNamed:@"btn_special_effects_selected.png"];
        _specialEffectsBtn.titleLabel.textColor = [UIColor whiteColor];
        _specialEffectsBtn.titleLabel.highlightedTextColor = UIColorFromRGB(0xc086e5);
        _specialEffectsBtn.titleLabel.text = @"特效";
        _specialEffectsBtn.tag = STViewTagSpecialEffectsBtn;
        
        STWeakSelf;
        
        _specialEffectsBtn.tapBlock = ^{
            [weakSelf clickBottomViewButton:weakSelf.specialEffectsBtn];
        };
    }
    return _specialEffectsBtn;
}

- (STViewButton *)beautyBtn {
    if (!_beautyBtn) {
        _beautyBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        [_beautyBtn setExclusiveTouch:YES];
        
        UIImage *image = [UIImage imageNamed:@"btn_beauty.png"];
        
        _beautyBtn.frame = CGRectMake(SCREEN_WIDTH - [self layoutWidthWithValue:143] - image.size.width, SCREEN_HEIGHT - 50, image.size.width, 50);
        _beautyBtn.center = CGPointMake(_beautyBtn.center.x, 622);
        _beautyBtn.backgroundColor = [UIColor clearColor];
        _beautyBtn.imageView.image = [UIImage imageNamed:@"btn_beauty.png"];
        _beautyBtn.imageView.highlightedImage = [UIImage imageNamed:@"btn_beauty_selected.png"];
        _beautyBtn.titleLabel.textColor = [UIColor whiteColor];
        _beautyBtn.titleLabel.highlightedTextColor = UIColorFromRGB(0xc086e5);
        _beautyBtn.titleLabel.text = @"美颜";
        _beautyBtn.tag = STViewTagBeautyBtn;
        
        STWeakSelf;
        
        _beautyBtn.tapBlock = ^{
            [weakSelf clickBottomViewButton:weakSelf.beautyBtn];
        };
    }
    return _beautyBtn;
}

- (UIView *)specialEffectsContainerView {
    if (!_specialEffectsContainerView) {
        _specialEffectsContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 230)];
        _specialEffectsContainerView.backgroundColor = [UIColor clearColor];
        
        UIView *noneStickerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 57, 40)];
        noneStickerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        noneStickerView.layer.shadowColor = UIColorFromRGB(0x141618).CGColor;
        noneStickerView.layer.shadowOpacity = 0.5;
        noneStickerView.layer.shadowOffset = CGSizeMake(3, 3);
        
        UIImage *image = [UIImage imageNamed:@"none_sticker.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake((57 - image.size.width) / 2, (40 - image.size.height) / 2, image.size.width, image.size.height)];
        imageView.contentMode = UIViewContentModeCenter;
        imageView.image = image;
        imageView.highlightedImage = [UIImage imageNamed:@"none_sticker_selected.png"];
        _noneStickerImageView = imageView;
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapNoneSticker:)];
        [noneStickerView addGestureRecognizer:tapGesture];
        
        [noneStickerView addSubview:imageView];
        
        UIView *whiteLineView = [[UIView alloc] initWithFrame:CGRectMake(56, 3, 1, 34)];
        whiteLineView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        [noneStickerView addSubview:whiteLineView];
        
        UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, SCREEN_WIDTH, 1)];
        lineView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        [_specialEffectsContainerView addSubview:lineView];
        
        [_specialEffectsContainerView addSubview:noneStickerView];
        [_specialEffectsContainerView addSubview:self.scrollTitleView];
        [_specialEffectsContainerView addSubview:self.collectionView];
        [_specialEffectsContainerView addSubview:self.objectTrackCollectionView];
        
        UIView *blankView = [[UIView alloc] initWithFrame:CGRectMake(0, 181, SCREEN_WIDTH, 50)];
        blankView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [_specialEffectsContainerView addSubview:blankView];
    }
    return _specialEffectsContainerView;
}

- (UIView *)beautyContainerView {
    
    if (!_beautyContainerView) {
        _beautyContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 180)];
        _beautyContainerView.backgroundColor = [UIColor clearColor];
        [_beautyContainerView addSubview:self.beautyScrollTitleView];
        
        UIView *whiteLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, SCREEN_WIDTH, 1)];
        whiteLineView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        [_beautyContainerView addSubview:whiteLineView];
        
        [_beautyContainerView addSubview:self.filterCategoryView];
        [_beautyContainerView addSubview:self.filterView];

        [_beautyContainerView addSubview:self.beautyBaseView];
        [_beautyContainerView addSubview:self.beautyShapeView];
        
        [self.arrBeautyViews addObject:self.beautyBaseView];
        [self.arrBeautyViews addObject:self.beautyShapeView];
        [self.arrBeautyViews addObject:self.filterCategoryView];
        [self.arrBeautyViews addObject:self.filterView];
    }
    return _beautyContainerView;
}

- (STFilterView *)filterView {
    
    if (!_filterView) {
        _filterView = [[STFilterView alloc] initWithFrame:CGRectMake(SCREEN_WIDTH, 41, SCREEN_WIDTH, 190)];
        _filterView.leftView.imageView.image = [UIImage imageNamed:@"still_life_highlighted"];
        _filterView.leftView.titleLabel.text = @"静物";
        _filterView.leftView.titleLabel.textColor = [UIColor whiteColor];
        
        _filterView.filterCollectionView.arrSceneryFilterModels = [self getFilterModelsByType:STEffectsTypeFilterScenery];
        _filterView.filterCollectionView.arrPortraitFilterModels = [self getFilterModelsByType:STEffectsTypeFilterPortrait];
        _filterView.filterCollectionView.arrStillLifeFilterModels = [self getFilterModelsByType:STEffectsTypeFilterStillLife];
        _filterView.filterCollectionView.arrDeliciousFoodFilterModels = [self getFilterModelsByType:STEffectsTypeFilterDeliciousFood];
        
        STWeakSelf;
        _filterView.filterCollectionView.delegateBlock = ^(STCollectionViewDisplayModel *model) {
            [weakSelf handleFilterChanged:model];
        };
        _filterView.block = ^{
            [UIView animateWithDuration:0.5 animations:^{
                weakSelf.filterCategoryView.frame = CGRectMake(0, weakSelf.filterCategoryView.frame.origin.y, SCREEN_WIDTH, 190);
                weakSelf.filterView.frame = CGRectMake(SCREEN_WIDTH, weakSelf.filterView.frame.origin.y, SCREEN_WIDTH, 190);
            }];
            weakSelf.filterStrengthView.hidden = YES;
        };
    }
    return _filterView;
}

- (UIView *)filterCategoryView {
    
    if (!_filterCategoryView) {
        
        _filterCategoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 190)];
        _filterCategoryView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];

        
        STViewButton *portraitViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        portraitViewBtn.tag = STEffectsTypeFilterPortrait;
        portraitViewBtn.backgroundColor = [UIColor clearColor];
        portraitViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 - 143, 28, 33, 60);
        portraitViewBtn.imageView.image = [UIImage imageNamed:@"portrait"];
        portraitViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"portrait_highlighted"];
        portraitViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        portraitViewBtn.titleLabel.textColor = [UIColor whiteColor];
        portraitViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        portraitViewBtn.titleLabel.text = @"人物";
        
        for (UIGestureRecognizer *recognizer in portraitViewBtn.gestureRecognizers) {
            [portraitViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *portraitRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [portraitViewBtn addGestureRecognizer:portraitRecognizer];
        [self.arrFilterCategoryViews addObject:portraitViewBtn];
        [_filterCategoryView addSubview:portraitViewBtn];
        
        
        
        STViewButton *sceneryViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        sceneryViewBtn.tag = STEffectsTypeFilterScenery;
        sceneryViewBtn.backgroundColor = [UIColor clearColor];
        sceneryViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 - 60, 28, 33, 60);
        sceneryViewBtn.imageView.image = [UIImage imageNamed:@"scenery"];
        sceneryViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"scenery_highlighted"];
        sceneryViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        sceneryViewBtn.titleLabel.textColor = [UIColor whiteColor];
        sceneryViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        sceneryViewBtn.titleLabel.text = @"风景";
        
        for (UIGestureRecognizer *recognizer in sceneryViewBtn.gestureRecognizers) {
            [sceneryViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *sceneryRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [sceneryViewBtn addGestureRecognizer:sceneryRecognizer];
        [self.arrFilterCategoryViews addObject:sceneryViewBtn];
        [_filterCategoryView addSubview:sceneryViewBtn];
        
        
        
        STViewButton *stillLifeViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        stillLifeViewBtn.tag = STEffectsTypeFilterStillLife;
        stillLifeViewBtn.backgroundColor = [UIColor clearColor];
        stillLifeViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 + 27, 28, 33, 60);
        stillLifeViewBtn.imageView.image = [UIImage imageNamed:@"still_life"];
        stillLifeViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"still_life_highlighted"];
        stillLifeViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        stillLifeViewBtn.titleLabel.textColor = [UIColor whiteColor];
        stillLifeViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        stillLifeViewBtn.titleLabel.text = @"静物";
        
        for (UIGestureRecognizer *recognizer in stillLifeViewBtn.gestureRecognizers) {
            [stillLifeViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *stillLifeRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [stillLifeViewBtn addGestureRecognizer:stillLifeRecognizer];
        [self.arrFilterCategoryViews addObject:stillLifeViewBtn];
        [_filterCategoryView addSubview:stillLifeViewBtn];
        
        
        
        STViewButton *deliciousFoodViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        deliciousFoodViewBtn.tag = STEffectsTypeFilterDeliciousFood;
        deliciousFoodViewBtn.backgroundColor = [UIColor clearColor];
        deliciousFoodViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 + 110, 28, 33, 60);
        deliciousFoodViewBtn.imageView.image = [UIImage imageNamed:@"delicious_food"];
        deliciousFoodViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"delicious_food_highlighted"];
        deliciousFoodViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        deliciousFoodViewBtn.titleLabel.textColor = [UIColor whiteColor];
        deliciousFoodViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        deliciousFoodViewBtn.titleLabel.text = @"美食";
        
        for (UIGestureRecognizer *recognizer in deliciousFoodViewBtn.gestureRecognizers) {
            [deliciousFoodViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *deliciousFoodRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [deliciousFoodViewBtn addGestureRecognizer:deliciousFoodRecognizer];
        [self.arrFilterCategoryViews addObject:deliciousFoodViewBtn];
        [_filterCategoryView addSubview:deliciousFoodViewBtn];
        
    }
    return _filterCategoryView;
}

- (void)switchFilterType:(UITapGestureRecognizer *)recognizer {
    
    [UIView animateWithDuration:0.5 animations:^{
        self.filterCategoryView.frame = CGRectMake(-SCREEN_WIDTH, self.filterCategoryView.frame.origin.y, SCREEN_WIDTH, 190);
        self.filterView.frame = CGRectMake(0, self.filterView.frame.origin.y, SCREEN_WIDTH, 190);
    }];
    
    if (self.currentSelectedFilterModel.modelType == recognizer.view.tag && self.currentSelectedFilterModel.isSelected) {
        self.filterStrengthView.hidden = NO;
    } else {
        self.filterStrengthView.hidden = YES;
    }
    
//    self.filterStrengthView.hidden = !(self.currentSelectedFilterModel.modelType == recognizer.view.tag);
    
    switch (recognizer.view.tag) {
            
        case STEffectsTypeFilterPortrait:
            
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"portrait_highlighted"];
            _filterView.leftView.titleLabel.text = @"人物";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrPortraitFilterModels;
            
            break;
            
        
        case STEffectsTypeFilterScenery:
            
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"scenery_highlighted"];
            _filterView.leftView.titleLabel.text = @"风景";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrSceneryFilterModels;
            
            break;
            
        case STEffectsTypeFilterStillLife:
            
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"still_life_highlighted"];
            _filterView.leftView.titleLabel.text = @"静物";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrStillLifeFilterModels;
            
            break;
            
        case STEffectsTypeFilterDeliciousFood:
            
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"delicious_food_highlighted"];
            _filterView.leftView.titleLabel.text = @"美食";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrDeliciousFoodFilterModels;
            
            break;
            
        default:
            break;
    }
    
    [_filterView.filterCollectionView reloadData];
}

- (void)refreshFilterCategoryState:(STEffectsType)type {
    
    for (int i = 0; i < self.arrFilterCategoryViews.count; ++i) {
        
        if (self.arrFilterCategoryViews[i].highlighted) {
            self.arrFilterCategoryViews[i].highlighted = NO;
        }
    }
    
    switch (type) {
        case STEffectsTypeFilterPortrait:
            
            self.arrFilterCategoryViews[0].highlighted = YES;
            
            break;
            
        case STEffectsTypeFilterScenery:
            
            self.arrFilterCategoryViews[1].highlighted = YES;
            
            break;
            
        case STEffectsTypeFilterStillLife:
            
            self.arrFilterCategoryViews[2].highlighted = YES;
            
            break;
            
        case STEffectsTypeFilterDeliciousFood:
            
            self.arrFilterCategoryViews[3].highlighted = YES;
            
            break;
            
        default:
            break;
    }
}

- (STScrollTitleView *)beautyScrollTitleView {
    if (!_beautyScrollTitleView) {
        
        STWeakSelf;
        
        _beautyScrollTitleView = [[STScrollTitleView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 40) titles:@[@"滤镜", @"基础美颜", @"美形"] effectsType:@[@(STEffectsTypeBeautyFilter), @(STEffectsTypeBeautyBase), @(STEffectsTypeBeautyShape)] titleOnClick:^(STTitleViewItem *titleView, NSInteger index, STEffectsType type) {
            [weakSelf handleEffectsType:type];
        }];
        _beautyScrollTitleView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _beautyScrollTitleView;
}

- (STScrollTitleView *)scrollTitleView {
    if (!_scrollTitleView) {
        
        STWeakSelf;

        _scrollTitleView = [[STScrollTitleView alloc] initWithFrame:CGRectMake(57, 0, SCREEN_WIDTH - 57, 40) normalImages:[self getNormalImages] selectedImages:[self getSelectedImages] effectsType:@[@(STEffectsTypeSticker2D), @(STEffectsTypeSticker3D), @(STEffectsTypeStickerGesture), @(STEffectsTypeStickerSegment), @(STEffectsTypeStickerFaceDeformation), @(STEffectsTypeStickerFaceChange), @(STEffectsTypeObjectTrack)] titleOnClick:^(STTitleViewItem *titleView, NSInteger index, STEffectsType type) {
            [weakSelf handleEffectsType:type];
        }];
        
        _scrollTitleView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _scrollTitleView;
}

- (STCollectionView *)collectionView {
    if (!_collectionView) {
        
        __weak typeof(self) weakSelf = self;
        _collectionView = [[STCollectionView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 140) withModels:nil andDelegateBlock:^(STCollectionViewDisplayModel *model) {
            
            [weakSelf handleStickerChanged:model];
        }];
        
        _collectionView.arr2DModels = self.arr2DStickers;
        _collectionView.arr3DModels = self.arr3DStickers;
        _collectionView.arrGestureModels = self.arrGestureStickers;
        _collectionView.arrSegmentModels = self.arrSegmentStickers;
        _collectionView.arrFaceDeformationModels = self.arrFacedeformationStickers;
        
        _collectionView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        
    }
    return _collectionView;
}

- (STCollectionView *)objectTrackCollectionView {
    if (!_objectTrackCollectionView) {
        
        __weak typeof(self) weakSelf = self;
        _objectTrackCollectionView = [[STCollectionView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 140) withModels:nil andDelegateBlock:^(STCollectionViewDisplayModel *model) {
            [weakSelf handleObjectTrackChanged:model];
        }];
        
        _objectTrackCollectionView.arrModels = self.arrObjectTrackers;
        _objectTrackCollectionView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _objectTrackCollectionView;
}

- (UIView *)beautyShapeView {
    
    if (!_beautyShapeView) {
        
        _beautyShapeView = [[UIView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 190)];
        
        STSliderView *thinFaceView = [[[NSBundle mainBundle] loadNibNamed:@"STSliderView" owner:nil options:nil] firstObject];
        thinFaceView.frame = CGRectMake(0, 5, SCREEN_WIDTH, 35);
        thinFaceView.backgroundColor = [UIColor clearColor];
        thinFaceView.imageView.image = [UIImage imageNamed:@"thin_face.png"];
        thinFaceView.titleLabel.textColor = UIColorFromRGB(0xffffff);
        thinFaceView.titleLabel.font = [UIFont systemFontOfSize:11];
        thinFaceView.titleLabel.text = @"瘦脸";
        
        thinFaceView.minLabel.textColor = UIColorFromRGB(0xffffff);
        thinFaceView.minLabel.font = [UIFont systemFontOfSize:15];
        thinFaceView.minLabel.text = @"";
        
        thinFaceView.maxLabel.textColor = UIColorFromRGB(0xffffff);
        thinFaceView.maxLabel.font = [UIFont systemFontOfSize:15];
        
        thinFaceView.slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        thinFaceView.slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        thinFaceView.slider.maximumValue = 100;
        [thinFaceView.slider addTarget:self action:@selector(beautifySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        thinFaceView.slider.tag = STViewTagShrinkFaceSlider;
        _thinFaceView = thinFaceView;
        
        
        STSliderView *enlargeEyesView = [[[NSBundle mainBundle] loadNibNamed:@"STSliderView" owner:nil options:nil] firstObject];
        enlargeEyesView.frame = CGRectMake(0, 40, SCREEN_WIDTH, 35);
        enlargeEyesView.backgroundColor = [UIColor clearColor];
        enlargeEyesView.imageView.image = [UIImage imageNamed:@"enlarge_eyes.png"];
        enlargeEyesView.titleLabel.textColor = UIColorFromRGB(0xffffff);
        enlargeEyesView.titleLabel.font = [UIFont systemFontOfSize:11];
        enlargeEyesView.titleLabel.text = @"大眼";
        
        enlargeEyesView.minLabel.textColor = UIColorFromRGB(0xffffff);
        enlargeEyesView.minLabel.font = [UIFont systemFontOfSize:15];
        enlargeEyesView.minLabel.text = @"";
        
        enlargeEyesView.maxLabel.textColor = UIColorFromRGB(0xffffff);
        enlargeEyesView.maxLabel.font = [UIFont systemFontOfSize:15];
        
        enlargeEyesView.slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        enlargeEyesView.slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        enlargeEyesView.slider.maximumValue = 100;
        [enlargeEyesView.slider addTarget:self action:@selector(beautifySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        enlargeEyesView.slider.tag = STViewTagEnlargeEyeSlider;
        _enlargeEyesView = enlargeEyesView;
        
        
        
        STSliderView *smallFaceView = [[[NSBundle mainBundle] loadNibNamed:@"STSliderView" owner:nil options:nil] firstObject];
        smallFaceView.frame = CGRectMake(0, 75, SCREEN_WIDTH, 35);
        smallFaceView.backgroundColor = [UIColor clearColor];
        smallFaceView.imageView.image = [UIImage imageNamed:@"small_face.png"];
        smallFaceView.titleLabel.textColor = UIColorFromRGB(0xffffff);
        smallFaceView.titleLabel.font = [UIFont systemFontOfSize:11];
        smallFaceView.titleLabel.text = @"小脸";
        
        smallFaceView.minLabel.textColor = UIColorFromRGB(0xffffff);
        smallFaceView.minLabel.font = [UIFont systemFontOfSize:15];
        smallFaceView.minLabel.text = @"";
        
        smallFaceView.maxLabel.textColor = UIColorFromRGB(0xffffff);
        smallFaceView.maxLabel.font = [UIFont systemFontOfSize:15];
        
        smallFaceView.slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        smallFaceView.slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        smallFaceView.slider.maximumValue = 100;
        [smallFaceView.slider addTarget:self action:@selector(beautifySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        smallFaceView.slider.tag = STViewTagShrinkJawSlider;
        _smallFaceView = smallFaceView;
        
        [_beautyShapeView addSubview:thinFaceView];
        [_beautyShapeView addSubview:enlargeEyesView];
        [_beautyShapeView addSubview:smallFaceView];
        
        _beautyShapeView.hidden = YES;
        _beautyShapeView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _beautyShapeView;
}

- (UIView *)beautyBaseView {
    
    if (!_beautyBaseView) {
        
        _beautyBaseView = [[UIView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 190)];
        
        STSliderView *dermabrasionView = [[[NSBundle mainBundle] loadNibNamed:@"STSliderView" owner:nil options:nil] firstObject];
        dermabrasionView.frame = CGRectMake(0, 5, SCREEN_WIDTH, 35);
        dermabrasionView.backgroundColor = [UIColor clearColor];
        dermabrasionView.imageView.image = [UIImage imageNamed:@"mopi.png"];
        dermabrasionView.titleLabel.textColor = [UIColor whiteColor];
        dermabrasionView.titleLabel.font = [UIFont systemFontOfSize:11];
        dermabrasionView.titleLabel.text = @"磨皮";
        
        dermabrasionView.minLabel.textColor = UIColorFromRGB(0x555555);
        dermabrasionView.minLabel.font = [UIFont systemFontOfSize:15];
        dermabrasionView.minLabel.text = @"";
        
        dermabrasionView.maxLabel.textColor = [UIColor whiteColor];
        dermabrasionView.maxLabel.font = [UIFont systemFontOfSize:15];
        
        dermabrasionView.slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        dermabrasionView.slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        dermabrasionView.slider.maximumValue = 100;
        [dermabrasionView.slider addTarget:self action:@selector(beautifySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        dermabrasionView.slider.tag = STViewTagSmoothSlider;
        _dermabrasionView = dermabrasionView;
        
        
        STSliderView *ruddyView = [[[NSBundle mainBundle] loadNibNamed:@"STSliderView" owner:nil options:nil] firstObject];
        ruddyView.frame = CGRectMake(0, 40, SCREEN_WIDTH, 35);
        ruddyView.backgroundColor = [UIColor clearColor];
        ruddyView.imageView.image = [UIImage imageNamed:@"hongrun.png"];
        ruddyView.titleLabel.textColor = [UIColor whiteColor];
        ruddyView.titleLabel.font = [UIFont systemFontOfSize:11];
        ruddyView.titleLabel.text = @"红润";
        
        ruddyView.minLabel.textColor = UIColorFromRGB(0x555555);
        ruddyView.minLabel.font = [UIFont systemFontOfSize:15];
        ruddyView.minLabel.text = @"";
        
        ruddyView.maxLabel.textColor = [UIColor whiteColor];
        ruddyView.maxLabel.font = [UIFont systemFontOfSize:15];
        
        ruddyView.slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        ruddyView.slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        ruddyView.slider.maximumValue = 100;
        [ruddyView.slider addTarget:self action:@selector(beautifySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        ruddyView.slider.tag = STViewTagReddenSlider;
        _ruddyView = ruddyView;
        
        
        STSliderView *whitenView = [[[NSBundle mainBundle] loadNibNamed:@"STSliderView" owner:nil options:nil] firstObject];
        whitenView.frame = CGRectMake(0, 75, SCREEN_WIDTH, 40);
        whitenView.backgroundColor = [UIColor clearColor];
        whitenView.imageView.image = [UIImage imageNamed:@"meibai.png"];
        
        whitenView.titleLabel.textColor = [UIColor whiteColor];
        whitenView.titleLabel.font = [UIFont systemFontOfSize:11];
        whitenView.titleLabel.text = @"美白";
        
        whitenView.minLabel.textColor = UIColorFromRGB(0x555555);
        whitenView.minLabel.font = [UIFont systemFontOfSize:15];
        whitenView.minLabel.text = @"";
        
        whitenView.maxLabel.textColor = [UIColor whiteColor];
        whitenView.maxLabel.font = [UIFont systemFontOfSize:15];
        
        whitenView.slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        whitenView.slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        whitenView.slider.maximumValue = 100;
        [whitenView.slider addTarget:self action:@selector(beautifySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        whitenView.slider.tag = STViewTagWhitenSlider;
        _whitenView = whitenView;
        
        
        [_beautyBaseView addSubview:dermabrasionView];
        [_beautyBaseView addSubview:ruddyView];
        [_beautyBaseView addSubview:whitenView];
        
        _beautyBaseView.hidden = YES;
        _beautyBaseView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _beautyBaseView;
}

- (STTriggerView *)triggerView {
    
    if (!_triggerView) {
        
        _triggerView = [[STTriggerView alloc] init];
    }
    
    return _triggerView;
}

- (UIView *)filterStrengthView {
    
    if (!_filterStrengthView) {
        
        _filterStrengthView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT - 230 - 35.5, SCREEN_WIDTH, 35.5)];
        _filterStrengthView.backgroundColor = [UIColor clearColor];
        _filterStrengthView.hidden = YES;
        
        UILabel *leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 10, 35.5)];
        leftLabel.textColor = [UIColor whiteColor];
        leftLabel.font = [UIFont systemFontOfSize:11];
        leftLabel.text = @"0";
        [_filterStrengthView addSubview:leftLabel];
        
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(40, 0, SCREEN_WIDTH - 90, 35.5)];
        slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        slider.maximumTrackTintColor = [UIColor whiteColor];
        slider.value = 1;
        [slider addTarget:self action:@selector(filterSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        _filterStrengthSlider = slider;
        [_filterStrengthView addSubview:slider];
        
        UILabel *rightLabel = [[UILabel alloc] initWithFrame:CGRectMake(SCREEN_WIDTH - 40, 0, 20, 35.5)];
        rightLabel.textColor = [UIColor whiteColor];
        rightLabel.font = [UIFont systemFontOfSize:11];
        rightLabel.text = @"100";
        _lblFilterStrength = rightLabel;
        [_filterStrengthView addSubview:rightLabel];
    }
    return _filterStrengthView;
}

#pragma mark - scroll title click events

- (void)onTapNoneSticker:(UITapGestureRecognizer *)tapGesture {
    
    [self cancelStickerAndObjectTrack];
    
    self.noneStickerImageView.highlighted = YES;
}

- (void)cancelStickerAndObjectTrack {
    
    self.collectionView.selectedModel.isSelected = NO;
    self.objectTrackCollectionView.selectedModel.isSelected = NO;
    
    [self.collectionView reloadData];
    [self.objectTrackCollectionView reloadData];
    
    self.collectionView.selectedModel = nil;
    self.objectTrackCollectionView.selectedModel = nil;

    if (_hSticker) {
        self.isNullSticker = YES;
    }
    
    if (_hTracker) {
        
        if (self.commonObjectContainerView.currentCommonObjectView) {
            
            [self.commonObjectContainerView.currentCommonObjectView removeFromSuperview];
        }
    }
    
    self.bTracker = NO;
    
}

- (void)handleEffectsType:(STEffectsType)type {
    
    switch (type) {
            
        case STEffectsTypeSticker2D:
            self.objectTrackCollectionView.hidden = YES;
            self.collectionView.hidden = NO;
            self.collectionView.arrModels = self.arr2DStickers;
            [self.collectionView reloadData];
            break;
            
        case STEffectsTypeStickerFaceDeformation:
            self.objectTrackCollectionView.hidden = YES;
            self.collectionView.hidden = NO;
            self.collectionView.arrModels = self.arrFacedeformationStickers;
            [self.collectionView reloadData];
            break;
            
        case STEffectsTypeStickerSegment:
            self.objectTrackCollectionView.hidden = YES;
            self.collectionView.hidden = NO;
            self.collectionView.arrModels = self.arrSegmentStickers;
            [self.collectionView reloadData];
            break;
            
        case STEffectsTypeStickerGesture:
            self.objectTrackCollectionView.hidden = YES;
            self.collectionView.hidden = NO;
            self.collectionView.arrModels = self.arrGestureStickers;
            [self.collectionView reloadData];
            break;
            
        case STEffectsTypeSticker3D:
            self.objectTrackCollectionView.hidden = YES;
            self.collectionView.hidden = NO;
            self.collectionView.arrModels = self.arr3DStickers;
            [self.collectionView reloadData];
            break;
            
        case STEffectsTypeObjectTrack:
            
            [self resetCommonObjectViewPosition];
            
            self.objectTrackCollectionView.arrModels = self.arrObjectTrackers;
            self.objectTrackCollectionView.hidden = NO;
            self.collectionView.hidden = YES;
            [self.objectTrackCollectionView reloadData];
            break;
            
        case STEffectsTypeStickerFaceChange:
            
            self.objectTrackCollectionView.hidden = YES;
            self.collectionView.hidden = NO;
            self.collectionView.arrModels = self.arrFaceChangeStickers;
            [self.collectionView reloadData];
            
            break;
        case STEffectsTypeBeautyFilter:
        {
            self.beautyBaseView.hidden = YES;
            self.beautyShapeView.hidden = YES;
            self.filterCategoryView.hidden = NO;
            self.filterView.hidden = NO;
            
            self.filterCategoryView.center = CGPointMake(SCREEN_WIDTH / 2, self.filterCategoryView.center.y);
            self.filterView.center = CGPointMake(SCREEN_WIDTH * 3 / 2, self.filterView.center.y);
            
        }
            break;
            
        case STEffectsTypeNone:
            break;
            
        case STEffectsTypeBeautyShape:
        {
            [self hideBeautyViewExcept:self.beautyShapeView];
            self.filterStrengthView.hidden = YES;
        }
            break;
            
        case STEffectsTypeBeautyBase:
        {
            self.filterStrengthView.hidden = YES;
            [self hideBeautyViewExcept:self.beautyBaseView];
        }
            break;
            
        default:
            break;
    }
    
}

#pragma mark - collectionview click events

- (void)handleFilterChanged:(STCollectionViewDisplayModel *)model {
    
    self.currentSelectedFilterModel = model;
    
    self.lblFilterStrength.text = @"100";
    
    self.bFilter = model.index > 0;
    
    if (self.bFilter) {
        self.filterStrengthView.hidden = NO;
    } else {
        self.filterStrengthView.hidden = YES;
    }
    
    // 切换滤镜
    if (_hFilter) {
        
        // 切换滤镜不会修改强度 , 这里根据实际需求实现 , 这里重置为1.0.
        self.fFilterStrength = 1.0;
        self.filterStrengthSlider.value = 1.0;
        
        self.curFilterModelPath = model.strPath;
        [self refreshFilterCategoryState:model.modelType];
        st_result_t iRet = st_mobile_gl_filter_set_param(_hFilter, ST_GL_FILTER_STRENGTH, self.fFilterStrength);
        if (iRet != ST_OK) {
            STLog(@"st_mobile_gl_filter_set_param %d" , iRet);
        }
    }
}

- (void)handleObjectTrackChanged:(STCollectionViewDisplayModel *)model {
    
    if (self.collectionView.selectedModel || self.objectTrackCollectionView.selectedModel) {
        self.noneStickerImageView.highlighted = NO;
    } else {
        self.noneStickerImageView.highlighted = YES;
    }
    
    if (self.commonObjectContainerView.currentCommonObjectView) {
        [self.commonObjectContainerView.currentCommonObjectView removeFromSuperview];
    }
    _commonObjectViewSetted = NO;
    _commonObjectViewAdded = NO;
    
    if (model.isSelected) {
        UIImage *image = model.image;
        [self.commonObjectContainerView addCommonObjectViewWithImage:image];
        self.commonObjectContainerView.currentCommonObjectView.onFirst = YES;
        self.bTracker = YES;
    }
}

- (void)handleStickerChanged:(STCollectionViewDisplayModel *)model {
    
    if (self.collectionView.selectedModel || self.objectTrackCollectionView.selectedModel) {
        self.noneStickerImageView.highlighted = NO;
    } else {
        self.noneStickerImageView.highlighted = YES;
    }
    
    self.bSticker = YES;
    
    if ([EAGLContext currentContext] != self.glContext) {
        
        [EAGLContext setCurrentContext:self.glContext];
    }
    
    self.triggerView.hidden = YES;
    
    // 需要保证 SDK 的线程安全 , 顺序调用.
    dispatch_async(self.changeStickerQueue, ^{
        
        if (self.isNullSticker) {
            self.isNullSticker = NO;
        }
        
        // 获取触发动作类型
        unsigned long long iAction = 0;
        
        const char *stickerPath = [model.strPath UTF8String];
        
        if (!model.isSelected) {
            stickerPath = NULL;
        }
        
        st_result_t iRet = st_mobile_sticker_change_package(_hSticker, stickerPath);
        
        if (iRet != ST_OK) {
            
            STLog(@"st_mobile_sticker_change_package error %d" , iRet);
        }else{
            
            // 需要在 st_mobile_sticker_change_package 之后调用才可以获取新素材包的 trigger action .
            iRet = st_mobile_sticker_get_trigger_action(_hSticker, &iAction);
            
            if (ST_OK != iRet) {
                
                STLog(@"st_mobile_sticker_get_trigger_action error %d" , iRet);
                
                return;
            }
            
            if (0 != iAction) {//有 trigger信息
                if (CHECK_FLAG(iAction, ST_MOBILE_BROW_JUMP)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeMoveEyebrow];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_EYE_BLINK)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeBlink];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HEAD_YAW)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeTurnHead];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HEAD_PITCH)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeNod];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_MOUTH_AH)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeOpenMouse];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_GOOD)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandGood];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_PALM)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandPalm];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_LOVE)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandLove];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_HOLDUP)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandHoldUp];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_CONGRATULATE)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandCongratulate];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_FINGER_HEART)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandFingerHeart];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_FINGER_INDEX)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandFingerIndex];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_OK)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandOK];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_SCISSOR)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandScissor];
                }
                if (CHECK_FLAG(iAction, ST_MOBILE_HAND_PISTOL)) {
                    [self.triggerView showTriggerViewWithType:STTriggerTypeHandPistol];
                }
            }
        }
        
        self.iCurrentAction = iAction;
    });
    
    self.strStickerPath = model.strPath;
}

- (void)clickBottomViewButton:(STViewButton *)senderView {

    switch (senderView.tag) {

        case STViewTagSpecialEffectsBtn:
            
            self.beautyBtn.userInteractionEnabled = NO;
            
            if (!self.specialEffectsContainerViewIsShow) {
                
                [self hideBeautyContainerView];
                [self containerViewAppear];
                
            } else {
                
                [self hideContainerView];
            }
            
            self.beautyBtn.userInteractionEnabled = YES;
            
            break;
            
        case STViewTagBeautyBtn:
            
            self.specialEffectsBtn.userInteractionEnabled = NO;
            
            if (!self.beautyContainerViewIsShow) {
                
                [self hideContainerView];
                [self beautyContainerViewAppear];
                
            } else {
                
                [self hideBeautyContainerView];
            }

            self.specialEffectsBtn.userInteractionEnabled = YES;
            
            break;
    }
    
}

- (void)addBodyModel {
    
    dispatch_async(self.changeModelQueue, ^{
        
        NSString *strBodyModelPath = [[NSBundle mainBundle] pathForResource:@"body" ofType:@"model"];
        st_result_t iRet = st_mobile_human_action_add_sub_model(_hDetector, strBodyModelPath.UTF8String);
        self.iCurrentAction |= ST_MOBILE_BODY_KEYPOINTS;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action add body model failed: %d", iRet);
        }
        
    });
    
}

- (void)deleteBodyModel {
    dispatch_async(self.changeModelQueue, ^{
        st_result_t iRet = st_mobile_human_action_remove_model_by_config(_hDetector, ST_MOBILE_ENABLE_BODY_KEYPOINTS);
        self.iCurrentAction &= ~ST_MOBILE_BODY_KEYPOINTS;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action remove body model failed: %d", iRet);
        }
    });
}

- (void)addFaceExtraModel {
    dispatch_async(self.changeModelQueue, ^{
        NSString *strFaceExtraModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Face_Extra_5.1.0" ofType:@"model"];
        st_result_t iRet = st_mobile_human_action_add_sub_model(_hDetector, strFaceExtraModelPath.UTF8String);
        self.iCurrentAction |= ST_MOBILE_DETECT_EXTRA_FACE_POINTS;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action add face extra model failed: %d", iRet);
        }
        
    });
}

- (void)deleteFaceExtraModel {
    
    dispatch_async(self.changeModelQueue, ^{
        st_result_t iRet = st_mobile_human_action_remove_model_by_config(_hDetector, ST_MOBILE_ENABLE_FACE_EXTRA_DETECT);
        self.iCurrentAction &= ~ST_MOBILE_DETECT_EXTRA_FACE_POINTS;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action remove face extra model failed: %d", iRet);
        }
    });
}

- (void)addEyeIrisModel {
    
    dispatch_async(self.changeModelQueue, ^{
        
        NSString *strEyeIrisModel = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Iris_1.7.0" ofType:@"model"];
        st_result_t iRet = st_mobile_human_action_add_sub_model(_hDetector, strEyeIrisModel.UTF8String);
        self.iCurrentAction |= ST_MOBILE_DETECT_EYEBALL_CONTOUR;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action add eye iris model failed: %d", iRet);
        }
    });
}

- (void)deleteEyeIrisModel {
    
    dispatch_async(self.changeModelQueue, ^{
        st_result_t iRet = st_mobile_human_action_remove_model_by_config(_hDetector, ST_MOBILE_ENABLE_EYEBALL_CONTOUR_DETECT);
        self.iCurrentAction &= ~ST_MOBILE_DETECT_EYEBALL_CONTOUR;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action remove eye iris model failed: %d", iRet);
        }
    });
}

- (void)addHandModel {
    
    dispatch_async(self.changeModelQueue, ^{
        
        NSString *strHandModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Hand_5.0.0" ofType:@"model"];
        st_result_t iRet = st_mobile_human_action_add_sub_model(_hDetector, strHandModelPath.UTF8String);
        self.iCurrentAction |= ST_MOBILE_HAND_DETECT_FULL;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action add hand model failed: %d", iRet);
        }
    });
    
}

- (void)delHandModel {
    dispatch_async(self.changeModelQueue, ^{
        st_result_t iRet = st_mobile_human_action_remove_model_by_config(_hDetector, ST_MOBILE_ENABLE_HAND_DETECT);
        self.iCurrentAction &= ~ST_MOBILE_HAND_DETECT_FULL;
        if (iRet != ST_OK) {
            NSLog(@"st mobile human action remove hand model failed: %d", iRet);
        }
    });
}

#pragma mark - get models

- (NSArray *)getStickerModelsByType:(STEffectsType)type {
    
    NSArray *stickerZipPaths = [STParamUtil getStickerPathsByType:type];
    
    NSMutableArray *arrModels = [NSMutableArray array];
    
    for (int i = 0; i < stickerZipPaths.count; i ++) {
        
        STCollectionViewDisplayModel *model = [[STCollectionViewDisplayModel alloc] init];
        model.strPath = stickerZipPaths[i];
        
        UIImage *thumbImage = [UIImage imageWithContentsOfFile:[[model.strPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]];
        model.image = thumbImage ? thumbImage : [UIImage imageNamed:@"none.png"];
        model.strName = @"";
        model.index = i;
        model.isSelected = NO;
        model.modelType = type;
        
        [arrModels addObject:model];
    }
    return [arrModels copy];
}

- (NSArray *)getFilterModelsByType:(STEffectsType)type {
    
    NSArray *filterModelPath = [STParamUtil getFilterModelPathsByType:type];
    
    NSMutableArray *arrModels = [NSMutableArray array];
    
    NSString *natureImageName = @"";
    switch (type) {
        case STEffectsTypeFilterDeliciousFood:
            natureImageName = @"nature_food";
            break;
            
        case STEffectsTypeFilterStillLife:
            natureImageName = @"nature_stilllife";
            break;
            
        case STEffectsTypeFilterScenery:
            natureImageName = @"nature_scenery";
            break;
            
        case STEffectsTypeFilterPortrait:
            natureImageName = @"nature_portrait";
            break;
            
        default:
            break;
    }
    
    STCollectionViewDisplayModel *model1 = [[STCollectionViewDisplayModel alloc] init];
    model1.strPath = NULL;
    model1.strName = @"original";
    model1.image = [UIImage imageNamed:natureImageName];
    model1.index = 0;
    model1.isSelected = NO;
    model1.modelType = STEffectsTypeNone;
    [arrModels addObject:model1];
    
    for (int i = 1; i < filterModelPath.count + 1; ++i) {
        
        STCollectionViewDisplayModel *model = [[STCollectionViewDisplayModel alloc] init];
        model.strPath = filterModelPath[i - 1];
        model.strName = [[model.strPath.lastPathComponent stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"filter_style_" withString:@""];
        
        UIImage *thumbImage = [UIImage imageWithContentsOfFile:[[model.strPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]];
        
        model.image = thumbImage ?: [UIImage imageNamed:@"none"];
        model.index = i;
        model.isSelected = NO;
        model.modelType = type;
        
        [arrModels addObject:model];
    }
    return [arrModels copy];
}

- (NSArray *)getObjectTrackModels {
    
    NSMutableArray *arrModels = [NSMutableArray array];
    
    NSArray *arrImageNames = @[@"object_track_happy", @"object_track_hi", @"object_track_love", @"object_track_star", @"object_track_sticker", @"object_track_sun"];
        
    for (int i = 0; i < arrImageNames.count; ++i) {
            
        STCollectionViewDisplayModel *model = [[STCollectionViewDisplayModel alloc] init];
        model.strPath = NULL;
        model.strName = @"";
        model.index = i;
        model.isSelected = NO;
        model.image = [UIImage imageNamed:arrImageNames[i]];
        model.modelType = STEffectsTypeObjectTrack;
        
        [arrModels addObject:model];
    }
    
    return [arrModels copy];
}

#pragma mark - help function

- (NSString*)getMobilePhoneModel
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    return platform;
}

- (NSArray *)getNormalImages {
    
    NSMutableArray *res = [NSMutableArray array];
    
    UIImage *sticker2d = [UIImage imageNamed:@"2d.png"];
    UIImage *sticker3d = [UIImage imageNamed:@"3d.png"];
    UIImage *stickerGesture = [UIImage imageNamed:@"sticker_gesture.png"];
    UIImage *stickerSegment = [UIImage imageNamed:@"sticker_segment.png"];
    UIImage *stickerDeformation = [UIImage imageNamed:@"sticker_face_deformation.png"];
    UIImage *objectTrack = [UIImage imageNamed:@"common_object_track.png"];
    UIImage *facePainting = [UIImage imageNamed:@"face_painting.png"];
    
    [res addObject:sticker2d];
    [res addObject:sticker3d];
    [res addObject:stickerGesture];
    [res addObject:stickerSegment];
    [res addObject:stickerDeformation];
    [res addObject:facePainting];
    [res addObject:objectTrack];
    
    return [res copy];
}

- (NSArray *)getSelectedImages {
    
    NSMutableArray *res = [NSMutableArray array];
    
    UIImage *sticker2d = [UIImage imageNamed:@"2d_selected.png"];
    UIImage *sticker3d = [UIImage imageNamed:@"3d_selected.png"];
    UIImage *stickerGesture = [UIImage imageNamed:@"sticker_gesture_selected.png"];
    UIImage *stickerSegment = [UIImage imageNamed:@"sticker_segment_selected.png"];
    UIImage *stickerDeformation = [UIImage imageNamed:@"sticker_face_deformation_selected.png"];
    UIImage *objectTrack = [UIImage imageNamed:@"common_object_track_selected.png"];
    UIImage *facePainting = [UIImage imageNamed:@"face_painting_selected.png"];

    [res addObject:sticker2d];
    [res addObject:sticker3d];
    [res addObject:stickerGesture];
    [res addObject:stickerSegment];
    [res addObject:stickerDeformation];
    [res addObject:facePainting];
    [res addObject:objectTrack];

    return [res copy];
}

- (CGFloat)layoutWidthWithValue:(CGFloat)value {
    
    return (value / 750) * SCREEN_WIDTH;
}

- (CGFloat)layoutHeightWithValue:(CGFloat)value {
    
    return (value / 1334) * SCREEN_HEIGHT;
}

#pragma mark - lazy load array

- (NSArray *)arr2DStickers {
    if (!_arr2DStickers) {
        _arr2DStickers = [self getStickerModelsByType:STEffectsTypeSticker2D];
    }
    return _arr2DStickers;
}

- (NSArray *)arr3DStickers {
    if (!_arr3DStickers) {
        _arr3DStickers = [self getStickerModelsByType:STEffectsTypeSticker3D];
    }
    return _arr3DStickers;
}

- (NSArray *)arrGestureStickers {
    if (!_arrGestureStickers) {
        _arrGestureStickers = [self getStickerModelsByType:STEffectsTypeStickerGesture];
    }
    return _arrGestureStickers;
}

- (NSArray *)arrSegmentStickers {
    if (!_arrSegmentStickers) {
        _arrSegmentStickers = [self getStickerModelsByType:STEffectsTypeStickerSegment];
    }
    return _arrSegmentStickers;
}

- (NSArray *)arrFacedeformationStickers {
    if (!_arrFacedeformationStickers) {
        _arrFacedeformationStickers = [self getStickerModelsByType:STEffectsTypeStickerFaceDeformation];
    }
    return _arrFacedeformationStickers;
}

- (NSArray *)arrObjectTrackers {
    if (!_arrObjectTrackers) {
        _arrObjectTrackers = [self getObjectTrackModels];
    }
    return _arrObjectTrackers;
}

- (NSArray *)arrFaceChangeStickers {
    
    if (!_arrFaceChangeStickers) {
        _arrFaceChangeStickers = [self getStickerModelsByType:STEffectsTypeStickerFaceChange];
    }
    return _arrFaceChangeStickers;
}

- (NSMutableArray *)arrBeautyViews {
    if (!_arrBeautyViews) {
        _arrBeautyViews = [NSMutableArray array];
    }
    return _arrBeautyViews;
}

- (NSMutableArray *)arrFilterCategoryViews {
    
    if (!_arrFilterCategoryViews) {
        
        _arrFilterCategoryViews = [NSMutableArray array];
    }
    return _arrFilterCategoryViews;
}

#pragma mark - animations

- (void)hideContainerView {
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        self.specialEffectsContainerView.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 180);
        
    } completion:^(BOOL finished) {
        self.specialEffectsContainerViewIsShow = NO;
    }];
    
    self.specialEffectsBtn.highlighted = NO;
}

- (void)containerViewAppear {
    
    self.filterStrengthView.hidden = YES;
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.specialEffectsContainerView.frame = CGRectMake(0, SCREEN_HEIGHT - 230, SCREEN_WIDTH, 180);
    } completion:^(BOOL finished) {
        self.specialEffectsContainerViewIsShow = YES;
    }];
    self.specialEffectsBtn.highlighted = YES;
}

- (void)hideBeautyContainerView {
    
    self.filterStrengthView.hidden = YES;
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        self.beautyContainerView.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 180);
        
    } completion:^(BOOL finished) {
        self.beautyContainerViewIsShow = NO;
    }];
    
    self.beautyBtn.highlighted = NO;
}

- (void)beautyContainerViewAppear {
    
    self.filterCategoryView.center = CGPointMake(SCREEN_WIDTH / 2, self.filterCategoryView.center.y);
    self.filterView.center = CGPointMake(SCREEN_WIDTH * 3 / 2, self.filterView.center.y);
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.beautyContainerView.frame = CGRectMake(0, SCREEN_HEIGHT - 230, SCREEN_WIDTH, 180);
    } completion:^(BOOL finished) {
        self.beautyContainerViewIsShow = YES;
    }];
    self.beautyBtn.highlighted = YES;
}

- (void)hideBeautyViewExcept:(UIView *)view {
    
    for (UIView *beautyView in self.arrBeautyViews) {
        
        beautyView.hidden = !(view == beautyView);
    }
}

#pragma mark - STCommonObjectContainerViewDelegate

- (void)commonObjectViewStartTrackingFrame:(CGRect)frame {
    
    _commonObjectViewAdded = YES;
    _commonObjectViewSetted = NO;
    
    CGRect rect = frame;
    _rect.left = (rect.origin.x + _margin) / _scale;
    _rect.top = rect.origin.y / _scale;
    _rect.right = (rect.origin.x + rect.size.width + _margin) / _scale;
    _rect.bottom = (rect.origin.y + rect.size.height) / _scale;
    
}

- (void)commonObjectViewFinishTrackingFrame:(CGRect)frame {
    _commonObjectViewAdded = NO;
}

#pragma mark -

- (void)resetCommonObjectViewPosition {
    if (self.commonObjectContainerView.currentCommonObjectView) {
        _commonObjectViewSetted = NO;
        _commonObjectViewAdded = NO;
        self.commonObjectContainerView.currentCommonObjectView.hidden = NO;
        self.commonObjectContainerView.currentCommonObjectView.onFirst = YES;
        self.commonObjectContainerView.currentCommonObjectView.center = CGPointMake(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2);
    }
}

- (void)resetSettings {
    self.noneStickerImageView.highlighted = YES;
    self.lblFilterStrength.text = @"100";
    self.filterStrengthSlider.value = 1;
    
    self.currentSelectedFilterModel.isSelected = NO;
    [self refreshFilterCategoryState:STEffectsTypeNone];
    
    self.fSmoothStrength = 0.74;
    self.fReddenStrength = 0.36;
    self.fWhitenStrength = 0.30;
    self.fEnlargeEyeStrength = 0.13;
    self.fShrinkFaceStrength = 0.11;
    self.fShrinkJawStrength = 0.10;
    
    self.thinFaceView.slider.value = 11;
    self.thinFaceView.maxLabel.text = @"11";
    
    self.enlargeEyesView.slider.value = 13;
    self.enlargeEyesView.maxLabel.text = @"13";
    
    self.smallFaceView.slider.value = 10;
    self.smallFaceView.maxLabel.text = @"10";
    
    self.dermabrasionView.slider.value = 74;
    self.dermabrasionView.maxLabel.text = @"74";
    
    self.ruddyView.slider.value = 36;
    self.ruddyView.maxLabel.text = @"36";
    
    self.whitenView.slider.value = 30;
    self.whitenView.maxLabel.text = @"30";
    
    self.preFilterModelPath = nil;
    self.curFilterModelPath = nil;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}



- (void)closeStFilter{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_textureInput removeOutputFramebuffer];
        [_textureInput removeAllTargets];
        _textureInput = nil;
        _textureOutput = nil;
        [self releaseResources];
        [_arrBeautyViews removeAllObjects];
        [_arrFilterCategoryViews removeAllObjects];
        [_normalImages removeAllObjects];
        [_selectedImages removeAllObjects];
        [_arrPersons removeAllObjects];
        [_arrPoints removeAllObjects];
        [_faceArray removeAllObjects];
        self.changeModelQueue = nil;
        self.changeStickerQueue = nil;
    });
}
@end
