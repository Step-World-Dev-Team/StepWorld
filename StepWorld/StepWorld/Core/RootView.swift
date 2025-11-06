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
    @State private var authHandle: AuthStateDidChangeListenerHandle?

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
       
        .onAppear {
                    authHandle = Auth.auth().addStateDidChangeListener { _, user in
                        Task { @MainActor in
                            let signedIn = (user != nil)
                            isSignedIn = signedIn
                            if signedIn, let authed = try? AuthenticationManager.shared.getAuthenticatedUser() {
                                stepManager.userId = authed.uid
                                mapManager.userId  = authed.uid   // propagates to scene via didSet, if you added that
                                try? await mapManager.loadFromFirestoreIfAvailable()
                            } else {
                                stepManager.userId = nil
                                mapManager.userId  = nil
                                mapManager.scene.userId = nil
                            }
                            print("👂 Auth state changed → signedIn=\(signedIn)")
                        }
                    }
                }
                .onDisappear {
                    if let h = authHandle {
                        Auth.auth().removeStateDidChangeListener(h)
                        authHandle = nil
                    }
                }
    }
}
