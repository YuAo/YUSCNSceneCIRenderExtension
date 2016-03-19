//
//  YUCISCNSceneRenderer.m
//  YUCISceneRendererDemo
//
//  Created by YuAo on 3/19/16.
//  Copyright © 2016 YuAo. All rights reserved.
//

#import "YUSCNSceneCIRenderExtension.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#define YU_SCNSCENE_CI_RENDER_EXTENSION_DEFER \
try {} @finally {} \
__strong YUSCNSceneCIRenderExtensionDeferCleanupBlock (YUSCNSceneCIRenderExtensionDeferBlock_##__LINE__) __attribute__((cleanup(YUSCNSceneCIRenderExtensionDeferExecuteCleanupBlock), unused)) = ^

typedef void (^YUSCNSceneCIRenderExtensionDeferCleanupBlock)();

void YUSCNSceneCIRenderExtensionDeferExecuteCleanupBlock (__strong YUSCNSceneCIRenderExtensionDeferCleanupBlock *block);

void YUSCNSceneCIRenderExtensionDeferExecuteCleanupBlock (__strong YUSCNSceneCIRenderExtensionDeferCleanupBlock *block) {
    (*block)();
}

@interface YUSCNSceneCIRenderExtension ()

@property (nonatomic,strong) EAGLContext *context;
@property (nonatomic,strong) SCNRenderer *renderer;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCache;

@end

@implementation YUSCNSceneCIRenderExtension

- (instancetype)init {
    if (self = [super init]) {
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.renderer = [SCNRenderer rendererWithContext:self.context options:nil];
        CVOpenGLESTextureCacheRef textureCache;
        CVReturn error = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, self.context, nil, &textureCache);
        if (error) {
            NSLog( @"Error at CVOpenGLESTextureCacheCreate %d", error);
        } else {
            self.textureCache = textureCache;
        }
    }
    return self;
}

- (void)setScene:(SCNScene *)scene {
    self.renderer.scene = scene;
}

- (SCNScene *)scene {
    return self.renderer.scene;
}

- (CFTimeInterval)nextFrameTime {
    return self.renderer.nextFrameTime;
}

- (CIImage *)renderAtTime:(CFTimeInterval)time size:(CGSize)size {
    CIImage *outputImage;
    
    NSDictionary *attributes = @{(NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferRef renderTarget;
    CVPixelBufferCreate(kCFAllocatorDefault, (size_t)size.width, (size_t)size.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef _Nullable)(attributes), &renderTarget);
    CVOpenGLESTextureRef texture;
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, renderTarget,
                                                 nil, // texture attributes
                                                 GL_TEXTURE_2D,
                                                 GL_RGBA, // opengl format
                                                 size.width,
                                                 size.height,
                                                 GL_BGRA, // native iOS format
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 &texture);
    @YU_SCNSCENE_CI_RENDER_EXTENSION_DEFER {
        CVPixelBufferRelease(renderTarget);
        CFRelease(texture);
        CVOpenGLESTextureCacheFlush(self.textureCache, 0);
    };
    
    EAGLContext *oldContext = [EAGLContext currentContext];
    if (oldContext != self.context) {
        [EAGLContext setCurrentContext:self.context];
    }
    @synchronized(self.context) {
        GLuint thumbnailFramebuffer = 0;
        glGenFramebuffers(1, &thumbnailFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, thumbnailFramebuffer); //checkGLErrors()
        
        GLuint colorRenderbuffer = 0;
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, size.width, size.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer); //checkGLErrors()
        
        GLuint depthRenderbuffer = 0;
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, size.width, size.height);
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer); //checkGLErrors()
        
        GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        assert(framebufferStatus == GL_FRAMEBUFFER_COMPLETE);
        if (framebufferStatus != GL_FRAMEBUFFER_COMPLETE) {
            return nil;
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(texture), 0);
        
        // clear buffer
        glViewport(0, 0, size.width, size.height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); //checkGLErrors()
        
        // render
        [self.renderer renderAtTime:time]; //checkGLErrors()
        
        glFlush();

        outputImage = [CIImage imageWithCVPixelBuffer:renderTarget];
        outputImage = [outputImage imageByApplyingTransform:[outputImage imageTransformForOrientation:4]];
        
        glDeleteFramebuffers(1, &thumbnailFramebuffer);
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        glDeleteRenderbuffers(1, &depthRenderbuffer);
    }
    if (oldContext != self.context) {
        [EAGLContext setCurrentContext:oldContext];
    }
    
    return outputImage;
}

- (void)dealloc {
    CFRelease(self.textureCache);
}

@end
