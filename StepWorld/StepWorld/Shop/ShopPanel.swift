//
//  ShopPanel.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/9/25.
//
import SwiftUI

struct ShopPanel: View {
    // Data
    let items: [ShopItem]

    // Actions
    var onClose: () -> Void
    var onBuy: (ShopItem) -> Void

    // Ownership / equipped checkers provided by the caller
    var isOwned: (ShopItem) -> Bool = { _ in false }
    var isEquipped: (ShopItem) -> Bool = { _ in false }

    private let cols = Array(repeating: GridItem(.fixed(90), spacing: 14), count: 3)

    var body: some View {
        ZStack {
            // Panel background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brown.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.4), lineWidth: 3)
                )
                .shadow(radius: 6)

            VStack(spacing: 12) {
                Text("SHOP")
                    .font(.custom("PressStart2P-Regular", size: 20))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                ScrollView {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(items) { item in
                            // --- State for this tile ---
                            let owned     = isOwned(item)
                            let equipped  = isEquipped(item)
                            let isDefault = item.type.hasSuffix("#Default")
                            let isSkin    = item.type.contains("#")

                            Button {
                                onBuy(item)         // caller decides buy/equip/clear
                            } label: {
                                ZStack {
                                    // Tile background
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.orange.opacity(0.9))
                                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 3)
                                        .frame(width: 90, height: 90)

                                    VStack(spacing: 6) {
                                        Image(item.iconName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 54, height: 54)

                                        // Label row:
                                        // - hide price for owned items and default
                                        // - show "Equipped" when equipped
                                        // - show "Equip" for owned but not equipped
                                        if isSkin {
                                            if equipped {
                                                Text("Equipped")
                                                    .font(.custom("PressStart2P-Regular", size: 9))
                                                    .foregroundStyle(.white)
                                            } else if owned || isDefault {
                                                Text("Equip")
                                                    .font(.custom("PressStart2P-Regular", size: 9))
                                                    .foregroundStyle(.white)
                                            } else {
                                                Text("$\(item.price)")
                                                    .font(.custom("PressStart2P-Regular", size: 10))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        else {
                                            // Decor/buildings: always show price, never "Equip/Equipped"
                                            Text("$\(item.price)")
                                                .font(.custom("PressStart2P-Regular", size: 10))
                                                .foregroundStyle(.white)
                                        }
                                                                            }
                                }
                                // Glow ring when equipped
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke((isSkin && equipped) ? Color.yellow.opacity(0.95) : .clear,
                                                lineWidth: (isSkin && equipped) ? 4 : 0)
                                        .shadow(color: (isSkin && equipped) ? Color.yellow.opacity(0.7) : .clear,
                                                radius: (isSkin && equipped) ? 10 : 0)
                                )
                                .animation(.easeInOut(duration: 0.2), value: equipped)
                            }
                            .disabled(isSkin && equipped) // no-op tap when already equipped
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }

                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Text("Close")
                            .font(.custom("PressStart2P-Regular", size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.bottom, 12)
                    .padding(.trailing, 12)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 360, maxHeight: 480)
        .background(Color.clear)
    }
}
