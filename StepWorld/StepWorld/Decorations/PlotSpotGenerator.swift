//
//  PlotSpotGenerator.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/7/25.
//
import SpriteKit

public enum PlotSpotStyle {
    case visibleDots       // small circles, made these invisible 
    case cornerBrackets    // corners only (subtle)
}

public struct PlotSpotGenerator {

    public static func makeSpots(in plot: SKShapeNode,
                                 cols: Int = 3,
                                 rows: Int = 2,
                                 inset: CGFloat = 14,
                                 radius: CGFloat = 8,
                                 style: PlotSpotStyle = .visibleDots) -> [SKNode] {

        let size = plot.path?.boundingBox.size ?? .zero
        guard size.width > 0, size.height > 0, cols > 0, rows > 0 else { return [] }

        let halfW = size.width * 0.5
        let halfH = size.height * 0.5

        let usableW = size.width  - inset * 2
        let usableH = size.height - inset * 2

        let dx = cols == 1 ? 0 : usableW / CGFloat(cols - 1)
        let dy = rows == 1 ? 0 : usableH / CGFloat(rows - 1)

        var nodes: [SKNode] = []

        for r in 0..<rows {
            for c in 0..<cols {
                let x = -halfW + inset + CGFloat(c) * dx
                let y = -halfH + inset + CGFloat(r) * dy

                switch style {
                case .visibleDots:
                    let dot = SKShapeNode(circleOfRadius: radius)
                    dot.fillColor = .white.withAlphaComponent(0.9)
                    dot.strokeColor = UIColor.black.withAlphaComponent(0.35)
                    dot.lineWidth = 1
                    dot.alpha = 0.9
                    dot.zPosition = 900
                    dot.name = "decorSpot"
                    dot.position = CGPoint(x: x, y: y)
                    nodes.append(dot)

                case .cornerBrackets:
                    // optional alt style: leave for future
                    let dot = SKShapeNode(circleOfRadius: radius)
                    dot.fillColor = .white.withAlphaComponent(0.8)
                    dot.strokeColor = .clear
                    dot.name = "decorSpot"
                    dot.position = CGPoint(x: x, y: y)
                    nodes.append(dot)
                }
            }
        }
        return nodes
    }

    /// Rescales any billboarded nodes (spots) to keep a constant on-screen size
    public static func rescaleBillboardSpots(in plots: [SKShapeNode], cameraScale: CGFloat) {
        let inv = 1.0 / cameraScale
        for plot in plots {
            for n in plot.children where n.name == "decorSpot" {
                n.setScale(inv)
            }
        }
    }
}

