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
                return ("House – Lvl 1", "\n\n\nA cozy starter\n home for new\n settlers.\n\n Upgrade: $200")
            case 2:
                return ("House – Lvl 2", "\n\nExpanded living\n space with room for \n  growth.\n Upgrade: $200")
            default: return ("House – Lv\(level)", "Upgraded home.")
            }
            
        case ("House", "Candy"):
            switch level {
            case 1:
                return ("Snowy House – Lvl 1",
                        "\n\nA warm little\n house, perfect for hot cocoa\n Upgrade: $200")
            case 2:
                return ("Snowy House – Lvl 2",
                        "\nYour festive home, candy included\n Upgrade: $200")
            default:
                return ("Snowy House – Lvl \(level)",
                        "\nYour festive home\n where every day\n feels like winter.\n Upgrade: $200")
            }
        case ("Barn", nil),
            ("Barn", "Default"):
            switch level {
            case 1:
                return ("Barn – Lvl 1", "\n \nA simple barn,\n perfect for\n beginner farmers.\n Upgrade: $200")
            case 2:
                return ("Barn – Lvl 2", "\n\nReinforced structure,can house more animals.\n Upgrade: $200")
            case 3:
                return ("Barn – Lvl 3", "\n\nA well-stocked\n barn buzzing with \n  activity.\n Upgrade: $200")
            case 4:
                return ("Barn – Lvl 4", "\n\nA well-stocked\n barn buzzing with \n  activity.\n Upgrade: $200")
            default: return ("Barn – Lvl\(level)", "\n A full barn,\nthe heart of your \n growing farm!\n Upgrade: $200")
                
            }
            // MARK: - Barn – Blue skin
        case ("Barn", "Blue"):
            switch level {
            case 1:
                return ("Blue Barn – Lvl 1",
                        "\n\nA bright blue\n barn that pops\n on the horizon.\n Upgrade: $200")
            case 2:
                return ("Blue Barn – Lvl 2",
                        "\n\nRepainted and sturdy,ready for more animals.\n Upgrade: $200")
            case 3:
                return ("Blue Barn – Lvl 3",
                        "\n\nThe most stylish\n  barn in town – a\n  true farm icon.\n Upgrade: $200")
            default:
                return ("Blue Barn – Lvl \(level)",
                        "\n\nA legendary blue barn everyone in\n town talks about.\n Upgrade: $200")
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
