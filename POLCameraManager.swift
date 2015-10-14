//
//  POLCameraManager.swift
//  POLCustomCamera
//
//  Created by Rodrigo Martins on 10/3/15.
//  Copyright © 2015 Martins. All rights reserved.
//

import UIKit
import AVFoundation

class POLCameraManager : NSObject {
    
    enum DevicePosition{
        case Back
        case Front
    }
    
    private var devicePosition: DevicePosition = .Back
    
    private var device: AVCaptureDevice!
    private var session: AVCaptureSession!
    private var sessionQueue: dispatch_queue_t!
    private var stillImageOutput: AVCaptureStillImageOutput?
    
    private var previewCamera: UIView!
    private var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private var tapHandler: ((CGPoint) -> Void)?
    
    private var isCrazyMode = false
    private var isCrazyModeStarted = false
    private var lensPosition: Float = 0
    
    init(previewCamera: UIView!) {
        super.init()
        self.initManager(previewCamera, position: DevicePosition.Back)
    }
    
    init(previewCamera: UIView!, devicePosition: DevicePosition) {
        super.init()
        self.initManager(previewCamera, position: devicePosition)
    }
    
    private func initManager(previewCamera: UIView!, position: DevicePosition){
        self.previewCamera = previewCamera
        self.devicePosition = position
        self.initializeSession()
    }

    //MARK: Session
    
    private func initializeSession(){
        NSLog("initializeSession")
        self.session = AVCaptureSession()
        self.session.sessionPreset = AVCaptureSessionPresetPhoto
        self.sessionQueue = dispatch_queue_create("POLCameraManager", DISPATCH_QUEUE_SERIAL)
        
        NSLog("beginConfiguration")
        self.session.beginConfiguration()
        NSLog("addInput")
        self.addInput()
        NSLog("addImageOutput")
        self.addImageOutput()
        NSLog("commitConfiguration")
        self.session.commitConfiguration()
        
        NSLog("configFocusHandler")
        self.configFocusHandler()
    }
    
    deinit{
        self.stopCamera()
    }

    //MARK: Manager
    //Running camera
    func startCamera(){
        NSLog("setupPreview")
        self.setupPreview()
        
        dispatch_async(self.sessionQueue){
            self.session.startRunning()
        }
    }
    
    //Stop Camera
    func stopCamera(){
        dispatch_async(self.sessionQueue){
            self.session.stopRunning()
        }
    }
    
    //Configure camera device input: .Back or .Front
    func setPositionCamera(position: DevicePosition){
        self.devicePosition = position
        dispatch_async(self.sessionQueue){
            self.changeInput()
        }
    }
    
    //Check device has flash
    func hasFlash() -> Bool {
        if let device = self.device {
            return device.hasFlash
        }
        return false
    }
    
    //Check device has Torch
    func hasTorch() -> Bool {
        if let device = self.device {
            return device.hasTorch
        }
        return false
    }
    
    //Change torch: .On or .Off
    func toggleTorch() -> Bool {
        if self.hasTorch() {
            self.session.beginConfiguration()
            do {
                try self.device.lockForConfiguration()
            } catch _ {
            }
            
            if self.device.torchMode == .Off {
                self.device.torchMode = .On
            } else if self.device.torchMode == .On {
                self.device.torchMode = .Off
            }
            
            
            
            self.device.unlockForConfiguration()
            self.session.commitConfiguration()
            
            return self.device.torchMode == .On
        }
        return false
    }
    
    //Change flash: .On or .Off
    func toggleFlash() -> Bool {
        if self.hasFlash() {
            self.session.beginConfiguration()
            do {
                try self.device.lockForConfiguration()
            } catch _ {
            }

            if self.device.flashMode == .Off {
                self.device.flashMode = .On
            } else if self.device.flashMode == .On {
                self.device.flashMode = .Off
            }
            
            self.device.unlockForConfiguration()
            self.session.commitConfiguration()
            
            return self.device.flashMode == .On
        }
        
        return false
    }
    
    //configure video orientation
    func viewDidLayoutSubviews(){

        if let videoPreviewLayer = self.captureVideoPreviewLayer {
            let videoOrientation = POLCameraManager.interfaceOrientationToVideoOrientation(UIApplication.sharedApplication().statusBarOrientation)
            if videoPreviewLayer.connection.supportsVideoOrientation
                && videoPreviewLayer.connection.videoOrientation != videoOrientation {
                    videoPreviewLayer.connection.videoOrientation = videoOrientation
            }
        }
    }
    
    //Change position camera: .Back or .Front
    func changePositionCamera(){
        switch devicePosition {
        case .Front:
            self.devicePosition = .Back
        case .Back:
            self.devicePosition = .Front
        }
        
        dispatch_async(self.sessionQueue){
            self.changeInput()
        }
    }
    
    //Take a picture
    func takePhoto(completed: (image: UIImage?) -> Void){
        if let imageOutput = self.stillImageOutput {
            dispatch_async(self.sessionQueue, { () -> Void in
                var videoConnection: AVCaptureConnection?
                for connection in imageOutput.connections {
                    let c = connection as! AVCaptureConnection
                    for port in c.inputPorts {
                        let p = port as! AVCaptureInputPort
                        if p.mediaType == AVMediaTypeVideo{
                            videoConnection = c
                            break
                        }
                    }
                    
                    if videoConnection != nil {
                        break
                    }
                }
                
                if videoConnection != nil {
                    imageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: { (imageSampleBuffer: CMSampleBufferRef!, error) -> Void in
                        let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                    
                        let image : UIImage? = UIImage(data: imageData)
                        
                        dispatch_async(dispatch_get_main_queue()){
                            completed(image: image)
                        }
                    })
                }else{
                    dispatch_async(dispatch_get_main_queue()){
                        completed(image: nil)
                    }
                }
            })
        }else{
            completed(image: nil)
        }
    }
    
    class func interfaceOrientationToVideoOrientation(orientation : UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch (orientation) {
        case .Unknown:
            fallthrough
        case .Portrait:
            return AVCaptureVideoOrientation.Portrait
        case .PortraitUpsideDown:
            return AVCaptureVideoOrientation.PortraitUpsideDown
        case .LandscapeLeft:
            return AVCaptureVideoOrientation.LandscapeLeft
        case .LandscapeRight:
            return AVCaptureVideoOrientation.LandscapeRight
        }
    }
    
    //MARK: Configuration
    private func setupPreview() {
        self.captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.captureVideoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.captureVideoPreviewLayer?.frame = self.previewCamera.bounds
        self.previewCamera.layer.addSublayer(self.captureVideoPreviewLayer!)
    }
    
    private func configFocusHandler(){
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "onTap:")
        self.previewCamera.addGestureRecognizer(tapGestureRecognizer)
    }
    
    private func addInput(){
        self.device = self.deviceWithMediaTypeWithPosition(AVMediaTypeVideo, position: getCaptureDevicePosition())
        var input: AVCaptureDeviceInput! = nil
        do{
            input = try AVCaptureDeviceInput.init(device: self.device)
        }catch _{
        }
        
        if let device = self.device {
            do {
                try device.lockForConfiguration()
                if self.device.isFocusModeSupported(.ContinuousAutoFocus) {
                    self.device.focusMode = .ContinuousAutoFocus
                }
                if self.device.autoFocusRangeRestrictionSupported {
                    self.device.autoFocusRangeRestriction = .Near
                }
                self.device.unlockForConfiguration()
            } catch _ {
            }
        }
        
        if self.session.canAddInput(input){
            self.session.addInput(input)
        }
    }
    
    private func changeInput(){
        
        let currentInput : AVCaptureDeviceInput = self.session.inputs[0] as! AVCaptureDeviceInput
        self.session.removeInput(currentInput)
        
        addInput()
        
    }
    
    private func getCaptureDevicePosition() -> AVCaptureDevicePosition{
        switch devicePosition{
        case .Front:
            return AVCaptureDevicePosition.Front
        case .Back:
            return AVCaptureDevicePosition.Back
        }
    }
    
    private func addImageOutput(){
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        if self.session.canAddOutput(stillImageOutput){
            self.session.addOutput(stillImageOutput)
        }
        
    }
    
    private func deviceWithMediaTypeWithPosition(mediaType: String, position: AVCaptureDevicePosition) -> AVCaptureDevice {
        let devices: NSArray = AVCaptureDevice.devicesWithMediaType(mediaType)
        var captureDevice: AVCaptureDevice = devices.firstObject as! AVCaptureDevice
        for device in devices {
            let d = device as! AVCaptureDevice
            if d.position == position {
                captureDevice = d
                break;
            }
        }
        
        return captureDevice
    }
    
    //Configure tap focus
    func onTap(gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.locationInView(self.previewCamera)
        let focusPoint = CGPointMake(
            tapPoint.x / self.previewCamera.bounds.size.width,
            tapPoint.y / self.previewCamera.bounds.size.height)
        
        if let device = self.device {
            do {
                try device.lockForConfiguration()
                if device.focusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                } else {
                    print("Focus point of interest not supported.")
                }
                if self.isCrazyMode {
                    if device.isFocusModeSupported(.Locked) {
                        device.focusMode = .Locked
                    } else {
                        print("Locked focus not supported.")
                    }
                    if !self.isCrazyModeStarted {
                        self.isCrazyModeStarted = true
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.autoUpdateLensPosition()
                        })
                    }
                } else {
                    if device.isFocusModeSupported(.ContinuousAutoFocus) {
                        device.focusMode = .ContinuousAutoFocus
                    } else if device.isFocusModeSupported(.AutoFocus) {
                        device.focusMode = .AutoFocus
                    } else {
                        print("Auto focus not supported.")
                    }
                }
                if device.autoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .None
                } else {
                    print("Auto focus range restriction not supported.")
                }
                device.unlockForConfiguration()
            } catch _ {
            }
        }
        
        if let tapHandler = self.tapHandler {
            tapHandler(tapPoint)
        }
    }
    
    private func autoUpdateLensPosition() {
        self.lensPosition += 0.01
        if self.lensPosition > 1 {
            self.lensPosition = 0
        }
        do {
            try device.lockForConfiguration()
            self.device.setFocusModeLockedWithLensPosition(self.lensPosition, completionHandler: nil)
            device.unlockForConfiguration()
        } catch _ {
        }
        if session.running {
            let when = dispatch_time(DISPATCH_TIME_NOW, Int64(10 * Double(USEC_PER_SEC)))
            dispatch_after(when, dispatch_get_main_queue(), {
                self.autoUpdateLensPosition()
            })
        }
    }
    
}