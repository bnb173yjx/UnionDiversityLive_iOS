//
//  ViewController.h
//
//  Created by HaifengMay on 16/11/7.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GPUImage/GPUImage.h>
#import "STViewButton.h"
#import "STCommonObjectContainerView.h"

@interface STFilterVC : GPUImageOutput<GPUImageInput>
@property (nonatomic, readwrite, strong) STCommonObjectContainerView *commonObjectContainerView;
@property(nonatomic, copy) void(^viewUpdateCallback)(void);
- (void) addview:(UIView*)view;
- (void) setFilter:(CGSize)previewDimension;
- (void) closeStFilter;
@end
