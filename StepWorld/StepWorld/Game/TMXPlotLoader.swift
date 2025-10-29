//
//  TMXPlotLoader.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/25/25.
//

import Foundation
import CoreGraphics

// MARK: - Basic TMX Map Info

struct TMXMapInfo {
    let cols: Int
    let rows: Int
    let tileSize: CGSize
    
    var pixelSize: CGSize {
        CGSize(width: CGFloat(cols) * tileSize.width,
               height: CGFloat(rows) * tileSize.height)
    }
}

// MARK: - Plot Rectangle Object

struct PlotObject {
    let name: String
    let rectPx: CGRect   // Rectangle in Tiled pixel coordinates (origin top-left)
}

// MARK: - TMX Plot Loader

final class TMXPlotLoader: NSObject, XMLParserDelegate {
    private(set) var info = TMXMapInfo(cols: 0, rows: 0, tileSize: .zero)
    private var inPlots = false
    private var plots: [PlotObject] = []
    private var plotLayerName = "Plots"
    
    /// Load TMX and extract rectangles from a specific object layer.
    static func load(tmxNamed name: String, plotLayerName: String = "Plots")
    -> (TMXMapInfo, [PlotObject])? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "tmx"),
              let parser = XMLParser(contentsOf: url) else {
            print("⚠️ Could not find \(name).tmx in bundle.")
            return nil
        }
        let loader = TMXPlotLoader()
        loader.plotLayerName = plotLayerName
        parser.delegate = loader
        if parser.parse() {
            return (loader.info, loader.plots)
        } else {
            print("⚠️ Failed to parse TMX \(name)")
            return nil
        }
    }
    
    // MARK: - XML Parsing
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "map":
            let cols = Int(attributeDict["width"] ?? "0") ?? 0
            let rows = Int(attributeDict["height"] ?? "0") ?? 0
            let tileW = Int(attributeDict["tilewidth"] ?? "0") ?? 0
            let tileH = Int(attributeDict["tileheight"] ?? "0") ?? 0
            info = TMXMapInfo(cols: cols, rows: rows, tileSize: CGSize(width: tileW, height: tileH))
            
        case "objectgroup":
            let name = attributeDict["name"] ?? ""
            inPlots = (name.caseInsensitiveCompare(plotLayerName) == .orderedSame)
            
        case "object":
            guard inPlots else { return }
            let name = attributeDict["name"] ?? ""
            let x = Double(attributeDict["x"] ?? "0") ?? 0
            let y = Double(attributeDict["y"] ?? "0") ?? 0
            let w = Double(attributeDict["width"] ?? "0") ?? 0
            let h = Double(attributeDict["height"] ?? "0") ?? 0
            let rect = CGRect(x: x, y: y, width: w, height: h)
            plots.append(PlotObject(name: name, rectPx: rect))
            
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "objectgroup" {
            inPlots = false
        }
    }
}
