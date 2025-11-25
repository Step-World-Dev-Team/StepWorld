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
    
    func buildingDescription(type: String,
                             skin: String?,
                             level: Int) -> (title: String, blurb: String) {
        switch (type, skin) {
        case ("House", nil), ("House", "Default"):
            switch level {
            case 1:
                return ("House – Lvl 1", "\nA cozy starter\n home for new\n settlers.")
            case 2:
                return ("House – Lvl 2", "\n  Expanded living\n space with room for \n  growth.")
            default: return ("House – Lv\(level)", "Upgraded home.")
            }
            
        case ("House", "Candy"):
            switch level {
            case 1:
                return ("Snowy House – Lvl 1",
                        "\n\nA warm little\n house, perfect for winter naps and \nhot cocoa")
            case 2:
                return ("Snowy House – Lvl 2",
                        "\nYour festive home\n where every day\n feels like winter.")
            default:
                return ("Snowy House – Lvl \(level)",
                        "\nYour festive home\n where every day\n feels like winter.")
                    }
        case ("Barn", nil),
             ("Barn", "Default"):
            switch level {
            case 1:
                return ("Barn – Lvl 1", "\n A simple barn,\n perfect for\n beginner farmers.")
            case 2:
                return ("Barn – Lvl 2", "\nReinforced structure,can house more animals.")
            case 3:
                return ("Barn – Lvl 3", "\n  A well-stocked\n barn buzzing with \n  activity.")
            default: return ("Barn – Lvl\(level)", "\n A full barn,\nthe heart of your \n growing farm!")
                
            }
            // MARK: - Barn – Blue skin
        case ("Barn", "Blue"):
        switch level {
            case 1:
                return ("Blue Barn – Lvl 1",
                        "\nA bright blue\n barn that pops\n on the horizon.")
            case 2:
                return ("Blue Barn – Lvl 2",
                        "\n \nRepainted and sturdy,\nready for more\n animals.")
            case 3:
                return ("Blue Barn – Lvl 3",
                        "\n  The most stylish\n  barn in town – a\n  true farm icon.")
            default:
                return ("Blue Barn – Lvl \(level)",
                        "\nA legendary blue\n barn everyone in\n town talks about.")
                       }
        default:
            // covers any building type you haven’t explicitly handled
            return ("\(type) – Lvl \(level)", "Upgraded building.")
        }
    }
    func updateManageMenuInfo(for building: SKSpriteNode) {
        let bType = (building.userData?["type"] as? String) ?? "Building"
        let bLevel = (building.userData?["level"] as? Int) ?? 1
        let skin = (building.userData?["skin"] as? String)
        
        let info = buildingDescription(type: bType, skin: skin, level: bLevel)
        
        guard let menuNode = (self.buildMenu as SKNode?) else { return }
        (menuNode.childNode(withName: "infoTitle") as? SKLabelNode)?.text = info.title
        (menuNode.childNode(withName: "infoBody")  as? SKLabelNode)?.text = info.blurb

        }
    }


