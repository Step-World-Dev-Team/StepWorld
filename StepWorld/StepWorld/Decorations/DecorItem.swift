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

    public func makeSprite() -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: type)
        node.position = position
        node.zRotation = rotation
        node.setScale(scale)
        node.zPosition = 2
        node.name = "decor"
        return node
    }
}

