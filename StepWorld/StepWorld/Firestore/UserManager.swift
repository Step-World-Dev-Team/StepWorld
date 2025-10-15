//
//  UserManager.swift
//  StepWorld
//
//  Created by Isai Soria on 10/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseSharedSwift

struct DBUser: Codable {
    // all variables that are in DBUser
    // more varaiables can be added here,
    // they must be initialized below
    let userId: String
    let email: String?
    let photoUrl: String?
    let name: String?
    
    // pulls/matches variables from authentication manager
    init(auth: AuthDataResultModel) {
        self.userId = auth.uid
        self.email = auth.email
        self.photoUrl = auth.photoURL
        self.name = auth.name
    }
    
    // initializing all variables
    init (
        userId: String,
        email: String? = nil ,
        photoUrl: String? = nil,
        name: String? = nil
    ) {
        self.userId = userId
        self.email = email
        self.photoUrl = photoUrl
        self.name = name
    }
    
    // keys that the encoder and decoder can use
    // to know how it should format the data
    // variable on the left and DB value format on right
    enum CodingKeys: String, CodingKey {
       case userId = "user_id"
        case email = "email"
        case photoUrl = "photo_url"
        case name = "name"
    }

    // decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        
    }
    
    // encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(photoUrl, forKey: .photoUrl)
        try container.encodeIfPresent(name, forKey: .name)
    }
    
}


final class UserManager {
    
    static let shared = UserManager()
    private init() {}
    
    // pulls the collection called Users
    // This call can be replicated for whichever collection that is needed
    // "Colleciton" representing a folder in the DB
    private let userCollection = Firestore.firestore().collection("Users")
    
    // pulls the individual document from the User folder
    private func userDocument(_ userId: String) -> DocumentReference {
        userCollection.document(userId)
    }
    
    private let encoder: Firestore.Encoder = {
        var encoder = Firestore.Encoder()
        //encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    private let decoder: Firestore.Decoder = {
        var decoder = Firestore.Decoder()
        //decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    func getUser(userId: String) async throws -> DBUser {
        try await userDocument(userId).getDocument(as: DBUser.self)
    }
    
    // more functions to update variables in DB will go here
    
}
