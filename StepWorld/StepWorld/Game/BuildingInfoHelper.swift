//
//  BuildingInfoHelper.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/23/25.
//

import SpriteKit
import Foundation

extension GameScene {
    // MARK: - Building Info Utilities
    
    func buildingDescription(type: String, level: Int) -> (title: String, blurb: String) {
        switch type {
        case "House":
            switch level {
            case 1: return ("House – Lvl 1", "\nA cozy starter\n home for new\n settlers.")
            case 2: return ("House – Lvl 2", "\n  Expanded living\n space with room for \n  growth.")
            default: return ("House – Lv\(level)", "Upgraded home.")
            }
        case "Barn":
            switch level {
            case 1: return ("Barn – Lvl 1", "\n A simple barn,\n perfect for\n beginner farmers.")
            case 2: return ("Barn – Lvl 2", "\n\nReinforced structure,can house more animals.")
            case 3: return ("Barn – Lvl 3", "\n  A well-stocked\n barn buzzing with \n  activity.")
            default: return ("Barn – Lvl\(level)", "\n A full barn,\nthe heart of your \n growing farm!")
                
            }
        default:
            // covers any building type you haven’t explicitly handled
            return ("\(type) – Lvl \(level)", "Upgraded building.")
        }
    }
    func updateManageMenuInfo(for building: SKSpriteNode) {
        let bType = (building.userData?["type"] as? String) ?? "Building"
        let bLevel = (building.userData?["level"] as? Int) ?? 1
        let info = buildingDescription(type: bType, level: bLevel)
        
        guard let menuNode = (self.buildMenu as SKNode?) else { return }
        (menuNode.childNode(withName: "infoTitle") as? SKLabelNode)?.text = info.title
        (menuNode.childNode(withName: "infoBody")  as? SKLabelNode)?.text = info.blurb

        }
    }


