//
//  ProfileView.swift
//  StepWorld
//
//  Created by Isai Soria on 10/7/25.
//

import Foundation
import SwiftUI
import Combine

// TODO: refactor into its own file
@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published private(set) var user: DBUser? = nil
    @Published private(set) var balance: Int? = nil
    @Published private(set) var todaySteps: Int? = nil
    
    // attempts to pull user data from authentication & user managers
    func loadCurrentUser() async throws {
        do {
            let authDataResult = try AuthenticationManager.shared.getAuthenticatedUser()
            self.user = try await UserManager.shared.getUser(userId: authDataResult.uid)
            
            let coins = try await UserManager.shared.getBalance(userId: authDataResult.uid)
            self.balance = coins
            
            if let metrics = try await UserManager.shared.getDailyMetrics(userId: authDataResult.uid, date: Date()) {
                self.todaySteps = metrics.stepCount
            } else {
                self.todaySteps = 0
            }
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
}


struct ProfileView: View {
    
    var onClose: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss  // for closing the view
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var steps: StepManager
    
    // creates inset of screen for borders to show
    private let border: CGFloat = 20
    private let cornerSafeMargin: CGFloat = 2
    
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
                
                Text("PROFILE")
                    .font(.custom("Press Start 2P", size: 25))
                    .foregroundColor(.black)
                    .padding(.top, 10)
                
                if let user = viewModel.user {
                    StatWidget(backgroundImageName: "NameWidget",
                               title: "Name:",
                               value: (user.name?.isEmpty == false ? user.name! : "Player"))
                        .padding(.top, 30)
                }
                
                StatWidget(backgroundImageName: "StepWidget",
                           title: "Steps:",
                           value: (viewModel.todaySteps?.formattedString() ?? "--"))
                    .padding(.top, 5)
                    .padding(.bottom, 5)
                
                StatWidget(
                    backgroundImageName: "CoinsWidget",
                           title: "Coins:",
                           value: (viewModel.balance?.formattedString() ?? "--")
                )
                    .padding(.bottom, 5)
                
                StatWidget(backgroundImageName: "AchievementWidget",
                           title: "Achievements",
                           value: nil)
                
                Spacer()
            }
            
            
        }
        .navigationBarBackButtonHidden(true)
        .task{
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(StepManager())
    }
}
