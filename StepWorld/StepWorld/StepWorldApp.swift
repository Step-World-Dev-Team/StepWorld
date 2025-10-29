//
//  StepWorldApp.swift
//  StepWorld
//
//  Created by Isai Soria on 10/2/25.
//

import SwiftUI
import Firebase

@main
struct StepWorldApp: App {
    
    @StateObject private var steps = StepManager()
    @StateObject private var map = MapManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            

            SignInView()
                .environmentObject(steps)
                .environmentObject(map)
            
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

