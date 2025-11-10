//
//  DecorManager.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/7/25.
//
import SpriteKit

public final class DecorManager {

    // MARK: - Dependencies
    private weak var scene: SKScene?
    private weak var cameraNode: SKCameraNode?
    private let plotsProvider: () -> [SKShapeNode]   // provided by GameScene

    // MARK: - State
    private(set) var placed: [SKSpriteNode] = []
    private var placingType: String?
    private var previewNode: SKSpriteNode?
    private var menuRoot: SKNode?
    // MARK: - Menu state & callbacks
    public private(set) var isMenuOpen = false
    public var onMenuStateChanged: ((Bool) -> Void)?  // true = opened, false = closed

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

    // Spots
    private var spotsVisible = false

    // MARK: - Init
    public init(scene: SKScene,
                cameraNode: SKCameraNode,
                plotsProvider: @escaping () -> [SKShapeNode]) {
        self.scene = scene
        self.cameraNode = cameraNode
        self.plotsProvider = plotsProvider
    }
    public func toggleMenu() {
        isMenuOpen ? dismissMenu() : showDecorMenu()
    }
    
    

    // MARK: - Public API
    public func showDecorMenu() {
        dismissMenu()

        let menu = SKNode(); menu.zPosition = 10_001
        cameraNode?.addChild(menu)
        menuRoot = menu

        let buttonsBlockH = CGFloat(availableDecor.count) * (menuButtonH + menuGap) - menuGap
        let panelH = menuHeaderPad + buttonsBlockH + menuFooterPad
        let panelSize = CGSize(width: panelWidth, height: panelH)

        // panel
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 14)
        panel.fillColor = UIColor.systemBackground.withAlphaComponent(0.92)
        panel.strokeColor = .clear
        menu.addChild(panel)

        // title
        let title = SKLabelNode(text: "Choose Decoration")
        title.fontName = ".SFUI-Bold"
        title.fontSize = 18
        title.fontColor = .label
        title.position = CGPoint(x: 0, y: panelSize.height/2 - 36)
        menu.addChild(title)

        // buttons
        var y = panelSize.height/2 - menuHeaderPad - menuButtonH/2
        for name in availableDecor {
            let btn = makeButton(title: name, actionName: "decor:\(name)",
                                 size: CGSize(width: menuButtonW, height: menuButtonH))
            btn.position = CGPoint(x: 0, y: y)
            menu.addChild(btn)
            y -= (menuButtonH + menuGap)
        }

        // cancel
        let cancel = makeButton(title: "Cancel", actionName: "cancel",
                                size: CGSize(width: menuButtonW, height: menuButtonH),
                                isCancel: true)
        cancel.position = CGPoint(x: 0, y: -panelSize.height/2 + menuFooterPad/2)
        menu.addChild(cancel)
        // NEW: flip state + notify HUD
        isMenuOpen = true
        onMenuStateChanged?(true)
    }


    /// Call from GameScene.touchesEnded; returns true if handled
    @discardableResult
    public func handleMenuTap(_ tapped: [SKNode]) -> Bool {
        guard let _ = menuRoot else { return false }
        guard let node = tapped.first(where: { ($0.name ?? "").hasPrefix("decor:")
                                           || $0.name == "cancel" }) else { return false }

        let name = node.name ?? ""
        if name == "cancel" { dismissMenu(); return true }

        if name.hasPrefix("decor:") {
            let type = String(name.dropFirst("decor:".count))
            startPlacement(type: type)
            dismissMenu()
            return true
        }
        return false
    }

    public func startPlacement(type: String) {
        placingType = type
        ensureSpotsVisible(false)

        // ghost preview
        let ghost = SKSpriteNode(imageNamed: type)
        ghost.alpha = 0.6
        ghost.zPosition = 150
        ghost.setScale(1.5)
        ghost.name = "decorPreview"
        scene?.addChild(ghost)
        previewNode = ghost
    }
    // DecorManager.swift  (inside the class)
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
        // Optional: uncomment if you want to prevent crowding with other items
        // if overlapsExisting(at: p) { return false }
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
        scene.addChild(node)
        placed.append(node)

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
        ensureSpotsVisible(false)
    }

    public func rescaleBillboardsForCamera() {
        PlotSpotGenerator.rescaleBillboardSpots(in: plotsProvider(), cameraScale: cameraNode?.xScale ?? 1)
    }

    // Saving / Loading
    public func getDecorModels() -> [DecorItem] {
        placed.map { n in
            DecorItem(type: n.name ?? "decor",
                      position: n.position,
                      rotation: n.zRotation,
                      scale: n.xScale)
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

    // MARK: - Internals

    private func makeButton(title: String,
                            actionName: String,
                            size: CGSize,
                            isCancel: Bool = false) -> SKNode {
        let node = SKNode(); node.name = actionName
        let bg = SKShapeNode(rectOf: size, cornerRadius: 10)
        bg.fillColor = isCancel ? UIColor.systemGray5.withAlphaComponent(0.85)
                                : UIColor.systemGreen.withAlphaComponent(0.35)
        bg.strokeColor = isCancel ? UIColor.systemGray3 : .systemGreen
        bg.lineWidth = 1.5
        bg.name = actionName
        node.addChild(bg)

        let label = SKLabelNode(text: title)
        label.fontName = ".SFUI-Semibold"
        label.fontSize = 16
        label.fontColor = isCancel ? .label : .white
        label.verticalAlignmentMode = .center
        label.name = actionName
        node.addChild(label)
        return node
    }

    private func dismissMenu() {
        menuRoot?.removeFromParent(); menuRoot = nil
        if isMenuOpen {
            isMenuOpen = false
            onMenuStateChanged?(false)
        }
    }

    private func ensureSpotsVisible(_ visible: Bool) {
       /* spotsVisible = visible
        let plots = plotsProvider()
        if visible {
            // create if not there
            for plot in plots {
                if plot.childNode(withName: "spotsRoot") == nil {
                    let root = SKNode(); root.name = "spotsRoot"; root.zPosition = 900
                    plot.addChild(root)
                    let dots = PlotSpotGenerator.makeSpots(in: plot,
                                                           cols: 3, rows: 2,
                                                           inset: 14, radius: 7,
                                                           style: .visibleDots)
                    dots.forEach { root.addChild($0) }
                }
                // billboard scale
                PlotSpotGenerator.rescaleBillboardSpots(in: [plot], cameraScale: cameraNode?.xScale ?? 1)
                plot.childNode(withName: "spotsRoot")?.isHidden = false
            }
        } else {
            for plot in plots {
                plot.childNode(withName: "spotsRoot")?.isHidden = true
            }
        }
        */
    }

    private func snapToNearestSpot(_ scenePoint: CGPoint) -> CGPoint? {
        guard spotsVisible, let scene = scene else { return nil }
        let plots = plotsProvider()

        var best: (node: SKNode, d2: CGFloat)?
        for plot in plots {
            // convert scene point into plot's local space
            let local = plot.convert(scenePoint, from: scene)
            for spot in plot.children where spot.name == "decorSpot" {
                let d2 = hypot(local.x - spot.position.x, local.y - spot.position.y)
                let score = d2 * d2
                if best == nil || score < best!.d2 {
                    best = (spot, score)
                }
            }
        }
        guard let spot = best?.node else { return nil }
        // return spot’s world position
        return spot.parent?.convert(spot.position, to: scene)
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

