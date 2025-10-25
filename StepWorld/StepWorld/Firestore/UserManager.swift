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

// MARK: Step Data Model
struct DBDailyMetrics: Codable {
    let dateId: String
    let stepCount: Int
    let money: Double
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case dateId = "date_id"
        case stepCount = "step_count"
        case money = "money"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}


// MARK: User Manager
final class UserManager {
    
    static let shared = UserManager()
    private init() {}
    
    // pulls the collection called Users
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
    
}


// MARK: Step Data Functions
extension UserManager {
    
    private func dailyMetricsCollection(_ userId: String) -> CollectionReference {
        userDocument(userId).collection("daily_metrics")
    }
    
    private func dailyMetricsDocument(_ userId: String, dateId: String) -> DocumentReference {
        dailyMetricsCollection(userId).document(dateId)
    }
    
    // update/insert daily metrics to database
    func upsertDailyMetrics(userId: String, date: Date, stepCount: Int, money: Double) throws {
        let dateId = UserManager.dateId(for: date)
        let today = Date()
        let payload = DBDailyMetrics(
            dateId: dateId,
            stepCount: stepCount,
            money: money,
            createdAt: today,
            updatedAt: today
        )
        try dailyMetricsDocument(userId, dateId: dateId)
            .setData(from: payload, merge: true)
    }
    
    // Fetches today's metics
    // use to get the metrics for the day (today's steps)
    func getDailyMetrics(userId: String, date: Date, stepCount: Int, money: Double) async throws -> DBDailyMetrics? {
        let dateId = UserManager.dateId(for: date)
        do {
            return try await dailyMetricsDocument(userId, dateId: dateId)
                .getDocument(as: DBDailyMetrics.self)
        } catch {
            return nil
        }
    }
    
    // Fetch a range of daily metrics
    func listDailyMetrics(userId: String, startDate: Date, endDate: Date) async throws -> [DBDailyMetrics] {
        let startId = Self.dateId(for: startDate)
        let endId   = Self.dateId(for: endDate)
        let snapshot = try await dailyMetricsCollection(userId)
            .whereField("date_id", isGreaterThanOrEqualTo: startId)
            .whereField("date_id", isLessThanOrEqualTo: endId)
            .order(by: "date_id")
            .getDocuments()
        
        return try snapshot.documents.map {try $0.data(as: DBDailyMetrics.self)}
    }
    
    private static func dateId(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
    
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

// MARK: Encoder-Decoder Functions
