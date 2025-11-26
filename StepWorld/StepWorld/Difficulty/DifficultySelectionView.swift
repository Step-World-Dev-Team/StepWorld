//
//  DifficultySelectionView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/16/25.
//

import SwiftUI
import FirebaseAuth

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
    var coinPerStep: Double {
        switch self {
        case .easy:   return 1.0
        case .medium: return 0.75
        case .hard:   return 0.5
        }
    }
    var ratioDescription: String {
        switch self {
        case .easy:   return "1 step = 1 coin"
        case .medium: return "1 step = 0.75 coin"
        case .hard:   return "1 step = 0.5 coin"
        }
    }
 
    var dailyStepGoal: Int {
            switch self {
            case .easy:   return 3_000
            case .medium: return 6_000
            case .hard:   return 10_000
        }
        
    }
}


struct DifficultySelectionView: View {
    var onFinished: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorText: String?
    
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
                        VStack(spacing: 10) {
                            Text("PS: How coins work")
                                .font(.custom("Press Start 2P", size: 14))
                                .foregroundColor(Color(red: 1.0, green: 0.973, blue: 0.906))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Difficulty.allCases) { level in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.white.opacity(0.7))
                                            .frame(width: 6, height: 6)
                                        Text("\(level.title): \(level.ratioDescription)")
                                            .font(.custom("Press Start 2P", size: 14))
                                            .foregroundColor(Color(red: 1.0, green: 0.973, blue: 0.906))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: 420, alignment: .leading)
                        }
                        .padding(.horizontal, sideGutter)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.89, green: 0.49, blue: 0.30).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, sideGutter)
                        .padding(.top, 90)
                        
                    }
                    .padding(.bottom, 16) // keeps distance from the bottom helper text
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if isSaving {
                        ProgressView().scaleEffect(1.2)
                    }
                }
            }
            // Bottom helper text
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
        guard let uid = Auth.auth().currentUser?.uid else {
            errorText = "No signed-in user."
            return
        }
        isSaving = true
        Task {
            do {
                try await UserManager.shared.setDifficulty(userId: uid, level)
                isSaving = false
                onFinished?()
                dismiss()
            } catch {
                isSaving = false
                errorText = (error as NSError).localizedDescription
            }
        }
    }
}
