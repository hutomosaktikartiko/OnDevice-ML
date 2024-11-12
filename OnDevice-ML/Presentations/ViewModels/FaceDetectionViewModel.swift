//
//  FaceDetectionViewModel.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import AVFoundation
import SwiftUI
import Vision

class FaceDetectionViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var drawings: [CAShapeLayer] = []
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    override init() {
        super.init()
        setupCamera()
    }

    func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to get the front camera device")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
        } catch {
            print("Error setting device video input: \(error)")
            return
        }

        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString: NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        captureSession.addOutput(videoDataOutput)

        guard let connection = videoDataOutput.connection(with: .video),
              connection.isVideoOrientationSupported else { return }

        connection.videoOrientation = .portrait
        captureSession.startRunning()
        print("Front camera session started")
    }

    func stopCamera() {
        captureSession.stopRunning()
        print("Camera session stopped")
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try requestHandler.perform([faceDetectionRequest])
        } catch {
            print("Failed to perform face detection request: \(error)")
        }
    }

    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, _ in
        DispatchQueue.main.async {
            guard let self = self else { return }
            if let results = request.results as? [VNFaceObservation], results.count > 0 {
                print("Detected \(results.count) faces")
                self.handleFaceDetectionResults(observedFaces: results)
            } else {
                print("No face detected")
                self.clearDrawings()
            }
        }
    }

    func handleFaceDetectionResults(observedFaces: [VNFaceObservation]) {
        let faceBoxes: [CAShapeLayer] = observedFaces.map { (observedFace: VNFaceObservation) -> CAShapeLayer in
            let boxOnScreen = previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)

            let faceBoundingBoxPath = CGPath(rect: boxOnScreen, transform: nil)
            let boxShape = CAShapeLayer()
            boxShape.path = faceBoundingBoxPath
            boxShape.fillColor = UIColor.clear.cgColor
            boxShape.strokeColor = UIColor.green.cgColor

            return boxShape
        }

        for box in faceBoxes {
            previewLayer.addSublayer(box)
        }
        drawings = faceBoxes
    }

    func clearDrawings() {
        for drawing in drawings {
            drawing.removeFromSuperlayer()
        }
        drawings.removeAll()
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return previewLayer
    }
}
