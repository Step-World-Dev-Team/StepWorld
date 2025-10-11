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
    
    // temporary way of displaying user information
    var body: some View {
        List {
            if let user = viewModel.user {
                
                Text("UserId: \(user.userId)")
                
                // will not display anything since there is no email value currently in DB
                if let email = user.email {
                    Text("Email: \(email.description.capitalized)")
                }
                
                if let name = user.name {
                    Text("Name: \(name.capitalized)")
                }
                 
            }
            
            // more fields can be added here
            
        }
        .task{
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "gear")
                    .font(.headline)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
