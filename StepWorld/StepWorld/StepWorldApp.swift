//
//  StepWorldApp.swift
//  StepWorld
//
//  Created by Isai Soria on 10/2/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

@main
struct StepWorldApp: App {
    
    @StateObject private var steps = StepManager()
    @StateObject private var map = MapManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(steps)
                .environmentObject(map)
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { @MainActor in
                if let uid = Auth.auth().currentUser?.uid {
                    steps.userId = uid
                    map.userId   = uid
                    steps.syncToday()
                    await map.refreshNow()
                }
            }
        }
    }
    
}

// initilizes conneciton to FireBase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
}

