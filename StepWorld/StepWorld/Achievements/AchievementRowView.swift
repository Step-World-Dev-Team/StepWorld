//
//  AchievementRowView.swift
//  StepWorld
//
//  Created by Isai soria on 11/24/25.
//
import SwiftUI

struct AchievementRowView: View {
    let row: AchievementsViewModel.Row
    let onClaim: () async -> Void
    
    @State private var isClaiming = false
    
    // Palette similar to your UI
    private let pixelCream = Color(red: 0.96, green: 0.92, blue: 0.80)
    private let pixelBrown = Color(red: 0.45, green: 0.31, blue: 0.22)
    private let pixelDark  = Color(red: 0.15, green: 0.15, blue: 0.15)
    private let pixelGreen = Color(red: 0.25, green: 0.80, blue: 0.40)
    
    var body: some View {
        ZStack {
        
            RoundedRectangle(cornerRadius: 6)
                .fill(pixelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(pixelDark, lineWidth: 3)
                )
            
            HStack(spacing: 10) {
                
                // LEFT: small pixel icon box
                ZStack {
                    Rectangle()
                        .fill(pixelDark)
                        .overlay(
                            Rectangle()
                                .stroke(pixelBrown, lineWidth: 2)
                        )
                        .frame(width: 38, height: 38)
                    
                    Text(iconEmoji)
                        .font(.system(size: 20))
                }
                
                // MIDDLE: text and progress
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.definition.title)
                        .font(.custom("Press Start 2P", size: 9))
                        .foregroundColor(pixelDark)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    Text("\(row.achievement.progress) / \(row.achievement.target)")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundColor(pixelBrown)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(pixelDark.opacity(0.2))
                                .overlay(
                                    Rectangle()
                                        .stroke(pixelDark, lineWidth: 2)
                                )
                                .frame(height: 10)
                            
                            Rectangle()
                                .fill(pixelGreen)
                                .frame(width: progressWidth(total: geo.size.width),
                                       height: 10)
                        }
                    }
                    .frame(height: 10)
                }
                
                Spacer()
                
                
                statusView
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 78)
        .frame(maxWidth: 280)
    }
    
    private func progressWidth(total: CGFloat) -> CGFloat {
        let p = Double(row.achievement.progress) / Double(row.achievement.target)
        let clamped = max(0, min(p, 1))
        return total * CGFloat(clamped)
    }
    
    private var iconEmoji: String {
        switch row.definition.id {
        case .lifetime10k, .lifetime30k, .lifetime50k: return "👣"
        case .day5k, .day7_5k, .day10k, .day12k:       return "⏱"
        case .firstBuilding: return "🏡"
        case .firstDecor:    return "🌼"
        case .firstSkin:     return "🎨"
        }
    }
    
    // MARK: Right-side status
    @ViewBuilder
    private var statusView: some View {
        if row.achievement.isClaimed {
            pixelTag(text: "CLAIMED", fill: pixelGreen)
        } else if row.achievement.isCompleted {
            Button {
                guard !isClaiming else { return }
                isClaiming = true
                Task {
                    await onClaim()
                    isClaiming = false
                }
            } label: {
                if isClaiming {
                    ProgressView()
                        .scaleEffect(1.1)
                } else {
                    pixelTag(text: "CLAIM", fill: pixelGreen)
                }
            }
            .buttonStyle(.plain)
        } else {
            pixelTag(text: "LOCKED", fill: pixelDark.opacity(0.4))
        }
    }
    
    private func pixelTag(text: String, fill: Color) -> some View {
        Text(text)
            .font(.custom("Press Start 2P", size: 8))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Rectangle()
                    .fill(fill)
                    .overlay(
                        Rectangle()
                            .stroke(pixelDark, lineWidth: 2)
                    )
            )
    }
}
