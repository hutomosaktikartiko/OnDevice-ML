//
//  FaceDetectionVisionView.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import AVFoundation
import SwiftUI
import Vision

struct FaceDetectionVisionView: View {
    @StateObject var viewModel = FaceDetectionVisionViewModel()

    var body: some View {
        Group {
            if let detectedFaceImage = viewModel.detectedFaceImage {
                VStack {
                    Text("Face Detected")
                    Image(uiImage: UIImage(cgImage: detectedFaceImage))
                        .resizable()
                        .scaledToFit()
                }
            } else {
                FaceDetectionVisionContent(viewModel: viewModel)
                    .onDisappear {
                        viewModel.stopCamera()
                    }
            }
        }
        .onChange(of: viewModel.detectedFaceImage) { newValue in
            if newValue != nil {
                viewModel.stopCamera()
            }
        }
    }
}

private struct FaceDetectionVisionContent: UIViewRepresentable {
    @ObservedObject var viewModel: FaceDetectionVisionViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = viewModel.getPreviewLayer()
        view.layer.addSublayer(previewLayer)
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
            print("Preview layer frame set in makeUIView: \(view.bounds)")
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            self.viewModel.getPreviewLayer().frame = uiView.bounds
            print("Preview layer frame updated in updateUIView: \(uiView.bounds)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: FaceDetectionVisionContent

        init(_ parent: FaceDetectionVisionContent) {
            self.parent = parent
        }
    }
}
