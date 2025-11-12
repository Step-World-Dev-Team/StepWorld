//
//  SignInEmailViewModel.swift
//  StepWorld
//
//  Created by Isai Soria on 10/6/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

enum AuthMode {
    case signIn
    case signUp
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var mode: AuthMode = .signIn
    @Published var errorText: String? = nil
    
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    
    func performPrimaryAction() async throws -> AuthDataResultModel {
        switch mode {
        case .signIn:
            return try await signIn()
        case .signUp:
            return try await signUp()
        }
    }
    
    private func signUp() async throws -> AuthDataResultModel {
            guard !email.isEmpty, !password.isEmpty else {
                throw NSError(domain: "SignUp", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Email or password missing"])
            }
        
            guard password.count >= 6 else {
                throw NSError(domain: "SignUp", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Password must be at least 6 characters"])
            }

            var auth = try await AuthenticationManager.shared.createUser(email: email, password: password)

            // optionally set display name
            if !displayName.trimmingCharacters(in: .whitespaces).isEmpty,
               let user = AuthenticationManager.shared.currentUser {
                let changeReq = user.createProfileChangeRequest()
                changeReq.displayName = displayName
                try await changeReq.commitChanges()
                auth = try AuthenticationManager.shared.getAuthenticatedUser()
            }

            // Create Users/{uid} if missing
            try await UserManager.shared.ensureUserExists(for: auth)
            return auth
        }
    
    func signIn() async throws -> AuthDataResultModel{
        
        // check for empty email or password field
        guard !email.isEmpty, !password.isEmpty else {
            throw NSError(domain: "SignIn", code: 0, userInfo: [NSLocalizedDescriptionKey: "Email or password missing"])
        }
        
        // attempts to sign in user using provided input
        let auth = try await AuthenticationManager.shared.signInUser(email: email, password: password)
        
        print("successfully signed in")
        return auth
    }
    
    func signOut() throws {
        try AuthenticationManager.shared.signOutUser()
    }
}
