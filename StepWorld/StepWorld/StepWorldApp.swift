//
//  StepWorldApp.swift
//  StepWorld
//
//  Created by Isai soria on 10/2/25.
//

import SwiftUI

@main
struct StepWorldApp: App {
    
    @StateObject private var steps = StepManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(steps)
        }
    }
}
