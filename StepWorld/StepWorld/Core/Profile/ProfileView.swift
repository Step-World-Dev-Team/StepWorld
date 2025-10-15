//
//  ProfileView.swift
//  StepWorld
//
//  Created by Isai Soria on 10/7/25.
//

import Foundation
import SwiftUI
import Combine


@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published private(set) var user: DBUser? = nil
    
    // attempts to pull user data from authentication & user managers
    func loadCurrentUser() async throws {
        let authDataResult = try AuthenticationManager.shared.getAuthenticatedUser()
        self.user = try await UserManager.shared.getUser(userId: authDataResult.uid)
    }
}


struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    
    // creates inset of screen for borders to show
    private let border: CGFloat = 6
    private let cornerSafeMargin: CGFloat = 2
    
    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.93, blue: 0.88)
                .ignoresSafeArea()
            
            Image("page_background")
                .resizable(
                    capInsets: EdgeInsets(top: border, leading: border, bottom: border, trailing: border),
                    resizingMode: .stretch
                )
                .interpolation(.none)
                .antialiased(false)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            
            // temporary way of displaying user information
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let user = viewModel.user {
                        
                        Text("UserId: \(user.userId)")
                            .font(.custom("Press Start 2P", size: 14))
                        
                        // will not display anything since there is no email value currently in DB
                        if let email = user.email {
                            Text("Email: \(email.description.capitalized)")
                                .font(.custom("Press Start 2P", size: 14))
                        }
                        
                        if let name = user.name {
                            Text("Name: \(name.capitalized)")
                                .font(.custom("Press Start 2P", size: 14))
                        }
                        
                    }
                }
                .padding(16)
            }
            
        }
        .task{
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
