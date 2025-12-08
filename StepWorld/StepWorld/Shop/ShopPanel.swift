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
        // Split items into sections
        let skinItems  = items.filter { $0.type.contains("#") }
        let decorItems = items.filter { !$0.type.contains("#") }

        return ZStack {
            // BACKGROUND
            Image("ShopViewBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // MAIN CONTENT (yellow panel)
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // --- Building Skins section ---
                        if !skinItems.isEmpty {
                            Text("Building Skins")
                                .font(.custom("PressStart2P-Regular", size: 12))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)


                            LazyVGrid(columns: cols, spacing: 14) {
                                ForEach(skinItems, id: \.type) { item in
                                    itemTile(for: item)
                                }
                            }
                            .padding(.horizontal, 18)
                        }

                        // --- Decor section ---
                        if !decorItems.isEmpty {
                            Text("Decor")
                                .font(.custom("PressStart2P-Regular", size: 12))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)

                            LazyVGrid(columns: cols, spacing: 14) {
                                ForEach(decorItems, id: \.type) { item in
                                    itemTile(for: item)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                    
                    .padding(.bottom, 8)
                }
                .padding(.top, 120)
                .scrollIndicators(.hidden)
                // COIN BAR
                ZStack {
                    Image("clear_button")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(height: 60)

                    HStack(spacing: 8) {
                        Image("Coin")
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

            // CLOSE BUTTON OVERLAY (on top of everything)
            HStack {
                Spacer()
                VStack {
                    Button {
                        onClose()
                    } label: {
                        Image("close_button")
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
            .zIndex(1)   // make sure it's above the ScrollView
        }
        .task { await vm.loadBalance() }
        .frame(maxWidth: 360, maxHeight: 480)
        .background(Color.clear)
    }

    
    // MARK: - Tile builder (shared by both sections)
    private func itemTile(for item: ShopItem) -> some View {
        let owned     = isOwned(item)
        let equipped  = isEquipped(item)
        let isDefault = item.type.hasSuffix("#Default")
        let isSkin    = item.type.contains("#")

        return Button { onBuy(item) } label: {
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
                        .interpolation(.none)
                        .antialiased(false)
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                    
                    if isSkin {
                        // Skins = price / Equip / Equipped
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
                    } else {
                        // Decor/buildings: always show price
                        Text("$\(item.price)")
                            .font(.custom("PressStart2P-Regular", size: 10))
                            .foregroundStyle(.black)
                    }
                }
            }
            // Glow ring when equipped skin
            .overlay(
                Rectangle()
                    .stroke((isSkin && equipped) ? Color.green.opacity(0.95) : .clear,
                            lineWidth: (isSkin && equipped) ? 4 : 0)
                    .shadow(color: (isSkin && equipped) ? Color.green.opacity(0.7) : .clear,
                            radius: (isSkin && equipped) ? 10 : 0)
            )
            .animation(.easeInOut(duration: 0.2), value: equipped)
        }
        .disabled(isSkin && equipped) // already equipped → no-op
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
