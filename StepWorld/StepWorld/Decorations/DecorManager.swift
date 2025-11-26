//
//  DecorManager.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/7/25.
//
import SpriteKit
import FirebaseAuth

public final class DecorManager {
    
    // MARK: - Dependencies
    private weak var scene: SKScene?
    private weak var cameraNode: SKCameraNode?
    private let plotsProvider: () -> [SKShapeNode]   // provided by GameScene
    
    // MARK: - State
    private(set) var placed: [SKSpriteNode] = []
    private var placingType: String?
    private var previewNode: SKSpriteNode?
    
    
    // Customize choices here (image names in assets)
    //add png to Assets to get another item into Decoration menu
    public var availableDecor: [String] = ["JackOLantern", "SunFlower"]
    
    public var isPlacing: Bool { placingType != nil }
    
    
    
    // UI sizing (matches your existing style)
    private let panelWidth: CGFloat = 260
    private let menuButtonW: CGFloat = 220
    private let menuButtonH: CGFloat = 44
    private let menuGap: CGFloat = 10
    private let menuHeaderPad: CGFloat = 64
    private let menuFooterPad: CGFloat = 64
    
    
    // MARK: - Init
    public init(scene: SKScene,
                cameraNode: SKCameraNode,
                plotsProvider: @escaping () -> [SKShapeNode]) {
        self.scene = scene
        self.cameraNode = cameraNode
        self.plotsProvider = plotsProvider
    }
    
    
    public func startPlacement(type: String) {
        placingType = type
        
        // ghost preview
        let ghost = SKSpriteNode(imageNamed: type)
        ghost.alpha = 0.6
        ghost.zPosition = 150
        ghost.setScale(1.5)
        ghost.name = "decorPreview"
        scene?.addChild(ghost)
        previewNode = ghost
    }
    public func movePreview(to scenePoint: CGPoint) {
        guard let ghost = previewNode else { return }
        ghost.position = scenePoint
        
        // Optional: live validity tint (green = ok, red = blocked by plot)
        if canPlace(at: scenePoint) {
            ghost.alpha = 0.75
            ghost.color = .green
            ghost.colorBlendFactor = 0.25
        } else {
            ghost.alpha = 0.35
            ghost.color = .red
            ghost.colorBlendFactor = 0.35
        }
    }
    
    
    // MARK: - Validation
    
    private func canPlace(at p: CGPoint) -> Bool {
        if isInsideAnyBuildingPlot(scenePoint: p) { return false }
        return true
    }
    
    private func isInsideAnyBuildingPlot(scenePoint p: CGPoint) -> Bool {
        guard let scene = scene else { return false }
        for plot in plotsProvider() {
            if let path = plot.path {
                let local = plot.convert(p, from: scene)
                if path.contains(local) { return true }
            }
        }
        return false
    }
    
    private func overlapsExisting(at p: CGPoint) -> Bool {
        guard let scene = scene else { return false }
        let testRect = CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)
        
        // Against placed decor
        for n in placed {
            if n.calculateAccumulatedFrame().intersects(testRect) { return true }
        }
        // Against buildings (if you name them "building")
        for child in scene.children where child.name == "building" {
            if child.calculateAccumulatedFrame().intersects(testRect) { return true }
        }
        return false
    }
    
    @discardableResult
    public func confirmPlacement(at scenePoint: CGPoint) -> Bool {
        guard let type = placingType, let scene = scene else { return false }
        
        // If you kept a ghost, drop it to this point for a consistent result:
        previewNode?.position = scenePoint
        
        // Validate: disallow inside building plots (and optional overlap checks)
        guard canPlace(at: scenePoint) else {
            // Optional feedback: quick shake if invalid
            if let ghost = previewNode {
                let l = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
                ghost.run(.sequence([l, l.reversed(), l, l.reversed()]))
            }
            return false
        }
        
        // Place final node
        let node = SKSpriteNode(imageNamed: type)
        node.position = scenePoint
        node.zPosition = 2
        // Match preview scale if you kept it; otherwise set your preferred scale:
        if let ghost = previewNode { node.setScale(ghost.xScale) } else { node.setScale(0.8) }
        node.name = "decor"
        
        if node.userData == nil { node.userData = [:] }
        node.userData?["type"] = type
        
        scene.addChild(node)
        placed.append(node)
        
        // Achievement - First Decor Item
        if let gameScene = scene as? GameScene {
            if let uid = gameScene.userId ?? Auth.auth().currentUser?.uid {
                Task {
                    await AchievementsManager.shared.registerFirstDecorIfNeeded(userId: uid)
                }
            }
        }
        
        // Cleanup placement state
        previewNode?.removeFromParent(); previewNode = nil
        placingType = nil
        
        pulseOnce(at: scenePoint)  // nice feedback ring
        return true
    }
    
    public func cancelPlacement() {
        previewNode?.removeFromParent()
        previewNode = nil
        placingType = nil
    }
    
    public func rescaleBillboardsForCamera() {
        PlotSpotGenerator.rescaleBillboardSpots(in: plotsProvider(), cameraScale: cameraNode?.xScale ?? 1)
    }
    
    // Saving / Loading
    public func getDecorModels() -> [DecorItem] {
        placed.map { n in
            let savedType = (n.userData?["type"] as? String) ?? n.name ?? "decor"
            return DecorItem(
                type: savedType,
                position: n.position,
                rotation: n.zRotation,
                scale: n.xScale
            )
        }
    }
    
    public func applyLoadedDecor(_ models: [DecorItem]) {
        guard let scene = scene else { return }
        for m in models {
            let node = m.makeSprite()
            scene.addChild(node)
            placed.append(node)
        }
    }
    
    private func pulseOnce(at position: CGPoint) {
        guard let scene = scene else { return }
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = position
        ring.strokeColor = UIColor.white.withAlphaComponent(0.7)
        ring.lineWidth = 2
        ring.glowWidth = 8
        ring.alpha = 0
        ring.zPosition = 999
        scene.addChild(ring)
        
        let appear = SKAction.group([
            .fadeAlpha(to: 1.0, duration: 0.1),
            .scale(to: 1.2, duration: 0.1)
        ])
        let vanish = SKAction.group([
            .fadeOut(withDuration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ])
        ring.run(.sequence([appear, vanish, .removeFromParent()]))
    }
}

