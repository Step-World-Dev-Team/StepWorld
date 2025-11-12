//
//  DecorItem.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/7/25.
//
import SpriteKit

public struct DecorItem: Codable {
    public let type: String          // e.g. "JackOLantern"
    public let position: CGPoint
    public let rotation: CGFloat
    public let scale: CGFloat

    public init(type: String, position: CGPoint, rotation: CGFloat = 0, scale: CGFloat = 0.5) {
        self.type = type
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    /*
    public func makeSprite() -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: type)
        node.position = position
        node.zRotation = rotation
        node.setScale(scale)
        node.zPosition = 2
        node.name = "decor"
        return node
    } */
    
    public func makeSprite() -> SKSpriteNode {
        let key = type.trimmingCharacters(in: .whitespacesAndNewlines)
        let node: SKSpriteNode

        if UIImage(named: key) != nil {
            node = SKSpriteNode(imageNamed: key)
        } else {
            print("❌ Missing decor texture for '\(key)'. Check asset name / target membership.")
            node = SKSpriteNode(color: .red, size: CGSize(width: 28, height: 28))
            let x = SKLabelNode(text: "X"); x.fontSize = 20; x.fontColor = .white; x.verticalAlignmentMode = .center
            node.addChild(x)
        }

        node.position = position
        node.zRotation = rotation
        node.setScale(scale)
        node.zPosition = 2
        node.name = "decor"
        if node.userData == nil { node.userData = [:] }
        node.userData?["type"] = key
        return node
    }
}

