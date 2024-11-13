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
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0

    private var startTime: Date?
    private var lastFaceObservationTime: Date?

    // Properties for detection buffer and timer
    private var detectionBuffer: [(isCorrect: Bool, image: CGImage?)] = []
    private let detectionThreshold = 0.8
    private let maxDetections = 10
    private var detectionTimer: Timer?

    private var cameraManager = CameraManager()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    override init() {
        super.init()
        self.cameraManager.delegate = self

        self.startDetectionTimer()
    }

    private func startDetectionTimer() {
        // Schedule timer to run every 1 second
        self.startTime = Date()
        self.detectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.processDetectionBuffer()
            self?.updateElapsedTime()
        }
    }

    private func updateElapsedTime() {
        guard let startTime = self.startTime else { return }
        self.elapsedTime = Date().timeIntervalSince(startTime)
    }

    func stopCamera() {
        self.cameraManager.captureSession.stopRunning()

        self.stopDetectionTimer()

        print("Camera session stopped")
    }

    private func stopDetectionTimer() {
        self.detectionTimer?.invalidate()
        self.detectionTimer = nil
    }

    private func processDetectionBuffer() {
        let correctDetections = self.detectionBuffer.filter { $0.isCorrect }
        let successRate = Double(correctDetections.count) / Double(self.detectionBuffer.count)

        self.errorMessage = nil

        print("Success rate: \(successRate)")
        print("Elapsed time: \(String(format: "%.1f", self.elapsedTime)) seconds")

        if successRate >= self.detectionThreshold,
           let imageToSave = correctDetections.first?.image
        {
            self.saveDetectedFace(imageToSave, orientation: self.currentFaceOrientation)
            self.proceedToNextOrientation()
        } else if self.detectionBuffer.count >= self.maxDetections {
            self.errorMessage = "Face \(self.currentFaceOrientation.description) not detected, please try again."
            print("Error \(String(describing: self.errorMessage))")

            // Reset buffer if threshold not met
            self.detectionBuffer.removeAll()
        }
    }

    private func proceedToNextOrientation() {
        // Reset buffer and move to next orientation
        self.detectionBuffer.removeAll()

        // Move to the next orientation
        switch self.currentFaceOrientation {
        case .straight:
            self.currentFaceOrientation = .left
        case .left:
            self.currentFaceOrientation = .right
        case .right:
            self.stopDetectionTimer()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer from sample buffer")
            return
        }

        // Introduce a delay mechanism
        let currentTime = Date()
        if let lastTime = lastFaceObservationTime, currentTime.timeIntervalSince(lastTime) < 1.0 {
            return
        }
        self.lastFaceObservationTime = currentTime

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
                self.handleFaceObservation(firstFace)
            } else {
                print("No face detected")
            }
        }
    }

    private func handleFaceObservation(_ faceObservation: VNFaceObservation) {
        let landmarksRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            DispatchQueue.main.async {
                print("handleFaceObservation")

                guard let self = self else { return }
                if let error = error {
                    print("Face detection request failed: \(error)")
                    return
                }
                if let results = request.results as? [VNFaceObservation], let firstFace = results.first {
                    let isCorrectOrientation = self.checkFaceOrientation(with: firstFace)
                    let currentImage = self.extractImage()
                    self.detectionBuffer.append((isCorrect: isCorrectOrientation, image: currentImage))

                    if self.detectionBuffer.count > self.maxDetections {
                        self.detectionBuffer.removeFirst()
                    }
                } else {
                    print("No face detected")
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

        var deltaX = rightEyePoint.x - leftEyePoint.x
        let deltaY = rightEyePoint.y - leftEyePoint.y

        // Check current camera position
        if self.cameraManager.currentCameraPosition == .front {
            deltaX = -deltaX
        }

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
