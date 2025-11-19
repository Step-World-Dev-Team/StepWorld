//
//  DifficultySelectionView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/16/25.
//
import SwiftUI

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String {
        switch self { case .easy: "Easy"; case .medium: "Medium"; case .hard: "Hard" }
    }
}

struct DifficultySelectionView: View {
    let userId: String
    var onFinished: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasChosenDifficulty") private var hasChosenDifficulty = false
    
    @State private var isSaving = false
    @State private var errorText: String?
    
    var body: some View {
        ZStack {
            // Reuse your cozy sign-in background
            Image("SignInBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            VStack(spacing: 20) {
                Text("Choose Difficulty")
                    .font(.custom("Press Start 2P", size: 24))
                    .foregroundColor(Color(red: 0.180, green: 0.118, blue: 0.071))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    .padding(.top, 36)
                
                Text("You can change this later in Settings.")
                    .font(.custom("Press Start 2P", size: 10))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.235, green: 0.165, blue: 0.118).opacity(0.8))
                    .padding(.horizontal, 24)
                
                VStack(spacing: 14) {
                    ForEach(Difficulty.allCases) { level in
                        Button { choose(level) } label: {
                            Text(level.title)
                                .font(.custom("Press Start 2P", size: 18))
                                .foregroundColor(Color(red: 1.0, green: 0.973, blue: 0.906))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(red: 0.89, green: 0.49, blue: 0.30))
                                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 0.9216, green: 0.8431, blue: 0.6980), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func choose(_ level: Difficulty) {
        // Mark this SPECIFIC user as onboarded on this device
        UserDefaults.standard.set(true, forKey: "hasChosenDifficulty.\(userId)")
        
        // Optional: stash the selected level locally per user too
        UserDefaults.standard.set(level.rawValue, forKey: "difficulty_local_choice.\(userId)")
        
        onFinished?()
        dismiss() // fullScreenCover goes away → map shows
    }
}
