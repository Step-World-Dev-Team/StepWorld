//
//  DailyGoalRowView.swift
//  StepWorld
//
//  Created by Eric Rodriguez on 11/25/25.
//


import SwiftUI

struct DailyGoalRowView: View {
    let progress: Int
    let target: Int
    
    // Same palette as AchievementRowView
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
                // LEFT: icon box
                ZStack {
                    Rectangle()
                        .fill(pixelDark)
                        .overlay(
                            Rectangle()
                                .stroke(pixelBrown, lineWidth: 2)
                        )
                        .frame(width: 38, height: 38)
                    
                    Text("🎯")
                        .font(.system(size: 20))
                }
                
                // MIDDLE: text + progress bar
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY'S GOAL")
                        .font(.custom("Press Start 2P", size: 9))
                        .foregroundColor(pixelDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("\(progress) / \(target) steps")
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
                
                // RIGHT: status tag similar to achievements
                if progress >= target {
                    pixelTag(text: "DONE", fill: pixelGreen)
                } else {
                    pixelTag(text: "IN PROGRESS", fill: pixelDark.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 78)
        .frame(maxWidth: 280)
    }
    
    private func progressWidth(total: CGFloat) -> CGFloat {
        guard target > 0 else { return 0 }
        let p = Double(progress) / Double(target)
        let clamped = max(0, min(p, 1))
        return total * CGFloat(clamped)
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

