//
//  DailyGoalBannerView.swift
//  StepWorld
//
//  Created by Eric Rodriguez on 11/25/25.
//

import SwiftUI

struct DailyGoalBannerView: View {
    let steps: Int
    let goal: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                // Swap this to whatever asset you want (e.g. a shoe or steps icon)
                Image("StepsEmoji")        // <- or use system image below
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                // If you prefer SF Symbols, use:
                // Image(systemName: "figure.walk")
                //    .resizable()
                //    .aspectRatio(contentMode: .fit)
                //    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily goal reached!")
                        .font(.custom("Press Start 2P", size: 12))
                        .foregroundColor(Color(red: 0.180, green: 0.118, blue: 0.071))
                    
                    Text("You walked \(steps) / \(goal) steps today.")
                        .font(.custom("Press Start 2P", size: 9))
                        .foregroundColor(
                            Color(red: 0.180, green: 0.118, blue: 0.071).opacity(0.85)
                        )
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
                            .stroke(Color(red: 0.89, green: 0.49, blue: 0.30).opacity(0.8),
                                    lineWidth: 1.5)
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
