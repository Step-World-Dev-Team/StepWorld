//
//  SignInEmailViewModel.swift
//  StepWorld
//
//  Created by Isai soria on 10/6/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SignInEmailViewModel: ObservableObject {
    
    @Published var email = ""
    @Published var password = ""
    
    func SignIn() async throws {
        
        // check for empty email or password field
        guard !email.isEmpty, !password.isEmpty else {
            print("No email or password found")
            return
        }
        
        // attempts to sign in user using provided input
        try await AuthenticationManager.shared.signInUser(email: email, password: password)
        print("successfully signed in")
    }
    
    // SignOut function will go here
    // along with any other functions
}
