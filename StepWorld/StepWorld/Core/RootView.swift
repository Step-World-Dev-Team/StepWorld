//
//  RootView.swift
//  StepWorld
//
//  Created by Isai soria on 11/4/25.
//

import Foundation
import SwiftUI
import SpriteKit
import Foundation
import FirebaseAuth
import Combine

struct RootView: View {
    @EnvironmentObject var stepManager: StepManager
    @EnvironmentObject var mapManager: MapManager
    @AppStorage("remember_me") private var rememberMe: Bool = true

    @State private var isSignedIn = false

    var body: some View {
        Group {
            if isSignedIn {
                SpriteKitMapView()
                    .environmentObject(mapManager)
                    .environmentObject(stepManager)
            } else {
                SignInView()
            }
        }
        .task {
            if rememberMe,
               let authed = try? AuthenticationManager.shared.getAuthenticatedUser() {
                stepManager.userId = authed.uid
                mapManager.userId  = authed.uid
                try? await mapManager.loadFromFirestoreIfAvailable()
                isSignedIn = true
            }
        }
        // ✨ listen for the sign-out notification
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            do {
                try AuthenticationManager.shared.signOutUser()
            } catch {
                print("Sign-out failed: \(error)")
            }
            stepManager.userId = nil
            mapManager.userId = nil
            isSignedIn = false
        }
    }
}
