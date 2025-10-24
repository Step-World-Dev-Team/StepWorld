//
//  UserManager.swift
//  StepWorld
//
//  Created by Isai Soria on 10/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseSharedSwift

// MARK: DBUser Model
struct DBUser: Codable {
    // all variables that are in DBUser
    // more varaiables can be added here,
    // they must be initialized below
    let userId: String
    let email: String?
    let photoUrl: String?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
       case userId = "user_id"
        case email = "email"
        case photoUrl = "photo_url"
        case name = "name"
    }
    
}

// MARK: User Manager
final class UserManager {
    
    static let shared = UserManager()
    private init() {}
    
    // pulls the collection called Users
    // This call can be replicated for whichever collection that is needed
    // "Collection" representing a folder in the DB
    private let userCollection = Firestore.firestore().collection("Users")
    
    // pulls the individual document from the User folder
    private func userDocument(_ userId: String) -> DocumentReference {
        userCollection.document(userId)
    }
    
    private let encoder: Firestore.Encoder = {
        var encoder = Firestore.Encoder()
        return encoder
    }()
    
    private let decoder: Firestore.Decoder = {
        var decoder = Firestore.Decoder()
        return decoder
    }()
    
    func getUser(userId: String) async throws -> DBUser {
        try await userDocument(userId).getDocument(as: DBUser.self)
    }
    
    // more functions to update variables in DB will go here
    
}

// MARK: DBUser Factory Methods
extension DBUser {
    static func fromAuth(_ auth: AuthDataResultModel) -> DBUser {
        DBUser(
            userId: auth.uid,
            email: auth.email,
            photoUrl: auth.photoURL,
            name: auth.name
        )
    }
}
