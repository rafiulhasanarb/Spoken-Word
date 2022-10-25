//
//  HomeViewController.swift
//  SpokenWord
//
//  Created by rafiul hasan on 19/10/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import UIKit
import Speech
import CallKit
import AVFoundation

class HomeViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    //for speech synthessizer
    private var synthesizer = AVSpeechSynthesizer()
    var lastString = ""
    
    @IBOutlet var textView : UITextView!
    @IBOutlet var recordButton : UIButton!
        
    // MARK: UIViewController
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
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
                @unknown default:
                    break
                }
            }
        }
    }

    private func startRecording() throws {
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSession.Category.playAndRecord)
        try audioSession.setMode(AVAudioSession.Mode.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = self.audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            if let result = result {
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
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        textView.text = "(Go ahead, I'm listening)"
    }
     
    func stopSpeaking() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    func saySpeechSynthesizer(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            let myUtterance = AVSpeechUtterance(string: text)
            myUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
            myUtterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            myUtterance.pitchMultiplier = 1
            myUtterance.volume = 1
            DispatchQueue.main.async {
                self.synthesizer.speak(myUtterance)
            }
        }
    }
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            recordButton.setTitle("Stop recording", for: [])
        }
    }
}

extension HomeViewController: CXCallObserverDelegate {
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded == true {
            print("Disconnected")
            do {
                try startRecording()
            } catch let error {
                print("Starting error: \(error.localizedDescription)")
            }
        }
        if call.isOutgoing == true && call.hasConnected == false {
            print("Dialing")
            self.stopSpeaking()
        }
        if call.isOutgoing == false && call.hasConnected == false && call.hasEnded == false {
            print("Incoming")
            self.stopSpeaking()
        }

        if call.hasConnected == true && call.hasEnded == false {
            print("Connected")
            self.stopSpeaking()
        }
    }
}
