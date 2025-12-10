//
//  building.swift
//  StepWorld
//
//  Created by Isai soria on 10/28/25.
//

import Foundation
import SpriteKit

struct Building: Codable {
    var type: String
    var plot: String
    var x: Double
    var y: Double
    var level: Int?   // optional so you don’t break old data
    var skin: String? // e.g. "Blue" for Barn, "Candy" for House
    var broken: Bool?
    var damaged: Bool //Maybe not used?
}

extension Building {
    init(node: SKSpriteNode) {
        self.type  = (node.userData?["type"] as? String) ?? "Unknown"
        self.plot  = (node.userData?["plot"] as? String) ?? "UnknownPlot"
        self.level = (node.userData?["level"] as? Int)
        self.skin  = (node.userData?["skin"] as? String)
        self.broken = (node.userData?["broken"] as? Bool) ?? false
        self.damaged = (node.userData?["damaged"] as? Bool) ?? false //maybe not used?
        self.x = Double(node.position.x)
        self.y = Double(node.position.y)
    }
    
    private func resolvedBaseName(type: String, skin: String?) -> String {
        switch (type, skin) {
        case ("Barn","Blue"):  return "BlueBarn"
        case ("House","Candy"):return "CandyHouse"
        default:               return type
        }
    }
    
    func makeSprite() -> SKSpriteNode {
        let base = resolvedBaseName(type: type, skin: skin)
        let lvl = (level ?? 1)
        let prefix = (broken ?? false) ? "Broken" : ""
        let name = prefix.isEmpty ? "\(base)_L\(lvl)" : "\(prefix)\(base)_L\(lvl)"

        // ---- CRISP TEXTURE LOADING ----
        let sprite: SKSpriteNode
        if UIImage(named: name) != nil {
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .nearest   // 👈 CRITICAL: no blur
            sprite = SKSpriteNode(texture: tex)
        } else {
            print("❌ Missing building texture '\(name)'")
            sprite = SKSpriteNode(color: .systemGreen, size: CGSize(width: 32, height: 32))
        }
        // --------------------------------

        if sprite.userData == nil { sprite.userData = [:] }
        sprite.userData?["type"]   = type
        sprite.userData?["plot"]   = plot
        sprite.userData?["skin"]   = skin ?? "Default"
        sprite.userData?["broken"] = (broken ?? false)
        if let lvl = level { sprite.userData?["level"] = lvl }

        sprite.position = CGPoint(x: x, y: y)
        sprite.name = "building"
        sprite.zPosition = 1
        return sprite
    }

}



