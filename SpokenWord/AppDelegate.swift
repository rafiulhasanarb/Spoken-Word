//
//  AppDelegate.swift
//  SpokenWord
//
//  Created by rafiul hasan on 19/10/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Get the singleton instance.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the audio session category, mode, and options.
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("Session is Active now")
        } catch {
            print("Failed to set audio session category.")
        }
//
//        do {
//            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: [.mixWithOthers, .duckOthers, .defaultToSpeaker])
//        } catch let error as NSError {
//          print("Error setting up AVAudioSession : \(error.localizedDescription)")
//        }
//
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay, .defaultToSpeaker])
            print("Playback OK")
            try AVAudioSession.sharedInstance().setActive(true)
            print("Session is Active")
        } catch {
            print(error.localizedDescription)
        }
        
        return true
    }
}
