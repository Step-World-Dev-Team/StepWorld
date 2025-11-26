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
    @Published var lastSyncDate: Date? = nil
    
    @Published var difficulty: Difficulty = .easy
    @Published var dailyStepGoal: Int = Difficulty.easy.dailyStepGoal
    
    var scene: GameScene
    private var pendingSave: DispatchWorkItem?
    

    // MARK: Pop-Up Variables
    private let defaults = UserDefaults.standard
    private let kLastSeenSteps   = "last_seen_steps"
    private let kLastSeenBalance = "last_seen_balance"
    private let kLastSeenAt      = "last_seen_at"
   
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
        checkForDailyReset()
        
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
        
        
        let decor = scene.currentDecorModels()
        try await UserManager.shared.saveDecor(userId: uid, items: decor)
        
        print("Saved \(buildings.count) buildings & \(decor.count) decor to Firestore for \(uid).")
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
        async let diff: Difficulty? = {
              do {
                  return try await UserManager.shared.getDifficulty(userId: uid)
              } catch {
                  return nil
              }
          }()
        
        let (s, b, d) = await (steps, coins, diff)
        await MainActor.run {
            self.todaySteps = s
            self.balance = b
            self.applyDifficulty(d)
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
                
                let decor = try await UserManager.shared.fetchDecor(userId: uid)
                guard !decor.isEmpty else {
                    print("No saved decore yet.")
                    return
                }
                self.scene.applyLoadedDecor(decor)
                
                print("✅ Loaded \(buildings.count) buildings & \(decor.count) decor from backend.")
                
                do {
                    let state = try await UserManager.shared.fetchSkinState(userId: uid)
                    self.inventory.ownedSkins = Set(state.owned)
                    self.equipped = state.equipped
                    // Apply equipped skins to currently loaded buildings
                    await MainActor.run { [weak self] in
                        guard let s = self?.scene else { return }
                        for (base, skin) in state.equipped { s.equipSkin(baseType: base, skin: skin) }
                    }
                } catch {
                    print("fetchSkinState failed:", error.localizedDescription)
                }
            } catch {
                let ns = error as NSError
                print("❌ fetchMapBuildings failed:", ns.localizedDescription, ns.domain, ns.code, ns.userInfo)
            }
        }
    }
    
    @MainActor
    func resetScene() {
        print("🗑️ Resetting GameScene for new session")
        let newScene = GameScene(size: UIScreen.main.bounds.size)
        newScene.scaleMode = .aspectFill
        
        // rewire callback
        newScene.onMapChanged = { [weak self] in
            self?.scheduleSave()
        }
        
        // assign and keep reference
        self.scene = newScene
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
        async let diff: Difficulty? = {
                do { return try await UserManager.shared.getDifficulty(userId: uid) }
                catch { return nil }
            }()
        
        let (s, b, d) = await (steps, coins, diff)
        self.todaySteps = s
        self.balance = b
        self.applyDifficulty(d)
        print("ATTEMPTED REFRESH-NOW")
    }
    
    func checkForDailyReset() {
        let calendar = Calendar.current
        if let last = lastSyncDate {
            if !calendar.isDateInToday(last) {
                todaySteps = 0
            }
        } else {
            todaySteps = 0
        }
        lastSyncDate = Date()
    }
    // MARK: - Client Side inventory + purchase/equip
    //New Code
    struct Inventory {
        var ownedSkins: Set<String> = []         // "Barn#Blue", "House#Candy"
    }
    @Published var inventory = Inventory()
    @Published var equipped: [String:String] = [:]  // ["Barn":"Blue", "House":"Candy"]
    
    func purchaseSkin(baseType: String, skin: String, price: Int, userId: String) async {
        let key = "\(baseType)#\(skin)"
        guard !inventory.ownedSkins.contains(key) else { return }
        
        do {
            // Spend coins
            _ = try await UserManager.shared.spend(userId: userId, amount: price)
            
            // Update local state
            inventory.ownedSkins.insert(key)
            scene.unlockSkin(baseType: baseType, skin: skin)
            equipped[baseType] = skin
            await persistSkins()
            
            // 🔹 Achievement for first skin
            await AchievementsManager.shared.registerFirstSkinIfNeeded(userId: userId)
            print("✅ Purchased skin \(key)")
        } catch {
            print("❌ Purchase skin failed: \(error.localizedDescription)")
        }
    }

    func equipSkin(baseType: String, skin: String) {
        let key = "\(baseType)#\(skin)"
        guard inventory.ownedSkins.contains(key) else { return }
        scene.equipSkin(baseType: baseType, skin: skin)
        equipped[baseType] = skin
        Task { await persistSkins() }
    }
    
    func equipDefault(baseType: String) {
        scene.clearEquippedSkin(baseType: baseType)
        equipped.removeValue(forKey: baseType)
        Task { await persistSkins() }
    }
    
    
    // MARK: - Apply buildings to the scene
    func loadBuildingData(_ buildings: [Building]) {
        // ✅ Delegate to GameScene’s built-in loader
        scene.applyLoadedBuildings(buildings)
        
        print("✅ Loaded \(buildings.count) buildings into GameScene via applyLoadedBuildings().")
    }
    
    // MARK: Disaster Function
    func checkAndApplyDailyDisaster(now: Date = Date()) async {
        guard let uid = scene.userId ?? Auth.auth().currentUser?.uid else { return }
        
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else { return }
        
        do {
            // Fetch yesterday's metrics AND the user's difficulty in parallel
            async let metricsAsync = UserManager.shared.getDailyMetrics(userId: uid, date: yesterday)
            async let diffAsync    = UserManager.shared.getDifficulty(userId: uid)
            
            let (metrics, diff) = try await (metricsAsync, diffAsync)
            
            guard let m = metrics else {
                // No metrics for yesterday → treat as 0 steps if you want:
                // let goal = (diff ?? .easy).dailyStepGoal
                // if goal > 0 { ... quake ... }
                return
            }
            
            let already = m.disasterApplied ?? false
            let difficulty = diff ?? .easy
            let goal = difficulty.dailyStepGoal
            
            // 🔥 If yesterday's steps were below the goal and we haven't already quaked
            if m.stepCount < goal && !already {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    // Use the full earthquake with shake + building damage
                    self.scene.triggerEarthquake(
                        duration: 3.0,
                        breakProbability: 0.4,     // tweak: 0.0–1.0
                        affectAlreadyBroken: false // only hit intact buildings
                    )
                }
                
                // Save the new broken map + mark the disaster as applied
                try await saveMapForCurrentUser()
                try await UserManager.shared.setDisasterApplied(
                    userId: uid,
                    date: yesterday,
                    applied: true
                )
            }
        } catch {
            print("Disaster check failed:", error.localizedDescription)
        }
    }

    
    // MARK: Skin Persistency
    func persistSkins() async {
        guard let uid = scene.userId ?? Auth.auth().currentUser?.uid else { return }
        do {
            try await UserManager.shared.saveSkinState(userId: uid,
                                                       owned: inventory.ownedSkins,
                                                       equipped: equipped)
        } catch {
            print("saveSkinState failed:", error.localizedDescription)
        }
    }
    
    // MARK: Pop-Up Functions
    /// Current change vs. last time the user saw the app (not persisted).
    func pendingChangeSinceLastSeen() -> (steps: Int, balance: Int) {
        let lastS = defaults.object(forKey: kLastSeenSteps) as? Int ?? 0
        let lastB = defaults.object(forKey: kLastSeenBalance) as? Int ?? 0
        return (todaySteps - lastS, balance - lastB)
    }

    /// Call this when the popup is dismissed (i.e., the user has "seen" these values).
    func markStatsAsSeenNow() {
        defaults.set(todaySteps, forKey: kLastSeenSteps)
        defaults.set(balance,    forKey: kLastSeenBalance)
        defaults.set(Date().timeIntervalSince1970, forKey: kLastSeenAt)
    }
    //MARK: Difficulty Helpers
    private func applyDifficulty(_ diff: Difficulty?) {
           let resolved = diff ?? .easy
           difficulty = resolved
           dailyStepGoal = resolved.dailyStepGoal
       }
    
}
