//
//  SpeechToTextViewModel.swift
//  OnDevice-ML
//
//  Created by Hutomo on 31/12/24.
//

import AVFoundation
import Combine
import Speech
import SwiftUI

class SpeechToTextViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var transcribedText: String = ""

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine = .init()
    private var request: SFSpeechAudioBufferRecognitionRequest = .init()

    init(locale: String = "id-ID") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        requestSpeechAuthorization()
    }

    // MARK: - Request Authorization

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition not authorized.")
            }
        }

        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied.")
            }
        }
    }

    // MARK: - Start Recording

    func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer is not available.")
            return
        }

        isRecording = true
        transcribedText = ""

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            request = SFSpeechAudioBufferRecognitionRequest()

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self?.transcribedText = result.bestTranscription.formattedString
                    }
                }

                if let error = error {
                    print("Recognition error: \(error.localizedDescription)")
                    self?.stopRecording()
                }
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to start speech recognition: \(error.localizedDescription)")
            stopRecording()
        }
    }

    // MARK: - Stop Recording

    func stopRecording() {
        isRecording = false

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionTask?.finish()
        recognitionTask = nil

        request.endAudio()
    }
}
