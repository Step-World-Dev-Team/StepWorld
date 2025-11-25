//
//  AchievementRowView.swift
//  StepWorld
//
//  Created by Isai soria on 11/24/25.
//

import SwiftUI

struct AchievementRowView: View {
    let row: AchievementsViewModel.Row
    let onClaim: () async -> Void    // injected from parent
    
    @State private var isClaiming = false
    
    var body: some View {
        HStack(spacing: 12) {
            // TODO: Replace with custom icon per achievement if desired
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("🏅") // placeholder
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // TODO: use custom font (e.g. Press Start 2P)
                Text(row.definition.title)
                    .font(.headline)
                
                // Progress text
                Text("\(row.achievement.progress) / \(row.achievement.target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Simple progress bar skeleton
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: progressWidth(in: geo.size.width))
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            // Right-side status: Claim / Claimed / nothing
            statusView
        }
        .padding(.vertical, 8)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let p = Double(row.achievement.progress) / Double(row.achievement.target)
        return totalWidth * CGFloat(max(0, min(p, 1)))
    }
    
    @ViewBuilder
    private var statusView: some View {
        if row.achievement.isClaimed {
            // Already claimed
            Text("Claimed")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(8)
            
        } else if row.achievement.isCompleted {
            // Completed but not claimed
            Button {
                if !isClaiming {
                    isClaiming = true
                    Task {
                        await onClaim()
                        isClaiming = false
                    }
                }
            } label: {
                if isClaiming {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("Claim")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            
        } else {
            // Not completed – show nothing or a "Locked" indicator
            // TODO: designer can choose locked state UI
            Text("") // Empty for now
                .frame(width: 60) // keeps rows aligned
        }
    }
}
