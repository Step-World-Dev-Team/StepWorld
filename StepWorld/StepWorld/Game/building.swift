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
}

extension Building {
    init(node: SKSpriteNode) {
        self.type  = (node.userData?["type"] as? String) ?? "Unknown"
        self.plot  = (node.userData?["plot"] as? String) ?? "UnknownPlot"
        self.level = (node.userData?["level"] as? Int)
        self.x = Double(node.position.x)
        self.y = Double(node.position.y)
    }
    
    func makeSprite() -> SKSpriteNode {
        // Try texture (with level if available), else placeholder
        let base = level != nil ? "\(type)_L\(level!)" : type
        let sprite: SKSpriteNode = UIImage(named: base) != nil
        ? SKSpriteNode(imageNamed: base)
        : SKSpriteNode(color: .systemGreen, size: CGSize(width: 32, height: 32))
        
        if sprite.userData == nil { sprite.userData = [:] }
        sprite.userData?["type"] = type
        sprite.userData?["plot"] = plot
        if let lvl = level { sprite.userData?["level"] = lvl }
        
        sprite.position = CGPoint(x: x, y: y)
        sprite.name = "building"
        sprite.zPosition = 1
        return sprite
    }
}



