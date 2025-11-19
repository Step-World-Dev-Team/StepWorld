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
import FirebaseFirestore
import Combine

struct RootView: View {
    @EnvironmentObject var stepManager: StepManager
    @EnvironmentObject var mapManager: MapManager
    @AppStorage("remember_me") private var rememberMe: Bool = true
    @AppStorage("current_user_id") private var currentUserIdStore: String = ""

    
    @State private var isSignedIn = false
    @State private var authHandle: AuthStateDidChangeListenerHandle?
    
    // ⬇️ NEW: local+server gate for one-time onboarding
    
    @State private var showDifficulty = false
    @State private var currentUserId: String = ""
    
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
        .fullScreenCover(isPresented: $showDifficulty) {
            DifficultySelectionView(userId: currentUserId) {
                // Optional: refresh anything that depends on difficulty
            }
        }
        
        .onAppear {
            authHandle = Auth.auth().addStateDidChangeListener { _, user in
                Task { @MainActor in
                    let signedIn = (user != nil)
                    isSignedIn = signedIn
                    if signedIn, let user = user, let authed = try? AuthenticationManager.shared.getAuthenticatedUser() {
                        currentUserId = authed.uid
                        stepManager.userId = authed.uid
                        mapManager.userId  = authed.uid   // propagates to scene via didSet, if you added that
                        currentUserIdStore = authed.uid // added for difficulty view
                        try? await mapManager.loadFromFirestoreIfAvailable()
                        stepManager.syncToday()          // HealthKit → Firestore
                        await mapManager.refreshNow()    // Firestore → UI
                        
                        // ⬇️ NEW: decide if we need to show the difficulty screen
                        checkIfNeedsDifficulty(user: user)
                    } else {
                        stepManager.userId = nil
                        mapManager.userId  = nil
                        mapManager.scene.userId = nil
                        showDifficulty = false
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
    private func localHasChosenDifficulty(uid: String) -> Bool {
        UserDefaults.standard.bool(forKey: "hasChosenDifficulty.\(uid)")
    }
    
    private func checkIfNeedsDifficulty(user: FirebaseAuth.User) {
        // 1️⃣ New per-user local gate:
        if localHasChosenDifficulty(uid: user.uid) {
            showDifficulty = false
            return
        }
        
        // 2️⃣ Only show for truly NEW accounts (created very recently).
        let isNew: Bool = {
            guard let created = user.metadata.creationDate else { return false }
            // treat as "new" if created within the last 10 minutes
            return Date().timeIntervalSince(created) < 10 * 60
        }()
        
        guard isNew else {
            // Existing user → do not show
            showDifficulty = false
            return
        }
        
        // 3️⃣ New account → show difficulty picker
        showDifficulty = true
    }
}
