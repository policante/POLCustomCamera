//
//  ViewController.swift
//  POLCustomCamera
//
//  Created by Rodrigo Martins on 10/3/15.
//  Copyright © 2015 Martins. All rights reserved.
//

import UIKit

class ViewController: UIViewController{

    @IBOutlet weak var previewCamera: UIView!
    @IBOutlet weak var lastCapture: UIImageView!
    
    var cameraManager: POLCameraManager?

    override func viewDidLoad() {
        super.viewDidLoad()

        //Initialize POLCameraManager
        self.cameraManager = POLCameraManager(previewCamera: self.previewCamera)
        //enable flash
        self.cameraManager?.toggleFlash()
        self.lastCapture.alpha = 0.0
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        //Running camera
        self.cameraManager?.startCamera()
    }
    
    override func viewDidDisappear(animated: Bool) {
        //Stop camera
        self.cameraManager?.stopCamera()
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //rotate preview
        self.cameraManager!.viewDidLayoutSubviews();
    }
    
    func takePicture(){
        //take a picture
        self.cameraManager?.takePhoto({ (image) -> Void in
            if image != nil {
                
                self.lastCapture.image = image
                
                UIView.animateWithDuration(0.225, animations: { () -> Void in
                    self.lastCapture.alpha = 1.0
                })
            }
        })
    }
    
    @IBAction func changeCamera(sender: AnyObject) {
        //change input camera
        self.cameraManager?.changePositionCamera()
    }
    
    @IBAction func takePhoto(sender: AnyObject) {
        self.takePicture()
    }

}

