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
    
    @StateObject private var vm = ShopPanelViewModel()

    private let cols = Array(repeating: GridItem(.fixed(90), spacing: 8), count: 3)

    var body: some View {
        ZStack {
            // Background
            Image("ShopViewBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            //Close button
            HStack {
                    Spacer()
                VStack {
                    Button {
                        onClose()   // trigger close action
                    } label: {
                        Image("close_button") // same asset as ProfileView
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
        
            VStack(spacing: 12) {
                // Grid
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(items, id: \.type) { item in
                            // --- State for this tile ---
                            let owned     = isOwned(item)
                            let equipped  = isEquipped(item)
                            let isDefault = item.type.hasSuffix("#Default")
                            let isSkin    = item.type.contains("#")
                            
                            Button { onBuy(item) } label: {
                                ZStack {
                                    // Tile background
                                    Image("Shop_square")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()
                                    
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
                                                    .foregroundStyle(.black)
                                            } else if owned || isDefault {
                                                Text("Equip")
                                                    .font(.custom("PressStart2P-Regular", size: 9))
                                                    .foregroundStyle(.black)
                                            } else {
                                                Text("$\(item.price)")
                                                    .font(.custom("PressStart2P-Regular", size: 10))
                                                    .foregroundStyle(.black)
                                            }
                                        }
                                        else {
                                            // Decor/buildings: always show price, never "Equip/Equipped"
                                            Text("$\(item.price)")
                                                .font(.custom("PressStart2P-Regular", size: 10))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                }
                                // Glow ring when equipped
                                .overlay(
                                    Rectangle()
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
                .padding(.top,120)
                
                ZStack {
                    Image("clear_button")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(height: 60)  // adjust to your art

                        HStack(spacing: 8) {
                            Image("Coin") // optional icon
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 22, height: 22)

                            Text(vm.balance.map { $0.formatted() } ?? "--")
                                .font(.custom("PressStart2P-Regular", size: 14))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, 50)
            .task { await vm.loadBalance() }
        }
        .frame(maxWidth: 360, maxHeight: 480)
        .background(Color.clear)
    }
}

#Preview {
    ShopPanel(
        items: [
            ShopItem(type: "Barn",  price: 300, iconName: "Barn_L1"),
            ShopItem(type: "House", price: 200, iconName: "House_L1"),
            ShopItem(type: "Tree",  price: 100, iconName: "Tree_L1"),
        ],
        onClose: {},
        onBuy: { item in print("Preview buy tapped:", item.type) }
    )
    .padding()
}
