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
    .init(type: "JackOLantern", price: 100, iconName: "JackOLantern"),
    .init(type: "SunFlower",    price: 80, iconName: "SunFlower"),
    .init(type: "Snowman_04", price: 150, iconName: "Snowman_04"),
    .init(type: "WaterFountain_04", price: 500, iconName: "WaterFountain_04"),
    .init(type: "Well_01", price: 500, iconName: "Well_01"),

]

