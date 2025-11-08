//
//  GameScene.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.

import SpriteKit
import UIKit

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
    private let panelWidth: CGFloat = 260
    private let menuButtonW: CGFloat = 220
    private let menuButtonH: CGFloat = 44
    private let menuGap: CGFloat = 10
    private let menuHeaderPad: CGFloat = 64
    private let menuFooterPad: CGFloat = 64

    // Building scale: House & Barn at 2× prior (0.8 vs 0.4)
    private let baseBuildingScale: CGFloat = 0.6
    private let buildingScaleOverrides: [String: CGFloat] = [
        "House": 0.8,
        "Barn":  1
    ]

    // MARK: - Data
    private(set) var buildings: [SKSpriteNode] = []
    private var selectedPlot: SKShapeNode?
    private var tmxPlots: [PlotObject] = []

    // MARK: - Camera / world
    private let cameraNode = SKCameraNode()
    private var background: SKSpriteNode!
    private var mapInfo: TMXMapInfo?

    // MARK: - Plots
    private var plotNodes: [SKShapeNode] = []

    // MARK: - HUD
    private let hudRoot = SKNode()
    private var hudLabel: SKLabelNode?

    // MARK: - Build menu
    private var buildMenu: SKNode?
    private let availableBuildings = ["Barn", "House"]

    // MARK: - Gestures / inertia
    private var pinchGR: UIPinchGestureRecognizer?
    private var panGR: UIPanGestureRecognizer?
    private var panVelocity = CGPoint.zero
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Database
    var onMapChanged: (() -> Void)?
    var userId: String!
    
    private func triggerMapChanged() {
        onMapChanged?()
    }

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = .black

        // Background (gets resized to TMX map so overlays align)
        background = SKSpriteNode(imageNamed: "FarmBackground")
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.position = .zero
        background.zPosition = -10
        addChild(background)

        // Build plots from TMX; fallback if none so you always see something
        let hadPlots = buildPlotsFromTMX()
        if !hadPlots { buildDebugPlots() }

        // Camera
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(initialZoom)
        rescaleWorldBillboardsForCamera()
        centerCamera()
        clampCameraToMap()

        // HUD
        setupHUD()

        // Gestures
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture(_:)))
        pinch.cancelsTouchesInView = false
        pinch.delaysTouchesBegan = false
        pinch.delaysTouchesEnded = false
        view.addGestureRecognizer(pinch); pinchGR = pinch

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        view.addGestureRecognizer(pan); panGR = pan

        print("✅ GameScene ready. plots=\(plotNodes.count) zoom=\(cameraNode.xScale)")
    }

    deinit {
        view?.gestureRecognizers?.forEach { gr in
            if gr === pinchGR || gr === panGR { view?.removeGestureRecognizer(gr) }
        }
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
    
    // New Code
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
                    maxLevel: ["House": 3],
                    anchor: CGPoint(x: 0.50, y: 0.6),
                    perBuildingAnchor: [:]),
        "Plot02": PlotRule(
            allowed: ["Barn", "House"],
            maxLevel: ["Barn": 4, "House": 3],
            anchor: CGPoint(x: 0.5, y: 0.5),
            perBuildingAnchor: ["Barn": CGPoint(x: 0.55, y: 0.55)]),
        "Plot03": PlotRule(
                    allowed: ["Barn", "House"],
                    maxLevel: ["Barn": 4, "House": 3],
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
    // New Code
    

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
                nameLabel.fontName = ".SFUI-Semibold"
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
            label.fontName = ".SFUI-Semibold"
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

    /*private func setPlotSelected(_ plot: SKShapeNode, selected: Bool) {
        if selected {
            plot.fillColor   = UIColor.systemGreen.withAlphaComponent(0.18)
            plot.strokeColor = UIColor.systemGreen
            plot.lineWidth   = 3
        } else {
            plot.fillColor   = UIColor.systemGreen.withAlphaComponent(0.14)
            plot.strokeColor = UIColor.systemGreen.withAlphaComponent(0.65)
            plot.lineWidth   = 2
        }

        let size = (plot.path?.boundingBox.size) ?? .zero
        ensureCornerBrackets(on: plot, size: size, visible: selected)
        plot.childNode(withName: "cornerBrackets")?.isHidden = !selected
    }
        */

    /*private func stylePlot(_ plot: SKShapeNode, size: CGSize) {
        // Softer base
        plot.fillColor   = UIColor.systemGreen.withAlphaComponent(0.14)
        plot.strokeColor = UIColor.systemGreen.withAlphaComponent(0.65)
        plot.lineWidth   = 2
        plot.glowWidth   = plotGlow
        plot.blendMode   = .alpha

        // Softer pulsing ring
        let ringSize = CGSize(width: size.width * ringScale, height: size.height * ringScale)
        let ring = SKShapeNode(rectOf: ringSize, cornerRadius: 10)
        ring.strokeColor = UIColor.white.withAlphaComponent(0.45)
        ring.lineWidth   = 1.5
        ring.glowWidth   = 5
        ring.alpha       = ringAlpha
        ring.blendMode   = .alpha
        ring.zPosition   = 6
        plot.addChild(ring)

        let up   = SKAction.group([.fadeAlpha(to: 0.5, duration: 1.2),
                                   .scale(to: 1.04, duration: 1.2)])
        let down = SKAction.group([.fadeAlpha(to: 0.3, duration: 1.2),
                                   .scale(to: 1.00, duration: 1.2)])
        ring.run(.repeatForever(.sequence([up, down])))

        // Corner brackets (subtle)
        let brackets = SKNode()
        brackets.zPosition = 7
        plot.addChild(brackets)

        func corner(_ dx: CGFloat, _ dy: CGFloat) -> SKShapeNode {
            let path = UIBezierPath()
            let len: CGFloat = 14
            path.move(to: .zero); path.addLine(to: CGPoint(x: len * dx, y: 0))
            path.move(to: .zero); path.addLine(to: CGPoint(x: 0, y: len * dy))
            let n = SKShapeNode(path: path.cgPath)
            n.strokeColor = UIColor.white.withAlphaComponent(0.6)
            n.lineWidth = 1.5
            n.alpha = 0.7
            n.blendMode = .alpha
            return n
        }

        let halfW = size.width / 2
        let halfH = size.height / 2
        let tl = corner( 1,  1); tl.position = CGPoint(x: -halfW, y:  halfH)
        let tr = corner(-1,  1); tr.position = CGPoint(x:  halfW, y:  halfH)
        let bl = corner( 1, -1); bl.position = CGPoint(x: -halfW, y: -halfH)
        let br = corner(-1, -1); br.position = CGPoint(x:  halfW, y: -halfH)
        [tl,tr,bl,br].forEach { brackets.addChild($0) }
    }

    private func setPlotSelected(_ plot: SKShapeNode, selected: Bool) {
        if selected {
            plot.fillColor   = UIColor.systemGreen.withAlphaComponent(0.32)
            plot.strokeColor = UIColor.systemGreen
            plot.lineWidth   = 3
        } else {
            plot.fillColor   = UIColor.systemGreen.withAlphaComponent(0.14)
            plot.strokeColor = UIColor.systemGreen.withAlphaComponent(0.65)
            plot.lineWidth   = 2
        }
    }
     */

    // MARK: - HUD
    private func setupHUD() {
        hudRoot.zPosition = 10_000
        cameraNode.addChild(hudRoot)
        let label = SKLabelNode(fontNamed: ".SFUI-Semibold")
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

    /*@objc private func panGesture(_ sender: UIPanGestureRecognizer) {
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
     */
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

        // Root node for easy cleanup
        let signNode = SKNode()
        signNode.name = "forSaleSign"
        signNode.zPosition = 30

        // --- Post ---
        let postWidth: CGFloat = 4
        let postHeight: CGFloat = 20
        let post = SKShapeNode(rectOf: CGSize(width: postWidth, height: postHeight), cornerRadius: 1.5)
        post.fillColor = .brown
        post.strokeColor = .clear
        post.position = CGPoint(x: 0, y: postHeight / 2)
        signNode.addChild(post)

        // --- Signboard ---
        let boardSize = CGSize(width: 60, height: 20)
        let board = SKShapeNode(rectOf: boardSize, cornerRadius: 3)
        board.fillColor = UIColor.white
        board.strokeColor = UIColor.darkGray
        board.lineWidth = 1.2
        board.position = CGPoint(x: 0, y: postHeight)
        signNode.addChild(board)

        // --- Text ---
        let label = SKLabelNode(text: "For Sale")
        label.fontName = "PressStart2P-Regular"
        label.fontSize = 6
        label.fontColor = .red
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        board.addChild(label)

        // --- Position sign above plot ---
        let yAbove = plotSize.height * 0.5 + 10
        signNode.position = CGPoint(x: 0, y: yAbove)
        signNode.setScale(1.0 / cameraNode.xScale) // stay same size on screen
        plot.addChild(signNode)

        // --- Optional gentle animation ---
        let up = SKAction.moveBy(x: 0, y: 2, duration: 0.8)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        signNode.run(.repeatForever(.sequence([up, down])))
    }
    private func rescaleWorldBillboardsForCamera() {
        let inv = 1.0 / cameraNode.xScale
        for plot in plotNodes {
            for child in plot.children where
                child.name == "plotNameLabel" || child.name == "forSaleSign" {
                child.setScale(inv)
            }
        }
    }


    // MARK: - Touch → plot select → build menu
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        let tapped = nodes(at: loc)

        // Handle menu taps first (either build or manage)
        if handleManageMenuTap(tapped) { return }
        if handleBuildMenuTap(tapped) { return }

        // Plot selection → show either Build or Manage menu
        if let plot = tapped.first(where: { $0.name == "plot" }) as? SKShapeNode {
            for p in plotNodes { setPlotSelected(p, selected: false) }
            setPlotSelected(plot, selected: true)
            selectedPlot = plot

            if isPlotOccupied(plot) {
                showManageMenu(for: plot)
            } else {
                showBuildMenu()
            }
            return
        }

        dismissBuildMenu()
    }


    // MARK: - Build menu (fixed layout: no overlap)
    private func showBuildMenu() {
        
        //New code
        guard let plot = selectedPlot else { return }

        // Figure out which buildings are allowed on this plot
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        let allowed = plotRules[plotName]?.allowed ?? availableBuildings  // fallback to current global
        guard !allowed.isEmpty else {
            // Tiny notice if nothing is allowed
            print("No buildings allowed on \(plotName)")
            return
        }
        //New code
        
        
        dismissBuildMenu()
        let menu = SKNode(); menu.zPosition = 10_001
        cameraNode.addChild(menu); buildMenu = menu

        // Compute panel height: header + N*(btn+gap) - last gap + footer
        
        //Changed availableBuildings.count to allowed.count
        let buttonsBlockH = CGFloat(allowed.count) * (menuButtonH + menuGap) - menuGap
        let panelH = menuHeaderPad + buttonsBlockH + menuFooterPad
        let panelSize = CGSize(width: panelWidth, height: panelH)

        // Panel
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 14)
        
        
        panel.fillColor = UIColor.systemBackground.withAlphaComponent(0.92)
        panel.strokeColor = .clear
        menu.addChild(panel)

        // Title
        let title = SKLabelNode(text: "Choose a building")
        title.fontName = ".SFUI-Bold"
        title.fontSize = 18
        title.fontColor = .label
        title.position = CGPoint(x: 0, y: panelSize.height/2 - 36)
        menu.addChild(title)

        // Buildings list
        var y = panelSize.height/2 - menuHeaderPad - menuButtonH/2
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
        cancel.position = CGPoint(x: 0, y: -panelSize.height/2 + menuFooterPad/2)
        menu.addChild(cancel)
    }

    private func buttonNode(title: String,
                            actionName: String,
                            size: CGSize,
                            isCancel: Bool = false) -> SKNode {
        let node = SKNode(); node.name = actionName

        let bg = SKShapeNode(rectOf: size, cornerRadius: 10)
        bg.fillColor = isCancel
            ? UIColor.systemGray5.withAlphaComponent(0.85)
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
                            guard let uid = self.userId else {
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
        }
        return false
    }
    
    private func showManageMenu(for plot: SKShapeNode) {
        dismissBuildMenu() // reuse the same container slot
        let menu = SKNode(); menu.zPosition = 10_001
        cameraNode.addChild(menu); buildMenu = menu

        // Layout (reuse your sizing constants)
        let buttons = ["Upgrade", "Sell", "Cancel"]
        let buttonsBlockH = CGFloat(buttons.count) * (menuButtonH + menuGap) - menuGap
        let panelH = menuHeaderPad + buttonsBlockH + menuFooterPad
        let panelSize = CGSize(width: panelWidth, height: panelH)

        // Panel
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 14)
        panel.fillColor = UIColor.systemBackground.withAlphaComponent(0.92)
        panel.strokeColor = .clear
        menu.addChild(panel)

        // Title
        let title = SKLabelNode(text: "Manage building")
        title.fontName = ".SFUI-Bold"
        title.fontSize = 18
        title.fontColor = .label
        title.position = CGPoint(x: 0, y: panelSize.height/2 - 36)
        menu.addChild(title)

        // Buttons
        var y = panelSize.height/2 - menuHeaderPad - menuButtonH/2

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
        
        //New Code
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        if let rule = plotRules[plotName], !rule.allowed.contains(assetName) {
            print("🚫 \(assetName) is not allowed on \(plotName)")
            // Optional: flash the plot or show a quick HUD tooltip
            return
        }
        //New Code
        
        //let pos = plot.position
        let pos = positionFor(assetName: assetName, on: plot)
        
        // Create the sprite first
        let level = 1
        let fullName = "\(assetName)_L\(level)"   // e.g. "Barn_L1"

        let sprite: SKSpriteNode

        if UIImage(named: fullName) != nil {
            sprite = SKSpriteNode(imageNamed: fullName)
        } else {
            sprite = SKSpriteNode(color: .systemGreen, size: CGSize(width: 32, height: 32))
            print("⚠️ Asset '\(fullName)' not found. Using placeholder.")
        }
        


        
        // ✅ Now you can safely assign userData
        if sprite.userData == nil { sprite.userData = [:] }
        sprite.userData?["type"] = assetName     // "Barn" or "House"
        sprite.userData?["level"] = level        // start at level 1
        sprite.userData?["plot"] = (plot.userData?["plotName"] as? String) ?? "UnknownPlot"

        sprite.position = pos
        sprite.zPosition = 8

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
        
        // New Code
        let plotName = (plot.userData?["plotName"] as? String) ?? ""
        let maxLevel = plotRules[plotName]?.maxLevel[type] ?? Int.max
        guard nextLevel <= maxLevel else {
            print("\(type) cannot be upgraded beyond L\(maxLevel) on \(plotName)")
            return
        }
        // New Code
        
        // Example: define upgrade cost logic
        let cost = nextLevel * 100  // cost currently set to 100 times the level of the building
        guard let uid = self.userId else {
            print("No userId set on GameScene");
            return
        }

        do {
            // Attempt to spend currency before upgrading
            let newBalance = try await UserManager.shared.spend(userId: uid, amount: cost)
            print("Spent \(cost). New balance: \(newBalance)")

            // 🏗 Proceed with upgrade visuals and data
            
            let newTextureName = "\(type)_L\(nextLevel)"
            if let newImage = UIImage(named: newTextureName) {
                building.texture = SKTexture(imageNamed: newTextureName)
                building.size = building.texture!.size()
                building.userData?["level"] = nextLevel
                print("\(type) upgraded to level \(nextLevel)")
                triggerMapChanged()
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
        
        guard let uid = self.userId else {
            print("No userId set on GameScene")
            return
        }
        do {
            let newBalance = try await UserManager.shared.refund(userId: uid, amount: refundAmount)
            print("Refunded \(refundAmount). New balance: \(newBalance)")
            
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
            return [
                "type": type,
                "plot": plot,
                "x": node.position.x,
                "y": node.position.y
            ]
        }
    }
    
    // Convert your in-memory sprites → typed models
    func getBuildingModels() -> [Building] {
        return buildings.map { Building(node: $0) }
    }

    // Place buildings from typed models (the only new "load" you need)
    func applyLoadedBuildings(_ models: [Building]) {
        for m in models {
            let sprite = m.makeSprite()

            // Keep your existing scaling rules
            let baseBuildingScale: CGFloat = 0.6
            let buildingScaleOverrides: [String: CGFloat] = [
                "House": 0.8,
                "Barn":  0.8
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
        default:
            return 100
        }
    }

    // separates the building name from the full asset Name
    private func baseName(from assetName: String) -> String {
        return assetName.components(separatedBy: "_").first ?? assetName
    }
}
