# POLCustomCamera
Create a custom camera using POLCustomCamera

![POLCustomCamera preview](https://github.com/policante/POLCustomCamera/blob/master/preview.PNG "Preview")

# How to use

Include the file 'POLCameraManager.swift' in your project.

Initialize POLCameraManager and set the UIView for preview.
```swift
  POLCameraManager manager = POLCameraManager(previewCamera: self.previewCamera)
```

Take a picture
```swift
  manager?.takePhoto({ (image) -> Void in
            if image != nil {
                self.myImageView.image = image
            }
        })
```

Toggle Flash
```swift
  manager?.toggleFlash()
```

Switch Camera
```swift
  manager?.changePositionCamera()
```

Take a look at the 'Sample' folder for an example project.

# Maintainers
* [Rodrigo Martins](http://rpolicante.com/) ([@rpmartins16](https://twitter.com/rpmartins16))

License
-------
POLCameraManager is released under the MIT license. See LICENSE for details.
