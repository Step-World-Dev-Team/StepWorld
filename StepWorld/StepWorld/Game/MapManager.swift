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
    
    //private var scene: GameScene?
    //private var skView: SKView?
    let scene: GameScene
    private var pendingSave: DispatchWorkItem?
   
    /*
     old logic that was breaking the view
    init(skView: SKView) {
        self.skView = skView
        setupScene()
        scene?.onMapChanged = { [weak self] in
            print("onMapChanged attempted")
            self?.scheduleSave() }
        loadFromFirestoreIfAvailable()
    }
     */

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
    
    // actual save
    private func saveMapForCurrentUser() async throws {
       //guard let scene = scene else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No signed-in user; skipping save.")
            return
        }
        
        let payload = scene.getBuildingData()
        let buildings = payload.compactMap { dict -> Building? in
            guard
                let type = dict["type"] as? String,
                let plot = dict["plot"] as? String
            else { return nil }
            let x = (dict["x"] as? CGFloat).map(Double.init) ?? (dict["x"] as? Double) ?? 0
            let y = (dict["y"] as? CGFloat).map(Double.init) ?? (dict["y"] as? Double) ?? 0
            let level = dict["level"] as? Int
            return Building(type: type, plot: plot, x: x, y: y, level: level)
        }
        print("Attempting save uid=\(uid) payload=\(payload)")
        Task {
            do {
                try await UserManager.shared.saveMapBuildings(userId: uid, buildings: buildings)
                print("Saved \(payload.count) buildings to Firestore for \(uid).")
            } catch {
                print("saveMapBuildings failed: \(error)")
            }
        }
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

    
    /*
    // load on startup
    private func loadFromFirestoreIfAvailable() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ℹ️ No signed-in user; skipping load.")
            return
        }
        Task {
            do {
                let data = try await UserManager.shared.fetchMapBuildings(userId: uid)
                guard !data.isEmpty else {
                    print("ℹ️ No saved buildings yet."); return
                }
                DispatchQueue.main.async { [weak self] in
                    self?.loadBuildingData(data)
                }
            } catch {
                print("❌ fetchMapBuildings failed: \(error)")
            }
        }
    }
     */
    
    // MARK: - Apply buildings to the scene (typed)
    func loadBuildingData(_ buildings: [Building]) {
        for b in buildings {
            let sprite = b.makeSprite()
            sprite.setScale(0.4)
            scene.addBuilding(sprite)
        }
    }
    
    // TODO: Bring these back
    /*
    func loadBuildingData(_ data: [[String: Any]]) {
            for item in data {
                guard let type = item["type"] as? String else { continue }
                let x = (item["x"] as? CGFloat) ?? .zero
                let y = (item["y"] as? CGFloat) ?? .zero

                let sprite: SKSpriteNode = UIImage(named: type) != nil
                ? SKSpriteNode(imageNamed: type)
                : SKSpriteNode(color: .systemGreen, size: CGSize(width: 32, height: 32))

                if sprite.userData == nil { sprite.userData = [:] }
                sprite.userData?["type"] = type
                sprite.position = CGPoint(x: x, y: y)
                sprite.name = "building"
                sprite.zPosition = 1
                sprite.setScale(0.4)

                scene.addBuilding(sprite)
            }
            print("✅ Loaded \(data.count) buildings from backend.")
        }
     */
    
   /*
    // MARK: - Setup Game Scene
    private func setupScene() {
        let scene = GameScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .aspectFill
        skView?.presentScene(scene)
        self.scene = scene
        print("✅ MapManager initialized and GameScene presented.")
    }
    
    // MARK: - Save Building Data
    func saveBuildingData() {
        guard let scene = scene else {
            print("⚠️ GameScene not initialized.")
            return
        }
        
        let buildingsJSON = scene.getBuildingData()
        print("📦 Collected \(buildingsJSON.count) buildings for saving.")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: buildingsJSON, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🗂️ Building JSON:\n\(jsonString)")
            }
            // TODO: upload jsonData to your backend here
        } catch {
            print("❌ Failed to encode building data: \(error)")
        }
        scheduleSave()
    }
    
    // MARK: - Load Buildings from Backend
    func loadBuildingData(_ data: [[String: Any]]) {
        guard let scene = scene else { return }
        
        for item in data {
            guard
                let type = item["type"] as? String
            else { continue }
            
            // Accept CGFloat OR Double/NSNumber (Firestore)
            let xNum: NSNumber? = (item["x"] as? NSNumber)
            let yNum: NSNumber? = (item["y"] as? NSNumber)
            let x: CGFloat
            let y: CGFloat
            if let xn = xNum, let yn = yNum {
                x = CGFloat(xn.doubleValue)
                y = CGFloat(yn.doubleValue)
            } else if let xcg = item["x"] as? CGFloat, let ycg = item["y"] as? CGFloat {
                x = xcg; y = ycg
            } else {
                continue
            }
            
            let sprite: SKSpriteNode
            if UIImage(named: type) != nil {
                sprite = SKSpriteNode(imageNamed: type)
            } else {
                sprite = SKSpriteNode(color: .systemGreen, size: CGSize(width: 32, height: 32))
            }
            if sprite.userData == nil { sprite.userData = [:] }
            sprite.userData?["type"] = type
            
            sprite.position = CGPoint(x: x, y: y)
            sprite.name = "building"
            sprite.zPosition = 1
            sprite.setScale(0.4)
            
            scene.addBuilding(sprite)
        }
        
        print("✅ Loaded \(data.count) buildings from backend.")
    }
    */
}
