//
//  CVPixelBuffer+CGImage.swift
//  OnDevice-ML
//
//  Created by Hutomo on 13/11/24.
//

import AVFoundation
import Foundation
import SwiftUI

extension CVPixelBuffer {
    func extractImage() -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: self)

        let orientedImage = ciImage.oriented(
            forExifOrientation: Int32(CGImagePropertyOrientation(
                deviceOrientation: UIDevice.current.orientation).rawValue
            )
        )

        let context = CIContext()
        return context.createCGImage(orientedImage, from: orientedImage.extent)
    }
}

extension Optional where Wrapped == CVPixelBuffer {
    func toCGImage() -> CGImage? {
        guard let pixelBuffer = self else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let orientedImage = ciImage.oriented(
            forExifOrientation: Int32(CGImagePropertyOrientation(
                deviceOrientation: UIDevice.current.orientation).rawValue
            )
        )

        let context = CIContext()
        return context.createCGImage(orientedImage, from: orientedImage.extent)
    }
}

private extension CGImagePropertyOrientation {
    init(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown:
            self = .left
        case .landscapeLeft:
            self = .down
        case .landscapeRight:
            self = .down
        case .portrait, .faceUp, .faceDown, .unknown:
            self = .right
        @unknown default:
            self = .right
        }
    }
}
