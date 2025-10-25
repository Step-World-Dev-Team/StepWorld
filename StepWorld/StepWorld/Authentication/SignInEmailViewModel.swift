//
//  SignInEmailViewModel.swift
//  StepWorld
//
//  Created by Isai Soria on 10/6/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SignInEmailViewModel: ObservableObject {
    
    @Published var email = ""
    @Published var password = ""
    
    func signIn() async throws -> AuthDataResultModel{
        
        // check for empty email or password field
        guard !email.isEmpty, !password.isEmpty else {
            throw NSError(domain: "SignIn", code: 0, userInfo: [NSLocalizedDescriptionKey: "Email or password missing"])
        }
        
        // attempts to sign in user using provided input
        let auth = try await AuthenticationManager.shared.signInUser(email: email, password: password)
        
        print("successfully signed in")
        
        // connect authenticated user to step manager
        //let stepManager = StepManager()
        //stepManager.userId = auth.uid
        
        // update step count on FireStore
        //stepManager.syncToday()
        return auth
        
    }
    
    // SignOut function will go here
    // along with any other functions
}
