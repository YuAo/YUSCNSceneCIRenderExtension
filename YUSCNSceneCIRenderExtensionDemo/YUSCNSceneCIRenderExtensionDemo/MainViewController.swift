//
//  ViewController.swift
//  YUSCNSceneCIRenderExtensionDemo
//
//  Created by YuAo on 3/19/16.
//  Copyright © 2016 YuAo. All rights reserved.
//

import UIKit
import AVFoundation
import YUSCNSceneCIRenderExtension

class MainViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    let captureSession = AVCaptureSession()
    
    let sampleBufferProcessingQueue = dispatch_queue_create("com.imyuao.demo.videoBufferProcessingQueue", DISPATCH_QUEUE_SERIAL)
    
    let videoSize = CGSizeMake(480, 640)
    
    weak var previewImageView: UIImageView!
    
    let coreImageSceneRenderExtension = YUSCNSceneCIRenderExtension()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previewImageView = UIImageView(frame: CGRectZero)
        self.view.addSubview(previewImageView)
        self.previewImageView = previewImageView
        
        Utilities.setupCaptureSession(self.captureSession, sampleBufferDelegate: self, queue: self.sampleBufferProcessingQueue)
        
        self.coreImageSceneRenderExtension.scene = Utilities.createDefaultSCNScene()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewImageView.frame = AVMakeRectWithAspectRatioInsideRect(self.videoSize, self.view.bounds)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.captureSession.startRunning()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        //get camera output
        let image = CIImage(CVPixelBuffer: pixelBuffer)
        
        //get rendered scene
        let sceneImage = self.coreImageSceneRenderExtension.renderAtTime(CFAbsoluteTimeGetCurrent(), size: self.videoSize)
        
        //apply filters
        let sourceOverlayFilter = CIFilter(name: "CISourceOverCompositing")!
        sourceOverlayFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        sourceOverlayFilter.setValue(sceneImage, forKey: kCIInputImageKey)
        
        let instantFilter = CIFilter(name: "CIPhotoEffectProcess")!
        instantFilter.setValue(sourceOverlayFilter.outputImage, forKey: kCIInputImageKey)
        
        let result = instantFilter.outputImage!
        
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.previewImageView.image = UIImage(CIImage: result)
        }
    }

}

