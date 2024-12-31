//
//  SpeechToTextView.swift
//  OnDevice-ML
//
//  Created by Hutomo on 31/12/24.
//

import SwiftUI

struct SpeechToTextView: View {
    @StateObject private var viewModel = SpeechToTextViewModel()

    var body: some View {
        VStack {
            Text(viewModel.transcribedText)
                .padding()
                .multilineTextAlignment(.center)

            Button(action: {
                viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
            }) {
                Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                    .foregroundColor(.white)
                    .padding()
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
