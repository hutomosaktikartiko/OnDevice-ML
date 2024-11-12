//
//  FaceDetectionVisionViewModel.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import AVFoundation
import SwiftUI
import Vision

class FaceDetectionVisionViewModel: NSObject, ObservableObject, CameraManagerDelegate {
    @Published var detectedFaceImage: CGImage?
    private var cameraManager = CameraManager()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    override init() {
        super.init()
        self.cameraManager.delegate = self
    }

    func startCameraSession() {
        Task {
            await self.cameraManager.startSession()
        }
    }

    func stopCamera() {
        self.cameraManager.captureSession.stopRunning()
        print("Camera session stopped")
    }

    func didCapturePhoto(_ image: CGImage) {
        // Handle captured photo if needed
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer from sample buffer")
            return
        }

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try requestHandler.perform([self.faceDetectionRequest])
        } catch {
            print("Failed to perform face detection request: \(error)")
        }
    }

    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
        DispatchQueue.main.async {
            guard let self = self else { return }
            if let error = error {
                print("Face detection request failed: \(error)")
                return
            }
            if let results = request.results as? [VNFaceObservation], let firstFace = results.first {
                print("Detected face")
                if let cgImage = self.extractImage(from: firstFace) {
                    self.detectedFaceImage = cgImage
                    self.stopCamera()
                }
            } else {
                print("No face detected")
                self.detectedFaceImage = nil
            }
        }
    }

    private func extractImage(from observation: VNFaceObservation) -> CGImage? {
        guard let pixelBuffer = cameraManager.currentPixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return self.previewLayer
    }
}

private extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: (1 - self.origin.y - self.height) * size.height,
            width: self.width * size.width,
            height: self.height * size.height
        )
    }
}