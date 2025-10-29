//
//  MapManager.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.

import SpriteKit
import Foundation

final class MapManager {

    private var scene: GameScene?
    private var skView: SKView?

    init(skView: SKView) {
        self.skView = skView
        setupScene()
    }

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
    }

    // MARK: - Load Buildings from Backend
    func loadBuildingData(_ data: [[String: Any]]) {
        guard let scene = scene else { return }

        for item in data {
            guard
                let type = item["type"] as? String,
                let x = item["x"] as? CGFloat,
                let y = item["y"] as? CGFloat
            else { continue }

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
}
