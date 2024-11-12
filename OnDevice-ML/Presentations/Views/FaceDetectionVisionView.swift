//
//  FaceDetectionVisionView.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import AVFoundation
import SwiftUI
import Vision

struct FaceDetectionVisionView: UIViewRepresentable {
    @ObservedObject var viewModel: FaceDetectionViewModel

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
        var parent: FaceDetectionVisionView

        init(_ parent: FaceDetectionVisionView) {
            self.parent = parent
        }
    }
}

struct FaceDetectionVisionViewContainer: View {
    @StateObject var viewModel = FaceDetectionViewModel()

    var body: some View {
        FaceDetectionVisionView(viewModel: viewModel)
            .onDisappear {
                viewModel.stopCamera()
            }
    }
}
