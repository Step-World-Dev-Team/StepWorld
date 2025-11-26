//
//  SettingsView.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    var onClose: (() -> Void)? = nil
    var onSignOut: (() -> Void)? = nil
    
    @State private var showDifficultySettings = false
    @State private var loadingDifficulty = false
    @State private var currentDifficulty: Difficulty?
    @State private var errorText: String?
    
    @Environment(\.dismiss) private var dismiss  // for closing the view
    @AppStorage("remember_me") private var rememberMe: Bool = true
    
    
    
    var body: some View {
        ZStack {
            
            Image("ProfileViewBackground")
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: 350, height: 700) // set desired size
                .scaledToFit()
                .padding()
                .padding(.bottom, 50)
            
            VStack {
                
                HStack {
                    Spacer()
                    
                    Button {
                        onClose?()  // closes the view and goes back
                    } label: {
                        Image("close_button")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .padding(.trailing, 10)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("SETTINGS")
                    .font(.custom("Press Start 2P", size: 25))
                    .foregroundColor(.black)
                    .padding(.top, 10)
                
                // --- Current difficulty status
                Group {
                    if loadingDifficulty {
                        ProgressView()
                            .padding(.top, 8)
                    } else if let diff = currentDifficulty {
                        Text("Current Difficulty: \(diff.title)")
                            .font(.custom("Press Start 2P", size: 11))
                            .padding(.top, 8)
                        Text(diff.ratioDescription)
                            .font(.custom("Press Start 2P", size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Difficulty not set")
                            .font(.custom("Press Start 2P", size: 13))
                            .padding(.top, 8)
                            .foregroundColor(.orange)
                    }
                    
                    if let err = errorText {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 4)
                
                Button {
                    showDifficultySettings = true
                } label: {
                    Text("CHANGE DIFFICULTY")
                        .font(.custom("Press Start 2P", size: 15))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .background(Image("clear_button")
                    .resizable()
                    .frame(width: 280, height: 60)
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
                
                Button(role: .destructive) {
                    onSignOut?()
                } label: {
                    Text("SIGN OUT")
                        .font(.custom("Press Start 2P", size: 15))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .background(Image("cancel_button")
                    .resizable()
                    .frame(width: 280, height: 60)
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
                
                Spacer()
                
            }
        }
        .sheet(isPresented: $showDifficultySettings, onDismiss: { refreshDifficulty() }) {
            // DifficultySelectionView now writes to Firestore and dismisses itself.
            // We refresh the label onDismiss above.
            NavigationStack {
                DifficultySelectionView(onFinished: {
                    // After a successful save, also refresh immediately.
                    refreshDifficulty()
                })
            }
        }
        .onAppear { refreshDifficulty() }
    }
    private func refreshDifficulty() {
        guard let uid = Auth.auth().currentUser?.uid else {
            currentDifficulty = nil
            return
        }
        loadingDifficulty = true
        errorText = nil
        Task {
            do {
                let diff = try await UserManager.shared.getDifficulty(userId: uid)
                await MainActor.run {
                    self.currentDifficulty = diff
                    self.loadingDifficulty = false
                }
            } catch {
                await MainActor.run {
                    self.currentDifficulty = nil
                    self.loadingDifficulty = false
                    self.errorText = (error as NSError).localizedDescription
                }
            }
        }
    }
}
#Preview {
    SettingsView()
}
