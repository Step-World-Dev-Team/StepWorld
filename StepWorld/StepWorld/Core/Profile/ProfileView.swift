//
//  ProfileView.swift
//  StepWorld
//
//  Created by Isai soria on 10/7/25.
//

import Foundation
import SwiftUI
import Combine


@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published private(set) var user: AuthDataResultModel? = nil
    
    func loadCurrentUser() throws {
        self.user = try AuthenticationManager.shared.getAuthenticatedUser()
        }
}


struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    
    // temporary way of displaying user information
    var body: some View {
        List {
            if let user = viewModel.user {
                Text("Userid: \(user.uid)")
            }
            
            // more fields can be added here
            
        }
        .onAppear{
            try? viewModel.loadCurrentUser()
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
