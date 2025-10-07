//
//  StepWorldApp.swift
//  StepWorld
//
//  Created by Isai soria on 10/2/25.
//

import SwiftUI
import Firebase

@main
struct StepWorldApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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

