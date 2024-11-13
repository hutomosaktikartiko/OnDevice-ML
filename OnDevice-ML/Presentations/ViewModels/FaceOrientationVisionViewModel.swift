//
//  FaceOrientationVisionViewModel.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import AVFoundation
import SwiftUI
import Vision

enum FaceOrientation {
    case straight
    case left
    case right
}

extension FaceOrientation: CaseIterable, CustomStringConvertible {
    var description: String {
        switch self {
        case .straight: return "Straight"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

class FaceOrientationVisionViewModel: NSObject, ObservableObject, CameraManagerDelegate {
    @Published var currentFaceOrientation: FaceOrientation = .straight
    @Published var detectedFaces: [FaceOrientation: CGImage] = [:]

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

    func didCapturePhoto(_ image: CGImage) {}

    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
        DispatchQueue.main.async {
            guard let self = self else { return }
            if let error = error {
                print("Face detection request failed: \(error)")
                return
            }
            if let results = request.results as? [VNFaceObservation], let firstFace = results.first {
//                print("Detected face")
                self.handleFaceObservation(firstFace)
            } else {
                print("No face detected")
            }
        }
    }

    private func handleFaceObservation(_ faceObservation: VNFaceObservation) {
        let landmarksRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("Face landmarks request failed: \(error)")
                    return
                }
                if let results = request.results as? [VNFaceObservation], let firstFace = results.first {
                    if self.checkFaceOrientation(with: firstFace),
                       let cgImage = self.extractImage()
                    {
                        self.saveDetectedFace(cgImage, orientation: self.currentFaceOrientation)

                        switch self.currentFaceOrientation {
                        case .straight:
                            self.currentFaceOrientation = .left
                        case .left:
                            self.currentFaceOrientation = .right
                        case .right:
                            break
                        }
                    }
                }
            }
        }

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: cameraManager.currentPixelBuffer!, options: [:])
        do {
            try requestHandler.perform([landmarksRequest])
        } catch {
            print("Failed to perform landmarks request: \(error)")
        }
    }

    private func checkFaceOrientation(with faceObservation: VNFaceObservation) -> Bool {
        guard let landmarks = faceObservation.landmarks else { return false }
        guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye else { return false }

        let leftEyePoint = leftEye.normalizedPoints[0]
        let rightEyePoint = rightEye.normalizedPoints[0]

        let deltaX = rightEyePoint.x - leftEyePoint.x
        let deltaY = rightEyePoint.y - leftEyePoint.y

        let angle = atan2(deltaY, deltaX) * 180 / .pi

        var detectedFaceOrientation: FaceOrientation
        if angle > -10 && angle < 10 {
            detectedFaceOrientation = .straight
        } else if angle <= -10 {
            detectedFaceOrientation = .left
        } else {
            detectedFaceOrientation = .right
        }

        print("Angle: \(angle)")
        print("Detected face orientation: \(detectedFaceOrientation.description)")
        print("Current face orientation: \(self.currentFaceOrientation.description)")
        print("========================================")

        return self.currentFaceOrientation == detectedFaceOrientation
    }

    private func saveDetectedFace(_ image: CGImage, orientation: FaceOrientation) {
        guard self.detectedFaces[orientation] == nil else { return }

        // Save the new detected face
        self.detectedFaces[orientation] = image
    }

    private func extractImage() -> CGImage? {
        guard let pixelBuffer = cameraManager.currentPixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return self.previewLayer
    }
}
