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

static void YUSCNSceneCIRenderExtensionCheckGLErrors() {
    GLenum error;
    BOOL hadError = NO;
    do {
        error = glGetError();
        if (error != 0) {
            NSLog(@"OpenGL error: %@",@(error));
            hadError = YES;
        }
    } while (error != 0);
    assert(!hadError);
}

@interface YUSCNSceneCIRenderExtension ()

@property (nonatomic) GLuint framebuffer;

@property (nonatomic,strong) EAGLContext *context;
@property (nonatomic,strong) SCNRenderer *renderer;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCache;

@end

@implementation YUSCNSceneCIRenderExtension

- (instancetype)init {
    if (self = [super init]) {
        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _context = context;
        _renderer = [SCNRenderer rendererWithContext:context options:nil];
        CVOpenGLESTextureCacheRef textureCache;
        CVReturn error = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context, nil, &textureCache);
        NSAssert(error == kCVReturnSuccess, @"Error at CVOpenGLESTextureCacheCreate %@",@(error));
        _textureCache = textureCache;
        
        //setup ogl context
        [self performWithOGLContext:^{
            GLuint framebuffer = 0;
            glGenFramebuffers(1, &framebuffer);
            glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
            _framebuffer = framebuffer;
            
            YUSCNSceneCIRenderExtensionCheckGLErrors();
        }];
    }
    return self;
}

- (void)performWithOGLContext:(void (^)(void))code {
    EAGLContext *oldContext = [EAGLContext currentContext];
    if (oldContext != self.context) {
        [EAGLContext setCurrentContext:self.context];
    }
    @synchronized(self.context) {
        code();
    }
    if (oldContext != self.context) {
        [EAGLContext setCurrentContext:oldContext];
    }
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
    //!!!TODO: Use a pixel buffer pool here
    NSDictionary *attributes = @{(NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
                                 (NSString *)kCVPixelFormatOpenGLESCompatibility: @(YES)};
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
    };
    
    [self performWithOGLContext:^{
        GLuint depthRenderbuffer = 0;
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, size.width, size.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        YUSCNSceneCIRenderExtensionCheckGLErrors();
        
        glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(texture), 0);
        
        YUSCNSceneCIRenderExtensionCheckGLErrors();
        
        GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        assert(framebufferStatus == GL_FRAMEBUFFER_COMPLETE);
        if (framebufferStatus != GL_FRAMEBUFFER_COMPLETE) {
            return;
        }
        
        //clear buffer
        glViewport(0, 0, size.width, size.height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        YUSCNSceneCIRenderExtensionCheckGLErrors();
        
        //render
        [self.renderer renderAtTime:time];
        
        YUSCNSceneCIRenderExtensionCheckGLErrors();
        
        glFlush();
        glDeleteRenderbuffers(1, &depthRenderbuffer);
    }];
    
    CIImage *outputImage = nil;
    outputImage = [CIImage imageWithCVPixelBuffer:renderTarget];
    outputImage = [outputImage imageByApplyingTransform:[outputImage imageTransformForOrientation:4]];
    return outputImage;
}

- (void)dealloc {
    [self performWithOGLContext:^{
        glDeleteFramebuffers(1, &_framebuffer);
    }];
    if (_textureCache) {
        CFRelease(_textureCache);
    }
}

@end
