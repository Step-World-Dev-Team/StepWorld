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
        switch self {
        case .easy:   "Easy"
        case .medium: "Medium"
        case .hard:   "Hard"
        }
    }
    var blurb: String {
        switch self {
        case .easy:   return "3,000 steps per day"
        case .medium: return "6,000 steps per day"
        case .hard:   return "10,000+ steps per day"
        }
    }
}

struct DifficultySelectionView: View {
    let userId: String
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasChosenDifficulty") private var hasChosenDifficulty = false

    private let buttonWidth: CGFloat = 300
    private let buttonHeight: CGFloat = 48
    private let sideGutter: CGFloat = 24

    var body: some View {
        ZStack {
            // Background
            Image("SignInBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Title
                Text("Choose Difficulty")
                    .font(.custom("Press Start 2P", size: 24))
                    .foregroundColor(Color(red: 0.90, green: 0.93, blue: 0.97))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    .padding(.top, 36)
                    .padding(.horizontal, sideGutter)
                    .padding(.bottom, 40)

                // Buttons
                ScrollView {
                    LazyVStack(spacing: 28) {
                    ForEach(Difficulty.allCases) { level in
                    VStack(spacing: 10) {
                        Button { choose(level) } label: {
                        Text(level.title)
                            .font(.custom("Press Start 2P", size: 18))
                            .frame(height: buttonHeight)
                            .frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .tint(Color(red: 0.89, green: 0.49, blue: 0.30))
                            .frame(width: buttonWidth)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, sideGutter)

                        // Description directly under the button
                        Text(level.blurb)
                            .font(.custom("Press Start 2P", size: 14))
                            .foregroundColor(Color(red: 1.0, green: 0.973, blue: 0.906))
                            .multilineTextAlignment(.center)
                            .frame(width: buttonWidth)
                            .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Text("You can change this later in Settings.")
                    .font(.custom("Press Start 2P", size: 10))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.90, green: 0.93, blue: 0.97))
                    .padding(.vertical, 14)
                    .padding(.horizontal, sideGutter)
            }
        }
    }

    private func choose(_ level: Difficulty) {
        UserDefaults.standard.set(true, forKey: "hasChosenDifficulty.\(userId)")
        UserDefaults.standard.set(level.rawValue, forKey: "difficulty_local_choice.\(userId)")
        onFinished?()
        dismiss()
    }
}
