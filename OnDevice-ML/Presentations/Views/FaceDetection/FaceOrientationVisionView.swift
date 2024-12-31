//
//  FaceOrientationVisionView.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import AVFoundation
import SwiftUI
import Vision

struct FaceOrientationVisionView: View {
    @StateObject var viewModel = FaceOrientationVisionViewModel()

    var body: some View {
        VStack {
            if viewModel.detectedFaces.count < FaceOrientation.allCases.count {
                ZStack(alignment: .center) {
                    FaceOrientationVisionContent(viewModel: viewModel)
                    VStack(alignment: .center) {
                        Text("Current orientation: \(viewModel.currentFaceOrientation.description)")
                        Text("Elapsed time: \(String(format: "%.1f", viewModel.elapsedTime)) seconds")
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                }
                .onDisappear {
                    viewModel.stopCamera()
                }
            } else {
                ScrollView {
                    ForEach(Array(viewModel.detectedFaces.keys).sorted(by: { $0.description < $1.description }), id: \.self) { orientation in
                        if let face = viewModel.detectedFaces[orientation] {
                            VStack(alignment: .leading) {
                                Text("Orientation: \(orientation.description)")
                                    .font(.headline)
                                Image(uiImage: UIImage(cgImage: face))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.detectedFaces) { _ in
            print("Detected faces: \(viewModel.detectedFaces)")

            if viewModel.detectedFaces.count == FaceOrientation.allCases.count {
                viewModel.stopCamera()
            }
        }
    }
}

private struct FaceOrientationVisionContent: UIViewRepresentable {
    @ObservedObject var viewModel: FaceOrientationVisionViewModel

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
        var parent: FaceOrientationVisionContent

        init(_ parent: FaceOrientationVisionContent) {
            self.parent = parent
        }
    }
}
