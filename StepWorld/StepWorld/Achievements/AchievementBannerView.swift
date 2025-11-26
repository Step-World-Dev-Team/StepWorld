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
                Text("🏆")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievement completed!")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 6)
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
