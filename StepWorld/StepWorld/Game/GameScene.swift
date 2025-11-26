//
//  GameScene.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.

import SpriteKit
import UIKit
import FirebaseAuth
import AVFoundation

/// Requires TMXPlotLoader.swift in the same target (with top-level TMXMapInfo & PlotObject).

final class GameScene: SKScene {

    // MARK: - Config
    private let tmxName = "BiggerMap"
    private let plotLayerName = "Building"        // must match Tiled Object Layer name exactly

    private let minZoom: CGFloat = 0.25 // was 0.55
    private let maxZoom: CGFloat = 0.7  // was 2.5
    private let initialZoom: CGFloat = 0.55 // was 0.95      // a bit more zoom for visual appeal

    // Plot visuals (subtle)
    private let plotGlow: CGFloat = 6.0           // was 16 (softer)
    private let ringScale: CGFloat = 1.02
    private let ringAlpha: CGFloat = 0.35

    // Camera inertia
    private let inertiaDampingPer60FPS: CGFloat = 0.92

    // Build menu layout
    private let panelWidth: CGFloat = 280
    private let menuButtonW: CGFloat = 200
    private let menuButtonH: CGFloat = 44
    private let menuGap: CGFloat = 10
    private let menuHeaderPad: CGFloat = 64
    private let menuFooterPad: CGFloat = 128

    // Building scale: House & Barn at 2× prior (0.8 vs 0.4)
    private let baseBuildingScale: CGFloat = 0.6
    private let buildingScaleOverrides: [String: CGFloat] = [
        "House": 1,
        "Barn":  1,
        "Farm": 1
    ]

    // MARK: - Data
    private(set) var buildings: [SKSpriteNode] = []
    private var selectedPlot: SKShapeNode?
    private var tmxPlots: [PlotObject] = []

    // MARK: - Camera / world
    private let cameraNode = SKCameraNode()
    private var background: SKSpriteNode!
    private var mapInfo: TMXMapInfo?
    private var didSetup = false

    // MARK: - Plots
    private var plotNodes: [SKShapeNode] = []

    // MARK: - HUD
    private let hudRoot = SKNode()
    private var hudLabel: SKLabelNode?

    // MARK: - Build menu
    var buildMenu: SKNode?
    private let availableBuildings = ["Barn", "House", "Farm"]
    private let panelSprite  = "build_menu_background"
    private let buttonSprite = "clear_button"
    private let buttonSpriteCancel = "cancel_button"
    private let titleToListGap: CGFloat = 8   // space between the title and the first button

    // MARK: - Gestures / inertia
    private var pinchGR: UIPinchGestureRecognizer?
    private var panGR: UIPanGestureRecognizer?
    private var panVelocity = CGPoint.zero
    private var lastUpdateTime: TimeInterval = 0
    
    //decorations
    private var decorManager: DecorManager!
    
    //Allows decor to hover on map while finding place to place it
    @available(iOS 13.4, *)
    private var hoverGR: UIHoverGestureRecognizer?

    
    // MARK: - Database
    var onMapChanged: (() -> Void)?
    var userId: String?
    
    
    //New code
    // MARK: - Skins (ownership + currently equipped per base type)
    private(set) var ownedSkins = Set<String>()               // e.g. "Barn#Blue", "House#Candy"
    private var equippedSkinForType: [String: String] = [:]   // ["Barn":"Blue", "House":"Candy"]

    func unlockSkin(baseType: String, skin: String) {
        ownedSkins.insert("\(baseType)#\(skin)")
        equippedSkinForType[baseType] = skin  // auto-equip on purchase
        applySkinToAllBuildings(of: baseType, skin: skin) // <- repaint existing now
    }

    func equipSkin(baseType: String, skin: String) {
        guard ownedSkins.contains("\(baseType)#\(skin)") else { return }
        equippedSkinForType[baseType] = skin
        applySkinToAllBuildings(of: baseType, skin: skin) // <- repaint existing now
    }
    
    func clearEquippedSkin(baseType: String) {
        equippedSkinForType.removeValue(forKey: baseType)
        applySkinToAllBuildings(of: baseType, skin: nil)  // <- revert existing now
    }
    
    // Apply a (new) equipped skin to all existing buildings of this base type.
    // If `skin` is nil, revert them to default art and clear userData["skin"].
    private func applySkinToAllBuildings(of baseType: String, skin: String?) {
        for node in buildings {
            let type = (node.userData?["type"] as? String) ?? ""
            guard type == baseType else { continue }
            let level = (node.userData?["level"] as? Int) ?? 1

            // Resolve the sprite type name from baseType + optional skin
            let resolvedType: String
            switch (baseType, skin) {
            case ("Barn",  "Blue"):  resolvedType = "BlueBarn"
            case ("House", "Candy"): resolvedType = "CandyHouse"
            default:                 resolvedType = baseType
            }
            // let texName = "\(resolvedType)_L\(level)" Old
            let isBroken = (node.userData?["broken"] as? Bool) ?? false
            let texName = isBroken ? "Broken\(resolvedType)_L\(level)" : "\(resolvedType)_L\(level)"

            if UIImage(named: texName) != nil {
                node.texture = SKTexture(imageNamed: texName)
                node.size = node.texture!.size()
                // persist/clear the skin on the node so upgrades follow the correct path
                if node.userData == nil { node.userData = [:] }
                if let s = skin { node.userData?["skin"] = s } else { node.userData?.removeObject(forKey: "skin") }
            } else {
                print("⚠️ Missing texture \(texName)")
            }
        }
        triggerMapChanged()
    }

    //New Code
    
    private func triggerMapChanged() {
        onMapChanged?()
    }
    //requires two fingers to drag map so decorations can be moved
    private func updatePanBehaviorForPlacement() {
        if decorManager?.isPlacing == true {
            panGR?.minimumNumberOfTouches = 2   // two-finger pan while placing
        } else {
            panGR?.minimumNumberOfTouches = 1   // normal map pan
        }
    }
    
    // helpers for resolving skins
    private func resolvedSpriteBase(type: String, skin: String?) -> String {
        switch (type, skin) {
        case ("Barn","Blue"):  return "BlueBarn"
        case ("House","Candy"): return "CandyHouse"
        default: return type
        }
    }

    private func textureName(baseType: String, skin: String?, level: Int?, damaged: Bool) -> String {
        let base = resolvedSpriteBase(type: baseType, skin: skin)
        if damaged {
            // Provide broken variants in Assets, e.g. "Barn_Broken_L1"
            if let lvl = level { return "\(base)_Broken_L\(lvl)" }
            return "\(base)_Broken"
        } else {
            if let lvl = level { return "\(base)_L\(lvl)" }
            return base
        }
    }


    // MARK: - Sound
    private var bgm: SKAudioNode?

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.ambient` lets your game respond to system volume and mix with other audio
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            print("🎧 Audio session configured for ambient mix mode")
        } catch {
            print("⚠️ Could not set audio session:", error)
        }
    }
    
    private func playLoopingSFX(_ name: String,
                                loops: Int = 1,
                                volume: CGFloat = 1.0,
                                clipDuration: TimeInterval = 1.0) {
        // assumes your sound files are .mp3 (you can change this to "wav" if needed)
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("❌ Missing sound \(name).mp3 in bundle.")
            return
        }

        let node = SKAudioNode(url: url)
        node.isPositional = false
        addChild(node)

        // fade in quickly, wait for total playtime (loops × clip length), then fade out & remove
        node.run(.sequence([
            .changeVolume(to: Float(volume), duration: 0.05),
            .wait(forDuration: clipDuration * Double(loops)),
            .changeVolume(to: 0.0, duration: 0.3),
            .removeFromParent()
        ]))
    }

    // MARK: - Earthquake (shake-only stub)
    private var isQuakeShaking = false

    func triggerEarthquakeShake(duration: TimeInterval = 3.0,
                                amplitudeX: CGFloat = 22,
                                amplitudeY: CGFloat = 6) {
        guard !isQuakeShaking, let cam = camera else { return }
        isQuakeShaking = true

        playLoopingSFX("earthquake", loops: 1, volume: 0.9, clipDuration: 3.0)
        
        let original = cam.position
        let step: TimeInterval = 0.03
        let iterations = max(1, Int(duration / step))
        var actions: [SKAction] = []

        for i in 0..<iterations {
            // ease-out falloff so it starts strong and settles
            let t = CGFloat(i) / CGFloat(max(1, iterations - 1))
            let falloff = 1 - t * t
            let dx = CGFloat.random(in: -amplitudeX...amplitudeX) * falloff
            let dy = CGFloat.random(in: -amplitudeY...amplitudeY) * falloff
            actions.append(.move(to: CGPoint(x: original.x + dx, y: original.y + dy), duration: step))
        }
        actions.append(.move(to: original, duration: 0.08))

        cam.run(.sequence(actions)) { [weak self] in
            self?.isQuakeShaking = false
        }
    }


    
    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        // Run setup only once per scene instance
        // fix for crashing on signup
        guard !didSetup else { return }
        didSetup = true
        
        backgroundColor = .black

        // Background (gets resized to TMX map so overlays align)
        background = SKSpriteNode(imageNamed: "FarmBackground")
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.position = .zero
        background.zPosition = -10
        addChild(background)
        
        // start background music
        configureAudioSession()
        
        let music = SKAudioNode(fileNamed: "town_bgm")
        music.autoplayLooped = true
        music.isPositional = false
        music.run(.changeVolume(to: 0.5, duration: 0))
        addChild(music)
        music.name = "BackgroundMusic"
        bgm = music
        print("🎵 Music node added to scene: \(music)")
        

        decorManager = DecorManager(
            scene: self,
            cameraNode: cameraNode,
            plotsProvider: { [weak self] in self?.plotNodes ?? [] })

        // Camera
        if camera == nil { camera = cameraNode }
        if cameraNode.parent == nil { addChild(cameraNode) }
        cameraNode.setScale(initialZoom)
        rescaleWorldBillboardsForCamera()
        centerCamera()
        clampCameraToMap()

        // HUD
        setupHUD()

        // Gestures
        if pinchGR == nil {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture(_:)))
            pinch.cancelsTouchesInView = false
            pinch.delaysTouchesBegan = false
            pinch.delaysTouchesEnded = false
            view.addGestureRecognizer(pinch); pinchGR = pinch
        }
        
        if panGR == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
            view.addGestureRecognizer(pan); panGR = pan
        }
        
        // Build plots from TMX; fallback if none so you always see something
        let hadPlots = buildPlotsFromTMX()
        if !hadPlots { buildDebugPlots() }
        
        print("✅ GameScene ready. plots=\(plotNodes.count) zoom=\(cameraNode.xScale)")
        
        //for decor hover
        if #available(iOS 13.4, *) {
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(hoverMoved(_:)))
            hover.cancelsTouchesInView = false
            view.addGestureRecognizer(hover)
            self.hoverGR = hover
        }
    }
    
    // When the scene is about to leave a view, clean up recognizers so we don't duplicate them later.
    override func willMove(from view: SKView) {
        if let pinch = pinchGR { view.removeGestureRecognizer(pinch); pinchGR = nil }
        if let pan = panGR { view.removeGestureRecognizer(pan); panGR = nil }
    }

    // MARK: - TMX → plots

    /// Convert Tiled pixel coords (origin top-left) → SpriteKit scene (origin center, Y up)
    private func scenePoint(fromTiledPixel pt: CGPoint, mapInfo: TMXMapInfo) -> CGPoint {
        let mapW = mapInfo.pixelSize.width
        let mapH = mapInfo.pixelSize.height
        let left = -mapW * 0.5
        let top  =  mapH * 0.5
        return CGPoint(x: left + pt.x, y: top - pt.y)
    }
    
    // MARK: - Plot rules
    
    
    private struct PlotRule {
        let allowed: [String]
        let maxLevel: [String: Int]
        let anchor: CGPoint
        let perBuildingAnchor: [String: CGPoint]
    }

    private var plotRules: [String: PlotRule] = [
        // Example names match what you assign in TMX or in buildDebugPlots()
        // "top left plot" / "plot 1" → use the actual names you see in logs
        "Plot01": PlotRule(
                    allowed: ["House"],
                    maxLevel: ["House": 2],
                    anchor: CGPoint(x: 0.50, y: 0.6),
                    perBuildingAnchor: [:]),
        "Plot02": PlotRule(
            allowed: ["Barn", "House"],
            maxLevel: ["Barn": 4, "House": 2],
            anchor: CGPoint(x: 0.5, y: 0.5),
            perBuildingAnchor: ["Barn": CGPoint(x: 0.55, y: 0.55)]),
        "Plot03": PlotRule(
                    allowed: ["Barn", "House"],
                    maxLevel: ["Barn": 4, "House": 2],
                    anchor: CGPoint(x: 0.5, y: 0.5),
                    perBuildingAnchor: ["Barn": CGPoint(x: 0.50, y: 0.55)])
        // Add more as needed...
    ]
    
    private func positionFor(assetName: String, on plot: SKShapeNode) -> CGPoint {
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        let rule = plotRules[plotName]
        let base = rule?.anchor ?? CGPoint(x: 0.5, y: 0.5)
        let perType = rule?.perBuildingAnchor[assetName]
        let anchor = perType ?? base

        // Need the plot size to compute an offset from the plot center
        let size = (plot.userData?["plotSize"] as? NSValue)?.cgSizeValue ?? .zero

        // Convert normalized anchor → local offset from center:
        // (0.5,0.5) is center → (0,0) offset. (1,1) is top-right → (+halfW,+halfH)
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let local = CGPoint(
            x: (anchor.x - 0.5) * (size.width),
            y: (anchor.y - 0.5) * (size.height)
        )

        // Plot node is already centered at the plot’s center
        return CGPoint(x: plot.position.x + local.x,
                       y: plot.position.y + local.y)
    }
    
    

    /// Build centered, full-size plot overlays from the TMX object layer
    @discardableResult
    private func buildPlotsFromTMX() -> Bool {
        guard let (info, plotObjs) = TMXPlotLoader.load(tmxNamed: tmxName, plotLayerName: plotLayerName) else {
            print("⚠️ TMX not found or layer '\(plotLayerName)' missing.")
            return false
        }
        self.mapInfo = info
        self.tmxPlots = plotObjs

        background.size = info.pixelSize
        

        // Clear previous
        plotNodes.forEach { $0.removeFromParent() }
        plotNodes.removeAll()

        // Optional border (debug)
        let border = SKShapeNode(rectOf: info.pixelSize)
        border.strokeColor = .white
        border.lineWidth = 1.0
        border.zPosition = -1
        addChild(border)
        

        for p in plotObjs {
            let rect = p.rectPx
            print("TMX Plot '\(p.name)' px rect:", rect)
            if rect.width < 32 || rect.height < 32 {
                print("Plot '\(p.name)' is very small. In Tiled, make sure it's a Rectangle object with real size.")
            }

            let centerPx = CGPoint(x: rect.midX, y: rect.midY)
            let center   = scenePoint(fromTiledPixel: centerPx, mapInfo: info)
            let size     = rect.size

            let plot = SKShapeNode(rectOf: size, cornerRadius: 10)
            plot.position = center
            plot.name = "plot"
            plot.zPosition = 5

            if plot.userData == nil { plot.userData = [:] }
            plot.userData?["plotName"] = p.name
            plot.userData?["plotSize"] = NSValue(cgSize: size)

            addChild(plot)
            plotNodes.append(plot)

            stylePlot(plot, size: size)

            // Plot name label (kept constant-size on screen)
            if !p.name.isEmpty {
                let nameLabel = SKLabelNode(text: p.name)
                nameLabel.fontName = "PressStart2P-Regular"
                nameLabel.fontSize = 14
                nameLabel.fontColor = .white
                nameLabel.verticalAlignmentMode = .top
                nameLabel.horizontalAlignmentMode = .center
                nameLabel.position = CGPoint(x: 0, y: size.height/2 - 6)
                nameLabel.zPosition = 20
                nameLabel.setScale(1.0 / cameraNode.xScale)
                nameLabel.name = "plotNameLabel"
                nameLabel.alpha = 0; // makes plot name invisible to player
                plot.addChild(nameLabel)
                
                if !isPlotOccupied(plot) {
                    attachForSaleSign(to: plot, plotSize: size)
                }

            }
        }

        print("✅ TMX plots built: \(plotNodes.count). Map=\(Int(info.pixelSize.width))x\(Int(info.pixelSize.height))")
        return !plotNodes.isEmpty
    }

    /// Fallback visible plots if TMX layer wasn’t found
    private func buildDebugPlots() {
        let assumed = CGSize(width: 53*16, height: 36*16)
        if mapInfo == nil {
            let border = SKShapeNode(rectOf: assumed)
            border.strokeColor = .white
            border.lineWidth = 1.0
            border.zPosition = -1
            addChild(border)
            background.size = assumed
        }

        let size = CGSize(width: 240, height: 160)
        let dx: CGFloat = 280
        let centers = [CGPoint(x: -dx, y: 0), .zero, CGPoint(x: dx, y: 0)]
        let names = ["Plot01","Plot02","Plot03"]

        for (i, c) in centers.enumerated() {
            let p = SKShapeNode(rectOf: size, cornerRadius: 10)
            p.position = c
            p.name = "plot"
            if p.userData == nil { p.userData = [:] }
            p.userData?["plotName"] = names[i]
            addChild(p)
            plotNodes.append(p)
            stylePlot(p, size: size)
            if !isPlotOccupied(p) {
                attachForSaleSign(to: p, plotSize: size)
            }


            let label = SKLabelNode(text: names[i])
            label.fontName = "PressStart2P-Regular"
            label.fontSize = 14
            label.fontColor = .white
            label.verticalAlignmentMode = .top
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: size.height/2 - 6)
            label.zPosition = 20
            label.setScale(1.0 / cameraNode.xScale)
            label.name = "plotNameLabel"
            p.addChild(label)
        }
        print("🟠 DEBUG: Using 3 fallback plots (no object layer found).")
    }
    // MARK: - Plot styling
    private func stylePlot(_ plot: SKShapeNode, size: CGSize) {
        
        plot.fillColor = UIColor.white.withAlphaComponent(0.001) // invisible but hittable
        plot.strokeColor = .clear
        plot.lineWidth = 0
        plot.glowWidth = 0
        plot.blendMode = .alpha

        _ = getOrCreateRing(on: plot, size: size)    // create once, hidden
        ensureCornerBrackets(on: plot, size: size, visible: false)

    }
    private func getOrCreateRing(on plot: SKShapeNode, size: CGSize) -> SKShapeNode {
        if let existing = plot.childNode(withName: "pulseRing") as? SKShapeNode {
            return existing
        }

        let ringSize = CGSize(width: size.width * ringScale, height: size.height * ringScale)
        let ring = SKShapeNode(rectOf: ringSize, cornerRadius: 10)
        ring.name = "pulseRing"
        ring.strokeColor = UIColor.white.withAlphaComponent(0.9)
        ring.lineWidth = 1.2
        ring.glowWidth = 8.0
        ring.alpha = 0.6
        ring.isHidden = true
        ring.zPosition = 12

        let up   = SKAction.group([
            .fadeAlpha(to: 0.5, duration: 1.4),
            .scale(to: 1.03, duration: 1.4)
        ])
        let down = SKAction.group([
            .fadeAlpha(to: 0.25, duration: 1.4),
            .scale(to: 1.00, duration: 1.4)
        ])
        ring.run(.repeatForever(.sequence([up, down])))

        plot.addChild(ring)
        return ring
    }
    
    private func setPlotSelected(_ plot: SKShapeNode, selected: Bool) {
        let size = (plot.path?.boundingBox.size) ?? .zero
        ensureCornerBrackets(on: plot, size: size, visible: selected)

        if let ring = plot.childNode(withName: "pulseRing") {
            ring.isHidden = !selected
        }

        // no border, no fill
        plot.strokeColor = .clear
        plot.fillColor = .clear
    }



    private func ensureCornerBrackets(on plot: SKShapeNode, size: CGSize, visible: Bool) {
        if let existing = plot.childNode(withName: "cornerBrackets") {
            existing.isHidden = !visible
            return
        }

        let tex = SKTexture(imageNamed: "PlotCorner") // your bracket image in Assets
        let container = SKNode()
        container.name = "cornerBrackets"
        container.zPosition = 999
        container.isHidden = !visible
        plot.addChild(container)

        let bracketSize = CGSize(width: 18, height: 18) // tweak to your art

        func makeCorner(x: CGFloat, y: CGFloat, flipX: Bool, flipY: Bool) -> SKSpriteNode {
            let n = SKSpriteNode(texture: tex)
            n.size = bracketSize
            n.position = CGPoint(x: x, y: y)
            n.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            n.xScale = flipX ? -1 : 1
            n.yScale = flipY ? -1 : 1
            return n
        }

        let halfW = size.width  * 0.5
        let halfH = size.height * 0.5
        let inset: CGFloat = 2

        let tl = makeCorner(x: -halfW + inset, y:  halfH - inset, flipX: false, flipY: true)
        let tr = makeCorner(x:  halfW - inset, y:  halfH - inset, flipX: true,  flipY: true)
        let bl = makeCorner(x: -halfW + inset, y: -halfH + inset, flipX: false, flipY: false)
        let br = makeCorner(x:  halfW - inset, y: -halfH + inset, flipX: true,  flipY: false)

        [tl, tr, bl, br].forEach { container.addChild($0) }
    }

    // MARK: - HUD
    private func setupHUD() {
        hudRoot.zPosition = 10_000
        cameraNode.addChild(hudRoot)
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.horizontalAlignmentMode = .right
        label.verticalAlignmentMode = .top
        label.fontSize = 14
        label.fontColor = .white
        label.text = plotNodes.isEmpty
        ? "⚠️ 0 plots found — check TMX layer '\(plotLayerName)'"
        : "Plots: \(plotNodes.count)"
        label.position = CGPoint(x: size.width/2 - 10, y: size.height/2 - 10)
        hudRoot.addChild(label)
        hudLabel = label
        hudLabel?.isHidden = true
        
        }


    private func rescalePlotNameLabelsForCamera() {
        let inv = 1.0 / cameraNode.xScale
        for plot in plotNodes {
            for child in plot.children where child.name == "plotNameLabel" {
                child.setScale(inv)
            }
        }
    }

    // MARK: - Gestures
    @objc private func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        // Hide brackets / menus immediately when zooming begins
        if sender.state == .began {
            if selectedPlot != nil { clearSelection() }
            panVelocity = .zero // cancel inertia while pinching
        }

        guard let camera = camera else { return }

        if sender.state == .changed {
            var target = camera.xScale / sender.scale
            target = max(minZoom, min(maxZoom, target))
            camera.setScale(target)
            sender.scale = 1.0

            // If you keep plot-name labels around (alpha = 0), this keeps them crisp.
            rescalePlotNameLabelsForCamera()
            rescaleWorldBillboardsForCamera() //adjusts for sale sign to return as og size
            clampCameraToMap()
        }

        if sender.state == .ended || sender.state == .cancelled || sender.state == .failed {
            // no special action needed; leaving here for symmetry
        }
    }

   /* @objc private func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        guard let camera = camera else { return }
        if sender.state == .changed {
            var target = camera.xScale / sender.scale
            target = max(minZoom, min(maxZoom, target))
            camera.setScale(target)
            sender.scale = 1.0
            rescalePlotNameLabelsForCamera()
            clampCameraToMap()
        }
    }
    */
    private func clearSelection() {
        for p in plotNodes { setPlotSelected(p, selected: false) }
        selectedPlot = nil
        dismissBuildMenu()
    }

    @objc private func panGesture(_ sender: UIPanGestureRecognizer) {
        // 🔹 clear selection as soon as the user starts dragging the map
        if sender.state == .began, selectedPlot != nil {
            clearSelection()
        }

        guard let view = self.view else { return }
        let t = sender.translation(in: view)
        sender.setTranslation(.zero, in: view)

        cameraNode.position.x -= t.x * cameraNode.xScale
        cameraNode.position.y += t.y * cameraNode.yScale
        clampCameraToMap()

        if sender.state == .ended {
            let v = sender.velocity(in: view)
            panVelocity = CGPoint(x: -v.x * cameraNode.xScale, y: v.y * cameraNode.yScale)
        } else {
            panVelocity = .zero
        }
    }
    //makes ghost follow cursor
    @available(iOS 13.4, *)
    @objc private func hoverMoved(_ sender: UIHoverGestureRecognizer) {
        guard decorManager?.isPlacing == true, let view = self.view else { return }
        let pView  = sender.location(in: view)
        let pScene = convertPoint(fromView: pView)
        switch sender.state {
        case .began, .changed, .ended:
            decorManager?.movePreview(to: pScene)
        default:
            break
        }
    }

    // MARK: - Camera helpers
    private func centerCamera() { cameraNode.position = .zero }

    private func clampCameraToMap() {
        let worldSize: CGSize = mapInfo?.pixelSize ?? background.size
        let mapW = worldSize.width, mapH = worldSize.height
        let visW = size.width * cameraNode.xScale
        let visH = size.height * cameraNode.yScale

        if visW >= mapW || visH >= mapH {
            cameraNode.position = .zero
            return
        }

        let limitX = (mapW - visW) * 0.5
        let limitY = (mapH - visH) * 0.5
        cameraNode.position.x = min(max(cameraNode.position.x, -limitX), limitX)
        cameraNode.position.y = min(max(cameraNode.position.y, -limitY), limitY)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = lastUpdateTime == 0 ? 1/60 : CGFloat(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        guard panVelocity != .zero else { return }
        cameraNode.position.x += panVelocity.x * dt
        cameraNode.position.y += panVelocity.y * dt
        clampCameraToMap()

        let factor = pow(inertiaDampingPer60FPS, dt * 60) // exponential damping
        panVelocity.x *= factor; panVelocity.y *= factor
        if abs(panVelocity.x) < 5 && abs(panVelocity.y) < 5 { panVelocity = .zero }
    }
    private func attachForSaleSign(to plot: SKShapeNode, plotSize: CGSize) {
        // Avoid duplicates
           if plot.childNode(withName: "forSaleSign") != nil { return }

           // Create sprite from your asset
           let sign = SKSpriteNode(imageNamed: "ForSale")
           sign.name = "forSaleSign"
           sign.zPosition = 30

           // --- Size ---
           // The PNG is large; scale it down here
           sign.size = CGSize(width: 40, height: 30)  // tweak these until it looks perfect

           // --- Position above plot ---
           let yAbove = plotSize.height * 0.5 + 30
           sign.position = CGPoint(x: 0, y: yAbove)

           // --- Stay same size on screen ---
           // Apply inverse camera scale initially so it cancels zoom
           sign.setScale(1.0 / cameraNode.xScale)

           // Save its base size for later updates
           if sign.userData == nil { sign.userData = [:] }
           sign.userData?["baseSize"] = sign.size

           plot.addChild(sign)

           // --- Optional gentle bobbing animation ---
           let up = SKAction.moveBy(x: 0, y: 2, duration: 0.8)
           up.timingMode = .easeInEaseOut
           let down = up.reversed()
           sign.run(.repeatForever(.sequence([up, down])))
       }
    
    private func rescaleWorldBillboardsForCamera() {
        let inv = 1.0 / cameraNode.xScale
           for plot in plotNodes {
               for child in plot.children {
                   switch child.name {
                   case "plotNameLabel":
                       child.setScale(inv) // labels stay same size on screen
                   case "forSaleSign":
                       if let sign = child as? SKSpriteNode {
                           // Reset its scale so it cancels zoom
                           sign.setScale(1.0 / cameraNode.xScale)
                           // Ensure size remains consistent
                           if let baseSize = sign.userData?["baseSize"] as? CGSize {
                               sign.size = baseSize
                           }
                       }
                   default:
                       break
                   }
               }
           }
       }
    public func attemptPurchaseAndStartPlacement(type: String, price: Int, userId: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let (newBal, _) = try await UserManager.shared.purchaseProduct(userId: userId, productId: type, quantity: 1)
                print("🛒 Bought \(type). New balance: \(newBal)")
                self.decorManager.startPlacement(type: type)    // ghost shows; user clicks to place
                self.decorManager.movePreview(to: self.cameraNode.position)
                self.updatePanBehaviorForPlacement()
            } catch {
                print("❌ Purchase failed: \(error.localizedDescription)")
                // Optionally: show a HUD toast in the scene
            }
        }
    }


    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If we're placing decor, a simple click should move the ghost to the cursor immediately.
        if let t = touches.first, decorManager?.isPlacing == true {
            decorManager?.movePreview(to: t.location(in: self))
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Optional: keep this if you still want drag-to-aim during placement.
        if let t = touches.first, decorManager?.isPlacing == true {
            decorManager?.movePreview(to: t.location(in: self))
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        let tapped = nodes(at: loc)
        let top = atPoint(loc)
        
        

        //If currently placing décor: single tap = try to place here
        if decorManager?.isPlacing == true {
            if decorManager?.confirmPlacement(at: loc) == true {
                updatePanBehaviorForPlacement()
                triggerMapChanged()
            }
                return
        }
            if let menu = buildMenu, top.inParentHierarchy(menu) {
                    if handleManageMenuTap(tapped) || handleBuildMenuTap(tapped) { return }
                    return // swallow taps on menu background — don’t open build menu
                }
        // 🚫 Ignore taps on the "For Sale" sign (and anything inside it)
        var s: SKNode? = top
        while let cur = s, cur.name != "forSaleSign" { s = cur.parent }
        if s?.name == "forSaleSign" { return }
        
        // Only react if the TOPMOST hit is a plot (or inside one)
            var n: SKNode? = top
            while let cur = n, cur.name != "plot" { n = cur.parent }
            if let plot = n as? SKShapeNode {
                for p in plotNodes { setPlotSelected(p, selected: false) }
                setPlotSelected(plot, selected: true)
                selectedPlot = plot
                if isPlotOccupied(plot) {
                    if let bld = building(on: plot) {
                        let isBroken = (bld.userData?["broken"] as? Bool) ?? false
                        if isBroken {
                            showRepairMenu(for: bld)   // <- NEW
                        } else {
                            showManageMenu(for: bld)   // existing
                        }
                    }
                } else {
                    showBuildMenu()
                }

                return
            }

            // Fallback — tapped empty space
            dismissBuildMenu()
        }

    // MARK: - Build menu (fixed layout: no overlap)
    
    private func nineSlice(_ node: SKSpriteNode,
                           centerRect: CGRect = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)) {
        node.centerRect = centerRect
    }
    
    private func showBuildMenu() {
        
        run(.playSoundFileNamed("pop", waitForCompletion: false))
        
        
        guard let plot = selectedPlot else { return }

        // Figure out which buildings are allowed on this plot
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        let allowed = plotRules[plotName]?.allowed ?? availableBuildings  // fallback to current global
        guard !allowed.isEmpty else {
            // Tiny notice if nothing is allowed
            print("No buildings allowed on \(plotName)")
            return
        }
    
        
        
        dismissBuildMenu()
        let menu = SKNode(); menu.zPosition = 10_001
        cameraNode.addChild(menu); buildMenu = menu

        // Compute panel height: header + N*(btn+gap) - last gap + footer
        
        //Changed availableBuildings.count to allowed.count
        let buttonsBlockH = CGFloat(allowed.count) * (menuButtonH + menuGap) - menuGap
        let infoLinesCount = allowed.count
        let infoBlockH: CGFloat = CGFloat(infoLinesCount) * 22 + 12
        let panelH = menuHeaderPad + titleToListGap + infoBlockH + 16 + buttonsBlockH + menuFooterPad
        let panelSize = CGSize(width: panelWidth, height: panelH)


        // Panel
        let panel = SKSpriteNode(imageNamed: panelSprite)
        nineSlice(panel)                       // 9-slice so edges stay crisp
        panel.size = panelSize
        panel.zPosition = 0
        panel.colorBlendFactor = 0             // keep original colors
        menu.addChild(panel)

        // Title
        let title = SKLabelNode(text: "Choose a building")
        title.fontName = "PressStart2P-Regular"
        title.fontSize = 13
        title.fontColor = .label
        title.position = CGPoint(x: 0, y: panelSize.height/2 - 60)
        menu.addChild(title)
        
        // --- Info preview box for available buildings ---
        let infoBG = SKShapeNode(
            rectOf: CGSize(width: panelWidth - 40, height: infoBlockH),
            cornerRadius: 10
        )
        infoBG.fillColor = .clear
        infoBG.strokeColor = .clear
        infoBG.zPosition = 1
        infoBG.position = CGPoint(x: 0, y: title.position.y - 32)
        menu.addChild(infoBG)

        // One line per allowed building: "House: Cozy starter home."
        let lineSpacing: CGFloat = 20
        let totalHeight = CGFloat(allowed.count - 1) * lineSpacing

        for (index, name) in allowed.enumerated() {
            let base = baseName(from: name)                // you already have baseName(from:)
            let preview = buildPreviewDescription(for: base)

            let label = SKLabelNode(text: "\(base): \(preview)")
            label.fontName = "PressStart2P-Regular"
            label.fontSize = 12
            label.fontColor = .black
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 2

            let lineY = infoBG.position.y + totalHeight/2 - CGFloat(index) * lineSpacing
            label.position = CGPoint(x: 0, y: lineY)

            menu.addChild(label)
        }

        // Buildings list
        var y = infoBG.position.y - infoBlockH/2 - 16 - menuButtonH/2
        for name in allowed { // Changed availableBuildings to allowed
            let btn = buttonNode(title: name, actionName: "build:\(name)",
                                 size: CGSize(width: menuButtonW, height: menuButtonH))
            btn.position = CGPoint(x: 0, y: y)
            menu.addChild(btn)
            y -= (menuButtonH + menuGap)
        }

        // Cancel in footer area
        let cancel = buttonNode(title: "Cancel", actionName: "cancel",
                                size: CGSize(width: menuButtonW, height: menuButtonH),
                                isCancel: true)
        cancel.position = CGPoint(x: 0, y: -panelSize.height/2 + menuFooterPad/1.35)
        menu.addChild(cancel)
    }

    private func buttonNode(title: String,
                            actionName: String,
                            size: CGSize,
                            isCancel: Bool = false,
                            control
                            useNineSlice: Bool = true) -> SKNode {
        let node = SKNode()
            node.name = actionName
            node.zPosition = 1

            // Choose the sprite name
            let bgName = isCancel ? buttonSpriteCancel : buttonSprite

            // Load texture and validate
            let tex = SKTexture(imageNamed: bgName)
            let texSize = tex.size()
            let bg: SKSpriteNode

            if texSize == .zero {
                // 🚨 Missing asset -> show visible fallback and log
                print("⚠️ Missing button sprite '\(bgName)'. Check asset name & target membership.")
                bg = SKSpriteNode(color: .red, size: size)
            } else {
                bg = SKSpriteNode(texture: tex)
                if useNineSlice {
                    // Adjust these insets to match YOUR art’s safe middle area
                    bg.centerRect = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
                    bg.size = size // now it can stretch without distorting corners
                } else {
                    // Use natural image size (no stretching)
                    bg.size = texSize
                }
            }

            bg.name = actionName
            bg.colorBlendFactor = 0
            node.addChild(bg)

            // Label
            let label = SKLabelNode(text: title)
            label.fontName = "PressStart2P-Regular"   // ensure font is in Info.plist (UIAppFonts)
            label.fontSize = 14
            label.fontColor = .black
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.name = actionName
            label.zPosition = 2
            node.addChild(label)

        return node
    }

    private func handleBuildMenuTap(_ tapped: [SKNode]) -> Bool {
        guard buildMenu != nil else { return false }
        
        if let node = tapped.first(where: { ($0.name ?? "").hasPrefix("build:")
                                      || $0.name == "cancel" }) {
            let name = node.name ?? ""
            if name == "cancel" {
                
                dismissBuildMenu(); return true
            }
            
            if name.hasPrefix("build:") {
                        let asset = String(name.dropFirst("build:".count))
                        let cost = buildCost(for: asset)

                        // Run async spending logic in a Task
                        Task { [weak self] in
                            guard let self = self else { return }
                            guard let uid = self.userId ?? Auth.auth().currentUser?.uid else {
                                print("No userId set on GameScene")
                                return
                            }
                            
                            
                            do {
                                // Attempt to spend before building
                                let newBalance = try await UserManager.shared.spend(userId: uid, amount: cost)
                                print("Built \(asset) for \(cost). New balance: \(newBalance)")

                                // Only place the building if payment succeeded
                                self.placeBuildingOnSelectedPlot(assetName: asset)
                                self.triggerMapChanged()
                                
                                //Play sound
                                self.playLoopingSFX("wood_sawing", loops: 1, volume: 0.9, clipDuration: 0.6)

                            } catch {
                                print("Could not build \(asset): \(error.localizedDescription)")
                            }

                            // Close menu afterward
                            self.dismissBuildMenu()
                        }

                        return true
                    }
                }
        return false
    }
    
    private func handleManageMenuTap(_ tapped: [SKNode]) -> Bool {
        guard buildMenu != nil else { return false }
        if let node = tapped.first(where: { ($0.name ?? "").hasPrefix("manage:")
                                       || $0.name == "cancel" }) {
            let action = node.name ?? ""
            if action == "cancel" {
                dismissBuildMenu(); return true
            }
            
            // this might no longer need to be used because I integrated it into the func call
            // refactoring opportunity?
            guard let plot = selectedPlot, let bld = building(on: plot) else {
                dismissBuildMenu(); return true
            }
            
            if action == "manage:upgrade" {
                Task { [weak self] in
                        guard let self, let plot = self.selectedPlot, let bld = self.building(on: plot) else { return }
                        await self.upgrade(building: bld, on: plot)
                    }
                
                    dismissBuildMenu()
                    return true
                /* Old Logic (kept just in case)
                upgrade(building: bld, on: plot)
                dismissBuildMenu(); return true
                 */
            }
            if action == "manage:sell" {
                Task { [weak self] in
                        guard let self, let plot = self.selectedPlot, let bld = self.building(on: plot) else { return }
                        await self.sell(building: bld, on: plot)
                    }
                    dismissBuildMenu()
                    return true
                /*  Old Logic (kept just in case)
                sell(building: bld, on: plot)
                dismissBuildMenu(); return true
                 */
            }
            if action == "manage:repair" {
                Task { [weak self] in
                    guard let self else { return }
                    await self.repairFlow(for: bld, on: plot)
                }
                dismissBuildMenu()
                return true
            }
        }
        return false
    }
    
    private func showManageMenu(for building: SKSpriteNode) {
        
        run(.playSoundFileNamed("pop", waitForCompletion: false))
        
        dismissBuildMenu() // reuse the same container slot
        let menu = SKNode(); menu.zPosition = 10_001
        cameraNode.addChild(menu); buildMenu = menu
        
        let isDamaged = (building.userData?["damaged"] as? Bool) ?? false

        // Layout (reuse your sizing constants)
        let infoBlockH: CGFloat = 68
        let buttons = isDamaged
        ? ["Repair", "Upgrade", "Sell", "Cancel"]
        : ["Upgrade", "Sell", "Cancel"]
        
        let buttonsBlockH = CGFloat(buttons.count) * (menuButtonH + menuGap) - menuGap
        let panelH = menuHeaderPad + titleToListGap + infoBlockH + 14 + buttonsBlockH + menuFooterPad/2
        let panelSize = CGSize(width: panelWidth, height: panelH)

        // Panel        
        let panel = SKSpriteNode(imageNamed: panelSprite)
        nineSlice(panel)                       // 9-slice so edges stay crisp
        panel.size = panelSize
        panel.zPosition = 0
        panel.colorBlendFactor = 0             // keep original colors
        menu.addChild(panel)

        // Title
        let title = SKLabelNode(text: "Manage building")
        title.fontName = "PressStart2P-Regular"
        title.fontSize = 13
        title.fontColor = .label
        title.position = CGPoint(x: 0, y: panelSize.height/2 - 60)
        menu.addChild(title)
        
        // --- Info box (uses helper) ---
        let bType = (building.userData?["type"] as? String) ?? "Building"
        let bLevel = (building.userData?["level"] as? Int) ?? 1
        let skin = (building.userData?["skin"] as? String)
        let info = buildingDescription(type: bType, skin:skin, level: bLevel)
        // Background for info
            let infoBG = SKShapeNode(rectOf: CGSize(width: panelWidth - 40, height: infoBlockH), cornerRadius: 10)
            infoBG.strokeColor = UIColor.white.withAlphaComponent(0.35)
            infoBG.lineWidth = 1
            infoBG.position = CGPoint(x: 0, y: title.position.y - 40)
            infoBG.zPosition = 1
            menu.addChild(infoBG)

        
            // Title (Lv info)
            let infoTitle = SKLabelNode(text: info.title)
            infoTitle.fontName = "PressStart2P-Regular"
            infoTitle.fontSize = 12
            infoTitle.fontColor = .black
            infoTitle.position = CGPoint(x: 0, y: infoBG.position.y + 12)
            infoTitle.zPosition = 2
            infoTitle.name = "infoTitle"
            menu.addChild(infoTitle)

            // Blurb
            let infoBody = SKLabelNode(text: info.blurb)
            infoBody.preferredMaxLayoutWidth = infoBG.frame.width - 20
            infoBody.fontName = "PressStart2P-Regular"
            infoBody.fontSize = 11
            infoBody.fontColor = .black
            infoBody.lineBreakMode = .byWordWrapping
            infoBody.numberOfLines = 0
            infoBody.verticalAlignmentMode = .center
            infoBody.horizontalAlignmentMode = .center
            infoBody.position = infoBG.position
            infoBody.zPosition = 2
            infoBody.name = "infoBody"
            menu.addChild(infoBody)
    


        // Buttons
        var y = infoBG.position.y - infoBlockH/2 - 16 - menuButtonH/2

        func addButton(_ label: String, action: String, isCancel: Bool = false) {
            let btn = buttonNode(
                title: label,
                actionName: action, // e.g. "manage:upgrade" / "manage:sell" / "cancel"
                size: CGSize(width: menuButtonW, height: menuButtonH),
                isCancel: isCancel
            )
            btn.position = CGPoint(x: 0, y: y)
            menu.addChild(btn)
            y -= (menuButtonH + menuGap)
        }
        
        if (isDamaged) {
            addButton("Repair", action: "manage:repair", isCancel: true)
        }
        addButton("Upgrade", action: "manage:upgrade")
        addButton("Sell", action: "manage:sell")
        addButton("Cancel", action: "cancel", isCancel: true)
    }



    private func dismissBuildMenu() {
        buildMenu?.removeFromParent(); buildMenu = nil
    }


    // MARK: - Place building (House & Barn now 2×)
    private func placeBuildingOnSelectedPlot(assetName: String) {
        guard let plot = selectedPlot else { return }
        
       
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        if let rule = plotRules[plotName], !rule.allowed.contains(assetName) {
            print("🚫 \(assetName) is not allowed on \(plotName)")
            // Optional: flash the plot or show a quick HUD tooltip
            return
        }
    
        
        //let pos = plot.position
        let pos = positionFor(assetName: assetName, on: plot)
        
        // Create the sprite first
        
        //New Code
        let baseType = assetName
        let skin = equippedSkinForType[baseType]
        let level = 1
        
        let resolvedType: String
        switch (baseType, skin) {
        case ("Barn",  "Blue"):  resolvedType = "BlueBarn"
        case ("House", "Candy"): resolvedType = "CandyHouse"
        default:                 resolvedType = baseType
        }
        
        let fullName = "\(resolvedType)_L\(level)"
        //New Code
        
        
        let sprite: SKSpriteNode

        if UIImage(named: fullName) != nil {
            sprite = SKSpriteNode(imageNamed: fullName)
        } else {
            sprite = SKSpriteNode(color: .systemGreen, size: CGSize(width: 32, height: 32))
            print("⚠️ Asset '\(fullName)' not found. Using placeholder.")
        }
        
        
        
        // ✅ Now you can safely assign userData
        if sprite.userData == nil { sprite.userData = [:] }
        sprite.userData?["type"] = baseType     // "Barn" or "House"
        sprite.userData?["level"] = level        // start at level 1
        sprite.userData?["plot"] = (plot.userData?["plotName"] as? String) ?? "UnknownPlot"
        
        if let skin { sprite.userData?["skin"] = skin }   // ✅ persist which skin was used (New Code)
        
        sprite.userData?["damaged"] = false

        sprite.position = pos
        sprite.zPosition = 4

        let scale = buildingScaleOverrides[assetName] ?? baseBuildingScale
        sprite.setScale(scale)

        addChild(sprite)
        buildings.append(sprite)
        plot.userData?["occupied"] = true
        triggerMapChanged()

        print("🏠 Placed \(assetName) (level \(level)) on \(plot.userData?["plotName"] ?? "UnknownPlot")")
        selectedPlot?.childNode(withName: "forSaleSign")?.removeFromParent()

    }


    // To detect if a building is occupied
    private func building(on plot: SKShapeNode) -> SKSpriteNode? {
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        return buildings.first { ($0.userData?["plot"] as? String) == plotName }
    }

    private func isPlotOccupied(_ plot: SKShapeNode) -> Bool {
        return building(on: plot) != nil
    }
    
    
    private func upgrade(building: SKSpriteNode, on plot: SKShapeNode) async {
        let type = (building.userData?["type"] as? String) ?? "Building"
        let currentLevel = (building.userData?["level"] as? Int) ?? 1
        let nextLevel = currentLevel + 1
        //New Code
        let skin = (building.userData?["skin"] as? String)
        let isDamaged = false
        let resolvedType: String
        switch (type, skin) {
        case ("Barn",  "Blue"):  resolvedType = "BlueBarn"
        case ("House", "Candy"): resolvedType = "CandyHouse"
        default:                 resolvedType = type
        }
        let newTextureName = "\(resolvedType)_L\(nextLevel)"
        
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        let maxLevel = plotRules[plotName]?.maxLevel[type] ?? Int.max
        guard nextLevel <= maxLevel else {
            print("\(type) cannot be upgraded beyond L\(maxLevel) on \(plotName)")
            return
        }
        //New Code
        
        // Example: define upgrade cost logic
        let cost = nextLevel * 100  // cost currently set to 100 times the level of the building
        guard let uid = self.userId ?? Auth.auth().currentUser?.uid else {
            print("No userId set on GameScene");
            return
        }

        do {
            // Attempt to spend currency before upgrading
            let newBalance = try await UserManager.shared.spend(userId: uid, amount: cost)
            print("Spent \(cost). New balance: \(newBalance)")

            // 🏗 Proceed with upgrade visuals and data
            
            
            if let newImage = UIImage(named: newTextureName) {
                building.texture = SKTexture(imageNamed: newTextureName)
                building.size = building.texture!.size()
                building.userData?["level"] = nextLevel
                print("\(type) upgraded to level \(nextLevel)")
                triggerMapChanged()
                
                //Play sound
                playLoopingSFX("wood_sawing", loops: 1, volume: 0.9, clipDuration: 0.6)
                // ✅ refresh the info labels using helper
                updateManageMenuInfo(for: building)
            } else {
                print("No image named \(newTextureName).png found")
            }

        } catch {
            print("Failed to spend \(cost): \(error.localizedDescription)")
        }
        
    }


    @MainActor
    private func sell(building: SKSpriteNode, on plot: SKShapeNode) async {
        // determine the amount that will be refunded based on level
        let currentLevel = (building.userData?["level"] as? Int) ?? 1
        let refundAmount = sellRefundAmount(for: currentLevel)
        
        guard let uid = self.userId ?? Auth.auth().currentUser?.uid else {
            print("No userId set on GameScene")
            return
        }
        do {
            let newBalance = try await UserManager.shared.refund(userId: uid, amount: refundAmount)
            print("Refunded \(refundAmount). New balance: \(newBalance)")
            
            playLoopingSFX("coin_drop", loops: 1, volume: 0.8, clipDuration: 1.0)
            
            updateManageMenuInfo(for: building)
            
            // Remove from scene and tracking; clear occupancy
            if let idx = buildings.firstIndex(of: building) { buildings.remove(at: idx) }
            building.removeFromParent()
            plot.userData?["occupied"] = false // if you use this flag anywhere
            print("🗑️ Sold building on plot \(plot.userData?["plotName"] ?? "Unknown")")
            // ✅ Re-add the "For Sale" sign after the sale succeeds
                   let size = (plot.path?.boundingBox.size) ?? .zero
                   attachForSaleSign(to: plot, plotSize: size)
                   rescaleWorldBillboardsForCamera()

                   triggerMapChanged()
        } catch {
            print("Refund failed (\(refundAmount): \(error.localizedDescription))")
            
            let size = (plot.path?.boundingBox.size) ?? .zero
            attachForSaleSign(to: plot, plotSize: size)
        }
    }


    // MARK: - MapManager helpers
    func addBuilding(_ node: SKSpriteNode) {
        addChild(node)
        buildings.append(node)
    }

    func getBuildingData() -> [[String: Any]] {
        return buildings.map { node in
            let type = (node.userData?["type"] as? String) ?? "Unknown"
            let plot = (node.userData?["plot"] as? String) ?? "UnknownPlot"
            let level = (node.userData?["level"] as? Int)    ?? 1
            return [
                "type": type,
                "plot": plot,
                "x": node.position.x,
                "y": node.position.y,
                "level": (node.userData?["level"] as? Int) ?? 1,
                "skin":  (node.userData?["skin"]  as? String) ?? "Default",
            ]
        }
    }
    
    // Convert your in-memory sprites → typed models
    func getBuildingModels() -> [Building] {
        return buildings.map {
            var m = Building(node: $0)
            // (init(node:) already sets broken)
            return m
        }
    }
    


    // Place buildings from typed models (the only new "load" you need)
    func applyLoadedBuildings(_ models: [Building]) {
        
        for b in buildings {
                b.removeFromParent()
            }
            buildings.removeAll()
        
        for m in models {
            let sprite = m.makeSprite()

            // Keep your existing scaling rules
            let baseBuildingScale: CGFloat = 0.6
            let buildingScaleOverrides: [String: CGFloat] = [
                "House": 1,
                "Barn":  1
            ]
            let scale = buildingScaleOverrides[m.type] ?? baseBuildingScale
            sprite.setScale(scale)

            addBuilding(sprite)
        }
        print("✅ Loaded \(models.count) buildings into scene.")
    }
    
    // determines amount that will be refunded based on level
    private func sellRefundAmount(for level: Int) -> Int {
        return max(0, level * 75) //currently set to only return 75/100 spent on an upgrade
    }
    
    // determins cost to build a building
    private func buildCost(for assetName: String) -> Int {
        let base = baseName(from: assetName)
        switch base {
        case "House":
            return 200
        case "Barn":
            return 300
        case "Farm":
            return 200
        default:
            return 100
        }
    }

    // separates the building name from the full asset Name
    private func baseName(from assetName: String) -> String {
        return assetName.components(separatedBy: "_").first ?? assetName
    }
    private func buildPreviewDescription(for baseType: String) -> String {
        switch baseType {
        case "House":
            return "Cost $200"
        case "Barn":
            return "Cost $300"
        case "Farm":
            return "Grows crops to earn more coins."
        default:
            return "A new building for your town."
        }
    }
    // MARK: - Texture name resolver
    
    private func resolvedType(baseType: String, skin: String?) -> String {
        switch (baseType, skin) {
        case ("Barn", "Blue"):  return "BlueBarn"
        case ("House","Candy"): return "CandyHouse"
        default:                return baseType
        }
    }

    private func textureName(for node: SKSpriteNode, broken: Bool? = nil) -> String? {
        let type  = (node.userData?["type"] as? String) ?? ""
        let skin  = (node.userData?["skin"] as? String)
        let level = (node.userData?["level"] as? Int) ?? 1
        let isBroken = broken ?? ((node.userData?["broken"] as? Bool) ?? false)

        let base = resolvedType(baseType: type, skin: skin)
        let name = isBroken ? "Broken\(base)_L\(level)" : "\(base)_L\(level)"
        return UIImage(named: name) != nil ? name : nil
    }

    private func applyTexture(_ node: SKSpriteNode, broken: Bool? = nil) {
        let isBroken = broken ?? ((node.userData?["broken"] as? Bool) ?? false)
        if let name = textureName(for: node, broken: isBroken) {
            node.texture = SKTexture(imageNamed: name)
            node.size    = node.texture!.size()
            if node.userData == nil { node.userData = [:] }
            node.userData?["broken"] = isBroken
        } else {
            print("⚠️ Missing texture for \(String(describing: node.userData?["type"])) level \(String(describing: node.userData?["level"])) broken=\(isBroken)")
        }
    }

    // One-off breakers/repairers
    private func breakBuilding(_ node: SKSpriteNode) {
        applyTexture(node, broken: true)
        triggerMapChanged()
    }

    private func repairBuilding(_ node: SKSpriteNode) {
        applyTexture(node, broken: false)
        triggerMapChanged()
    }
    
    // MARK: - Earthquake → break buildings
    func triggerEarthquake(duration: TimeInterval = 3.0,
                           breakProbability: Double = 1.0,
                           affectAlreadyBroken: Bool = false) {
        // 1) Shake camera/SFX (existing)
        triggerEarthquakeShake(duration: duration)

        // 2) After shake settles, damage buildings
        let settleDelay = duration + 0.1
        run(.wait(forDuration: settleDelay)) { [weak self] in
            guard let self = self else { return }
            var anyChanged = false
            for b in self.buildings {
                let wasBroken = (b.userData?["broken"] as? Bool) ?? false
                if wasBroken {
                    // idempotent: keep as-is (or tweak visuals if you set affectAlreadyBroken = true)
                    if affectAlreadyBroken {
                        // (optional) play dust/sfx only, no texture change
                    }
                    continue
                }
                if Double.random(in: 0...1) <= breakProbability {
                    self.setBroken(b, to: true)
                    anyChanged = true
                }
            }
            if anyChanged {
                self.playLoopingSFX("HouseBreak", loops: 1, volume: 1.0, clipDuration: 1.0)
                self.triggerMapChanged()
            }
        }
    }
    
    private func setBroken(_ node: SKSpriteNode, to isBroken: Bool) {
        if node.userData == nil { node.userData = [:] }
        node.userData?["broken"] = isBroken

        let type  = (node.userData?["type"] as? String) ?? ""
        let skin  = (node.userData?["skin"] as? String)
        let level = (node.userData?["level"] as? Int) ?? 1

        // Resolve skin → base name
        let resolved: String
        switch (type, skin) {
        case ("Barn","Blue"):   resolved = "BlueBarn"
        case ("House","Candy"): resolved = "CandyHouse"
        default:                resolved = type
        }

        let texName = isBroken ? "Broken\(resolved)_L\(level)" : "\(resolved)_L\(level)"
        if UIImage(named: texName) != nil {
            node.texture = SKTexture(imageNamed: texName)
            node.size = node.texture!.size()
        } else {
            print("⚠️ Missing texture \(texName)")
        }
    }
    
    // MARK: Repair Menu and Handler
    private func showRepairMenu(for building: SKSpriteNode) {
        dismissBuildMenu()
        let menu = SKNode(); menu.zPosition = 10_001
        cameraNode.addChild(menu); buildMenu = menu

        let buttons = ["Repair", "Cancel"]
        let buttonsBlockH = CGFloat(buttons.count) * (menuButtonH + menuGap) - menuGap
        let panelH = menuHeaderPad + titleToListGap + buttonsBlockH + menuFooterPad/2
        let panelSize = CGSize(width: panelWidth, height: panelH)

        let panel = SKSpriteNode(imageNamed: panelSprite)
        nineSlice(panel)
        panel.size = panelSize
        menu.addChild(panel)

        let title = SKLabelNode(text: "Damaged building")
        title.fontName = "PressStart2P-Regular"
        title.fontSize = 13
        title.fontColor = .label
        title.position = CGPoint(x: 0, y: panelSize.height/2 - 60)
        menu.addChild(title)

        var y = panelSize.height/2 - menuHeaderPad - titleToListGap - menuButtonH/2
        func addButton(_ label: String, action: String, isCancel: Bool = false) {
            let btn = buttonNode(title: label,
                                 actionName: action,
                                 size: CGSize(width: menuButtonW, height: menuButtonH),
                                 isCancel: isCancel)
            btn.position = CGPoint(x: 0, y: y)
            menu.addChild(btn)
            y -= (menuButtonH + menuGap)
        }
        addButton(
            "Repair",
            action: "manage:repair"
        )
        addButton("Cancel", action: "cancel", isCancel: true)
    }
    
    // MARK: the repair flow (pay, flip texture, clear flag)
    
    private func repairCost(for node: SKSpriteNode) -> Int {
        // example: scale by level
        let lvl = (node.userData?["level"] as? Int) ?? 1
        return max(50, 100 * lvl)   // tweak
    }

    @MainActor
    private func repairFlow(for building: SKSpriteNode, on plot: SKShapeNode) async {
        // spend coins
        let cost = repairCost(for: building)
        guard let uid = self.userId ?? Auth.auth().currentUser?.uid else { return }
        do {
            _ = try await UserManager.shared.spend(userId: uid, amount: cost)
            // flip flag & art
            repairBuilding(building)
            // SFX
            playLoopingSFX("wood_sawing", loops: 1, volume: 0.9, clipDuration: 0.6)
        } catch {
            print("❌ Repair failed: \(error.localizedDescription)")
        }
    }




    
}


// MARK: Decore Bridge
extension GameScene {
    func currentDecorModels() -> [DecorItem] {
        decorManager.getDecorModels()
    }
    func applyLoadedDecor(_ models: [DecorItem]) {
        decorManager.applyLoadedDecor(models)
    }
}

//MARK: Earthquak functions
extension GameScene {
    func applyEarthquakeDamage() {
        for node in buildings {
            if node.userData == nil { node.userData = [:] }
            node.userData?["damaged"] = true

            let type = (node.userData?["type"] as? String) ?? "Building"
            let skin = (node.userData?["skin"] as? String)
            let level = (node.userData?["level"] as? Int)
            let tex = textureName(baseType: type, skin: skin, level: level, damaged: true)
            if UIImage(named: tex) != nil {
                node.texture = SKTexture(imageNamed: tex)
                node.size = node.texture!.size()
            }
        }
        triggerMapChanged()              // will persist via MapManager
        triggerEarthquakeShake()         // optional: shake on damage apply
    }
    
    @MainActor
    private func repair(building: SKSpriteNode) async {
        let repairCost = 150   // tweak
        guard let uid = self.userId ?? Auth.auth().currentUser?.uid else { return }
        do {
            _ = try await UserManager.shared.spend(userId: uid, amount: repairCost)
            let type = (building.userData?["type"] as? String) ?? "Building"
            let skin = (building.userData?["skin"] as? String)
            let level = (building.userData?["level"] as? Int)
            building.userData?["damaged"] = false
            let tex = textureName(baseType: type, skin: skin, level: level, damaged: false)
            if UIImage(named: tex) != nil {
                building.texture = SKTexture(imageNamed: tex)
                building.size = building.texture!.size()
            }
            playLoopingSFX("wood_sawing", loops: 1, volume: 0.9, clipDuration: 0.6)
            triggerMapChanged()
        } catch {
            print("Repair failed: \(error.localizedDescription)")
        }
    }
}
