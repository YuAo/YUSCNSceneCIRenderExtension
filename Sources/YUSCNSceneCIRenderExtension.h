//
//  YUCISCNSceneRenderer.h
//  YUCISceneRendererDemo
//
//  Created by YuAo on 3/19/16.
//  Copyright © 2016 YuAo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <CoreImage/CoreImage.h>

@interface YUSCNSceneCIRenderExtension : NSObject

@property (nonatomic,strong,readonly) SCNRenderer *renderer;

@property (nonatomic,strong) SCNScene *scene; //renderer.scene

@property(nonatomic, readonly) CFTimeInterval nextFrameTime; //renderer.nextFrameTime

- (CIImage *)renderAtTime:(CFTimeInterval)time size:(CGSize)size;

@end
