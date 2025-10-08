//
//  UIImage+GIF.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/7/25.
//
import UIKit
import ImageIO
import MobileCoreServices

extension UIImage {
    static func animatedImageWithGIFData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let count = CGImageSourceGetCount(source)
        var images = [UIImage]()
        var duration: Double = 0

        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))

                let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as NSDictionary?
                let gifInfo = properties?[kCGImagePropertyGIFDictionary as String] as? NSDictionary
                let delayTime = gifInfo?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double ??
                                gifInfo?[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
                duration += delayTime
            }
        }

        if duration == 0 {
            duration = Double(count) * 0.1
        }

        return UIImage.animatedImage(with: images, duration: duration)
    }
}
