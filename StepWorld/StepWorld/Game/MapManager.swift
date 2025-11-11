//
//  MapManager.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.

import SpriteKit
import Foundation
import FirebaseAuth
import Combine

@MainActor
final class MapManager: ObservableObject {
    var userId: String?
    @Published var balance: Int = 0
    @Published var todaySteps: Int = 0
    
    let scene: GameScene
    private var pendingSave: DispatchWorkItem?
   
    init() {
        // one scene for the whole app session
                self.scene = GameScene(size: UIScreen.main.bounds.size)
                self.scene.scaleMode = .aspectFill
            
        if let uid = Auth.auth().currentUser?.uid {
            self.userId = uid
        }

                // wire the trigger once
                self.scene.onMapChanged = { [weak self] in
                    print("onMapChanged attempted")
                    self?.scheduleSave()
                }

                print("✅ MapManager initialized with shared GameScene.")
                //loadFromFirestoreIfAvailable()
    }
    
    // MARK: - Database Functions
    // debounce saves a bit to avoid spamming Firestore
    private func scheduleSave() {
        print("made it to scheduleSave")
        pendingSave?.cancel()
        
        let job = DispatchWorkItem { [weak self] in
            guard let self = self else {return}
            Task {
                do {try await self.saveMapForCurrentUser()
                    await self.refreshStepsAndBalance()
                } catch {
                    print("Save failed:", error.localizedDescription)
                }
            }
        }
        pendingSave = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: job)
    }
    
    private func saveMapForCurrentUser() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No signed-in user; skipping save.")
            return
        }

        let buildings = scene.getBuildingModels() // includes type/plot/x/y/level
        try await UserManager.shared.saveMapBuildings(userId: uid, buildings: buildings)
        print("Saved \(buildings.count) buildings to Firestore for \(uid).")
    }
    
    // refresh helper (steps + balance), called after save completes
    @MainActor
    private func refreshStepsAndBalance(date: Date = Date()) async {
        guard let uid = scene.userId ?? Auth.auth().currentUser?.uid else { return }
        
        let currentBalance = self.balance

        async let steps: Int = {
            do {
                if let m = try await UserManager.shared.getDailyMetrics(userId: uid, date: date) {
                    return m.stepCount
                } else { return 0 }
            } catch { return 0 }
        }()

        async let coins: Int = {
                do {
                    return try await UserManager.shared.getBalance(userId: uid)
                } catch {
                    return currentBalance // ✅ safe captured value
                }
            }()

        let (s, b) = await (steps, coins)
        await MainActor.run {
            self.todaySteps = s
            self.balance = b
        }
    }
    
    // MARK: - Load on startup (typed [Building] version)
    @MainActor
    func loadFromFirestoreIfAvailable() async throws{
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ℹ️ No signed-in user; skipping load.")
            return
        }

        Task {
            do {
                let buildings: [Building] = try await UserManager.shared.fetchMapBuildings(userId: uid)
                guard !buildings.isEmpty else {
                    print("ℹ️ No saved buildings yet.")
                    return
                }
                // We're on @MainActor already (MapManager is @MainActor), so just call it.
                self.loadBuildingData(buildings)
                print("✅ Loaded \(buildings.count) buildings from backend.")
            } catch {
                let ns = error as NSError
                print("❌ fetchMapBuildings failed:", ns.localizedDescription, ns.domain, ns.code, ns.userInfo)
            }
        }
    }
    
    // MARK: Refresh Functions
    // function to refresh at any point in time (public)
    func refreshNow(date: Date = Date()) async {
            guard let uid = scene.userId ?? Auth.auth().currentUser?.uid else { return }

            // ⬅️ capture while on MainActor
            let currentBalance = self.balance

            async let steps: Int = {
                do {
                    if let m = try await UserManager.shared.getDailyMetrics(userId: uid, date: date) {
                        return m.stepCount
                    } else { return 0 }
                } catch { return 0 }
            }()

            async let coins: Int = {
                do { return try await UserManager.shared.getBalance(userId: uid) }
                catch { return currentBalance }   // ⬅️ use snapshot
            }()

            let (s, b) = await (steps, coins)
            self.todaySteps = s
            self.balance = b
        print("ATTEMPTED REFRESH-NOW")
        }

    
    
    // MARK: - Apply buildings to the scene
    func loadBuildingData(_ buildings: [Building]) {
        // ✅ Delegate to GameScene’s built-in loader
        scene.applyLoadedBuildings(buildings)

        print("✅ Loaded \(buildings.count) buildings into GameScene via applyLoadedBuildings().")
    }
    
}
