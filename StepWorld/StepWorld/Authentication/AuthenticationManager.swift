//
//  Authentication Manager.swift
//  StepWorld
//
//  Created by Isai Soria on 10/6/25.
//

import Foundation
import FirebaseAuth

// initiates variables used for authentication
struct AuthDataResultModel {
    let uid: String
    let email: String?
    let photoURL: String?
    let name: String?
    
    init(user: User) {
        self.uid = user.uid
        self.email = user.email
        self.photoURL = user.photoURL?.absoluteString
        self.name = user.displayName
    }
}

final class AuthenticationManager {
    
    // globalizes the AuthenticationManager
    static let shared = AuthenticationManager()
    private init() {}
    
    var currentUser: User? { Auth.auth().currentUser }
    
    // function to get user that is associated with user info
    func getAuthenticatedUser() throws -> AuthDataResultModel {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.badServerResponse)
        }
        
        return AuthDataResultModel(user: user)
    }
}

// MARK: SIGN IN EMAIL
extension AuthenticationManager {
    
    @discardableResult
    func createUser(email: String, password: String) async throws -> AuthDataResultModel {
        
        let authDataResult = try await Auth.auth().createUser(withEmail: email, password: password)
        return AuthDataResultModel(user: authDataResult.user)
    }
    
    @discardableResult
    func signInUser(email: String, password: String) async throws -> AuthDataResultModel {
        let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
        return AuthDataResultModel(user: authDataResult.user)
    }
    
}

// MARK: SIGN OUT EMAIL
extension AuthenticationManager {
    
    func signOutUser() throws {
        try Auth.auth().signOut()
    }
}
