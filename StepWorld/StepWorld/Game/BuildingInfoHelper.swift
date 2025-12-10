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
                return ("House – Lvl 1", "\n\nA cozy starter\nhome for new\nsettlers.\nUpgrade: $200")
            case 2:
                return ("House – Lvl 2", "\n\nExpanded living\n space with room for \n  growth.\n")
            default: return ("House – Lv\(level)", "Upgraded home.")
            }
            
        case ("House", "Candy"):
            switch level {
            case 1:
                return ("Snowy House– Lvl 1",
                        "\n\nA warm little\n house, perfect\nfor hot cocoa\nUpgrade: $200")
            case 2:
                return ("Snowy House– Lvl 2",
                        "\nYour festive home, candy included!")
            default:
                return ("Snowy House – Lvl \(level)",
                        "\nYour festive home\n where every day\n feels like winter.\n Upgrade: $200")
            }
        case ("Barn", nil),
            ("Barn", "Default"):
            switch level {
            case 1:
                return ("Barn – Lvl 1", "\n\nA simple barn,\n perfect for\n beginner farmers.\nUpgrade: $200")
            case 2:
                return ("Barn – Lvl 2", "\n\nReinforced structure, can house more animals.\nUpgrade: $300")
            case 3:
                return ("Barn – Lvl 3", "\n\nA well-stocked\nbarn buzzing with\nactivity.\nUpgrade: $400")
            case 4:
                return ("Barn – Lvl 4", "\n\nA well-stocked\n barn buzzing with \n  activity!")
                
            default: return ("Barn – Lvl\(level)", "\n A full barn,\nthe heart of your \n growing farm!\n Upgrade: $200")
                
            }
            // MARK: - Barn – Blue skin
        case ("Barn", "Blue"):
            switch level {
            case 1:
                return ("Blue Barn – Lvl 1",
                        "\n\nA bright blue\nbarn that pops\non the horizon.\nUpgrade: $200")
            case 2:
                return ("Blue Barn – Lvl 2",
                        "\n\nRepainted and sturdy,ready for more animals.\nUpgrade: $300")
            case 3:
                return ("Blue Barn – Lvl 3",
                        "\n\nThe most stylish\n  barn in town, a\n  true farm icon.\n")
            default:
                return ("Blue Barn – Lvl \(level)",
                        "\n\nA legendary blue barn everyone in\ntown talks about!")
            }
        case ("Blacksmith", nil),
                 ("Blacksmith", "Default"):
                switch level {
                case 1:
                    return ("Blacksmith – Lvl 1",
                            "\n\nA small forge\nwhere simple tools\nare crafted.\nUpgrade: $200")
                case 2:
                    return ("Blacksmith – Lvl 2",
                            "\n\nHotter fires and\nbetter tools for\nyour settlers.\nUpgrade: $300")
                case 3:
                    return ("Blacksmith – Lvl 3",
                            "\n\nA master smithy\npowering your\nentire town!")
                default:
                    return ("Blacksmith – Lvl \(level)",
                            "\n\nA master smithy\n powering your\n entire town.\n Upgrade: $500")
                }

            // MARK: - Farm (default skin)
            case ("Farm", nil),
                 ("Farm", "Default"):
                switch level {
                case 1:
                    return ("Farm – Lvl 1",
                            "\n\nA small plot\ngrowing basic\ncrops.\n Upgrade: $200")
                case 2:
                    return ("Farm – Lvl 2",
                            "\n\nMore fields mean\nmore food for\nyour people.\n Upgrade: $300")
                case 3:
                    return ("Farm – Lvl 3",
                            "\n\nA thriving farm\nsustaining a\ngrowing town.\n Upgrade: $400")
                default:
                    return ("Farm – Lvl \(level)",
                            "\n\nAn abundant farm\n that never seems\n to run dry!")
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
