//
//  ShopPanel.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/9/25.
//
import SwiftUI

struct ShopPanel: View {
    let items: [ShopItem]
    var onClose: () -> Void
    var onBuy: (ShopItem) -> Void

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
                        // Use a stable key for id; change to your unique field if needed
                        ForEach(items, id: \.type) { item in
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
                                        Text("$\(item.price)")
                                            .font(.custom("PressStart2P-Regular", size: 10))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                .padding(.top,120)
            }
            .padding(.vertical, 8)
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
