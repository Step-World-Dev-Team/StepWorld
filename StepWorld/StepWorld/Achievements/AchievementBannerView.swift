//
//  AchievementBannerView.swift
//  StepWorld
//
//  Created by Isai soria on 11/25/25.
//

import Foundation
import SwiftUI

struct AchievementBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                // TODO: swap emoji for a pixel-art icon later
                Image("TrophyEmoji")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievement completed!")
                        .font(.custom("Press Start 2P", size: 12))
                        .foregroundColor(Color(red: 0.180, green: 0.118, blue: 0.071))
                    
                    Text(message)
                        .font(.custom("Press Start 2P", size: 9))
                        .foregroundColor(Color(red: 0.180, green: 0.118, blue: 0.071).opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
            // soft cream color, slightly see-through so map shows behind
                        .fill(Color(red: 1.0, green: 0.9725, blue: 0.9059).opacity(0.85))
                        .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.89, green: 0.49, blue: 0.30).opacity(0.8), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    )
                        .padding(.horizontal, 16)
            
            Spacer()
        }
        .padding(.top, 40)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after ~3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            onDismiss()
        }
    }
}
