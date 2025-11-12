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

    private let cols = Array(repeating: GridItem(.fixed(90), spacing: 14), count: 3)

    var body: some View {
        ZStack {
            // Background – use your wood image if available
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
        Button { onBuy(item) } label: {
            
        ZStack {
        // Tile background
        RoundedRectangle(cornerRadius: 8)
        .fill(Color.orange.opacity(0.9))
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 3)
        .frame(width: 90, height: 90)

        VStack(spacing: 6) {
        Image(item.iconName)      // your PNG from Assets
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

