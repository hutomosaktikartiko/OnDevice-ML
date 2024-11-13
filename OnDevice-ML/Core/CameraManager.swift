//
//  CameraManager.swift
//  OnDevice-ML
//
//  Created by Hutomo on 12/11/24.
//
import AVFoundation
import CoreImage
import Foundation
import SwiftUI

protocol CameraManagerDelegate: AnyObject {
    func didCapturePhoto(_ image: CGImage)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}

class CameraManager: NSObject, ObservableObject {
    weak var delegate: CameraManagerDelegate?
    let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    var currentCameraPosition: AVCaptureDevice.Position = .front
    var flashMode: AVCaptureDevice.FlashMode = .off

    private var sessionQueue = DispatchQueue(label: "video.preview.session")
    
    private var addToPreviewStream: ((CGImage) -> Void)?
    
    override init() {
        super.init()
        
        Task {
            await configureSession()
            await startSession()
        }
    }
    
    lazy var previewStream: AsyncStream<CGImage> = AsyncStream { continuation in
        addToPreviewStream = { cgImage in
            continuation.yield(cgImage)
        }
    }
    
    var currentPixelBuffer: CVPixelBuffer?

    private var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            return isAuthorized
        }
    }
    
    private func configureSession() async {
        let systemPreferredCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: currentCameraPosition
        )
        
        guard await isAuthorized,
              let systemPreferredCamera = systemPreferredCamera,
              let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera)
        else { return }
         
        captureSession.beginConfiguration()
         
        defer {
            self.captureSession.commitConfiguration()
        }
         
        let videoOutput = AVCaptureVideoDataOutput()
        let photoOutput = AVCapturePhotoOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
         
        guard captureSession.canAddInput(deviceInput) else {
            return
        }
         
        guard captureSession.canAddOutput(videoOutput) else {
            return
        }
         
        guard captureSession.canAddOutput(photoOutput) else {
            return
        }
         
        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)
        captureSession.addOutput(photoOutput)
         
        self.deviceInput = deviceInput
        self.videoOutput = videoOutput
        self.photoOutput = photoOutput
    }
    
    func startSession() async {
        guard await isAuthorized else { return }
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func toggleFlash() {
        guard let device = deviceInput?.device, device.hasFlash else {
            return
        }

        do {
            try device.lockForConfiguration()
            flashMode = (flashMode == .off) ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to lock device for configuration: \(error)")
        }
    }

    func flipCamera() async {
        guard let currentInput = deviceInput else { return }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.removeInput(currentInput)

        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
        let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition)
        
        guard let newDeviceInput = try? AVCaptureDeviceInput(device: newCamera!) else { return }
        
        if captureSession.canAddInput(newDeviceInput) {
            captureSession.addInput(newDeviceInput)
            deviceInput = newDeviceInput
        } else {
            captureSession.addInput(currentInput)
        }
    }

    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        let photoSettings = AVCapturePhotoSettings()
        photoSettings.flashMode = flashMode

        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        currentPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        delegate?.captureOutput(output, didOutput: sampleBuffer, from: connection)
    }
}

extension CMSampleBuffer {
    var cgImage: CGImage? {
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(self)
        guard let imagePixelBuffer = pixelBuffer else { return nil }
        return CIImage(cvPixelBuffer: imagePixelBuffer).cgImage
    }
}

extension CIImage {
    var cgImage: CGImage? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: extent) else { return nil }
        return cgImage
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage
        else {
            return
        }

        DispatchQueue.main.async {
            self.delegate?.didCapturePhoto(cgImage)
        }
    }
}
