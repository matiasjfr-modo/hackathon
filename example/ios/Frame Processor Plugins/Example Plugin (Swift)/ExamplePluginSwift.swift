//
//  ExamplePluginSwift.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 30.04.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVKit
import Vision

@objc(ExamplePluginSwift)
public class ExamplePluginSwift: NSObject, FrameProcessorPluginBase {
    @objc
    public static func callback(_ frame: Frame!, withArgs args: [Any]!) -> Any! {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else {
            return nil
        }
      let ciimage = CIImage(cvPixelBuffer: imageBuffer)
      let image = self.convert(cmage: ciimage)
      
      let grayImage = OpenCVWrapper.toGray(image)
      
      let myImage = OpenCVWrapper.processImage(withOpenCV: grayImage)
      
      print("----------------------------------------------")
      print(myImage.base64 ?? "No tengo base 64 perrita")
      
      let base64: String = myImage.base64 ?? ""

        args.forEach { arg in
            var string = "\(arg)"
            if let array = arg as? NSArray {
                string = (array as Array).description
            } else if let map = arg as? NSDictionary {
                string = (map as Dictionary).description
            }
            NSLog("ExamplePlugin:   -> \(string) (\(type(of: arg)))")
        }

        return [
          "base_64" : base64,
            "example_str": "Test",
            "example_bool": true,
            "example_double": 5.3,
            "example_array": [
                "Hello",
                true,
                17.38,
            ],
        ]
    }
  
  public static func convert(cmage: CIImage) -> UIImage {
       let context = CIContext(options: nil)
       let cgImage = context.createCGImage(cmage, from: cmage.extent)!
       let image = UIImage(cgImage: cgImage)
       return image
  }
}

extension UIImage {
    var base64: String? {
        self.jpegData(compressionQuality: 1)?.base64EncodedString()
    }
}
