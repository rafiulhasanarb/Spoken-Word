//
//  ViewController.swift
//  SpokenWord
//
//  Created by rafiul hasan on 19/10/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import UIKit
import Speech
import CallKit
import AVFoundation

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    //MARK: Speech Recognition
    var callObserver: CXCallObserver!
    private var synthesizer = AVSpeechSynthesizer()
    var lastString = ""
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var recordButton: UIButton!
    
    // MARK: View Controller Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        //CallKit implementations
        callObserver = CXCallObserver()
        callObserver.setDelegate(self, queue: nil)
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }
    
    private func startRecording() throws {
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSession.Category.playAndRecord)
        try audioSession.setMode(AVAudioSession.Mode.default)
        try audioSession.setActive(true)
        try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                let message = result.bestTranscription.formattedString
                
                for segment in result.bestTranscription.segments {
                    let indexTo = message.index(message.startIndex, offsetBy: segment.substringRange.location)
                    self.lastString = String(message[indexTo...])
                }
                if self.lastString == "Marco" {
                    self.saySpeechSynthesizer(text: "Marco polo")
                }
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }

        // Configure the microphone input.
        //let sampleRate = AVAudioSession.sharedInstance().sampleRate
        //let sampleRate = inputNode.inputFormat(forBus: 0).sampleRate
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        textView.text = "(Go ahead, I'm listening)"
    }
    
    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recordButton.isEnabled = false
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        print("Stop Speech recognition")
    }
    
    func stopSpeaking() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recordButton.isEnabled = false
    }
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle("Stop Recording", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
}

extension ViewController {
    func saySpeechSynthesizer(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            utterance.pitchMultiplier = 1
            utterance.volume = 1
            DispatchQueue.main.async {
                self.synthesizer.speak(utterance)
            }
        }
    }
}

extension ViewController: CXCallObserverDelegate {
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded == true {
            print("Disconnected")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                do {
                    try self.startRecording()
                    self.recordButton.isEnabled = true
                    self.recordButton.setTitle("Stop Recording", for: [])
                } catch let error {
                    print("Starting error: \(error.localizedDescription)")
                }
            }
        }
        if call.isOutgoing == true && call.hasConnected == false {
            print("Dialing")
            self.stopRecording()
            self.recordButton.isEnabled = false
            self.recordButton.setTitle("Start Recording", for: [])
        }
        if call.isOutgoing == false && call.hasConnected == false && call.hasEnded == false {
            print("Incoming")
            self.stopRecording()
            self.recordButton.isEnabled = false
            self.recordButton.setTitle("Start Recording", for: [])
        }
        if call.hasConnected == true && call.hasEnded == false {
            print("Connected")
            self.stopRecording()
            self.recordButton.isEnabled = false
            self.recordButton.setTitle("Start Recording", for: [])
        }
    }
}
