//
//  Utilities.swift
//  YUSCNSceneCIRenderExtensionDemo
//
//  Created by YuAo on 3/19/16.
//  Copyright © 2016 YuAo. All rights reserved.
//

import UIKit
import SceneKit
import AVFoundation

struct Utilities {
    static func createDefaultSCNScene() -> SCNScene {
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = SCNLightTypeOmni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = UIColor.darkGrayColor()
        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the ship node
        let ship = scene.rootNode.childNodeWithName("ship", recursively: true)!
        
        // animate the 3d object
        ship.runAction(SCNAction.repeatActionForever(SCNAction.rotateByX(0, y: 2, z: 0, duration: 1)))
        
        return scene
    }
    
    static func setupCaptureSession(captureSession:AVCaptureSession, sampleBufferDelegate:AVCaptureVideoDataOutputSampleBufferDelegate, queue: dispatch_queue_t) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSessionPreset640x480
        let videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            }
        } catch {
            print("error setting up videoDeviceInput: %@",error)
        }
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: queue)
        captureSession.addOutput(videoDataOutput)
        captureSession.commitConfiguration()
        
        videoDataOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = .Portrait
    }
}
