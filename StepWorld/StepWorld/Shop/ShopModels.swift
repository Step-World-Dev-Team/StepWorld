//
//  ShopModels.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/9/25.
//
import Foundation

struct ShopItem: Identifiable {
    let id = UUID()
    let type: String      // matches your asset name: "JackOLantern", "SunFlower"
    let price: Int
    let iconName: String  // typically same as type
}

let defaultShopItems: [ShopItem] = [
    .init(type: "JackOLantern", price: 150, iconName: "JackOLantern"),
    .init(type: "SunFlower",    price: 120, iconName: "SunFlower"),
]

