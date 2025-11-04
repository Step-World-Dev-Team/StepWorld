//
//  UserManager.swift
//  StepWorld
//
//  Created by Isai Soria on 10/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseSharedSwift
import CoreGraphics

// MARK: DBUser Model
struct DBUser: Codable {
    let userId: String
    let email: String?
    let photoUrl: String?
    let name: String?
    let balance: Int?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email = "email"
        case photoUrl = "photo_url"
        case name = "name"
        case balance = "balance"
    }
    
}

// MARK: Step Data Model
struct DBDailyMetrics: Codable {
    let dateId: String
    let stepCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case dateId = "date_id"
        case stepCount = "step_count"
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
enum SpendError: Error {
    case insufficientFunds
}

extension UserManager {
    
    private func dailyMetricsCollection(_ userId: String) -> CollectionReference {
        userDocument(userId).collection("daily_metrics")
    }
    
    private func dailyMetricsDocument(_ userId: String, dateId: String) -> DocumentReference {
        dailyMetricsCollection(userId).document(dateId)
    }
    
    // Helper to safely convert Firestore numeric values to Int
    private func asInt(_ any: Any?) -> Int {
        if let n = any as? Int { return n }
        if let n = any as? Int64 { return Int(n) }
        if let n = any as? Double { return Int(n) }
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
    
    // Get user's coin balance
    func getBalance(userId: String) async throws -> Int {
        let snap = try await userDocument(userId).getDocument()
        return asInt(snap.data()?["balance"])
    }
    
    // Credit delta steps and upsert today's daily_metrics (atomic)
    func creditStepsAndSyncDaily(userId: String, date: Date, newStepCount: Int) async throws -> (delta: Int, balance: Int) {
        let fs = Firestore.firestore()
        let dateId = Self.dateId(for: date)
        let userRef = userDocument(userId)
        let dailyRef = dailyMetricsDocument(userId, dateId: dateId)
        
        return try await withCheckedThrowingContinuation { cont in
            fs.runTransaction({ (txn, errorPointer) -> Any? in
                do {
                    // Read User
                    let userSnap = try txn.getDocument(userRef)
                    var balance = self.asInt(userSnap.data()?["balance"])
                    
                    // Read daily metrics (can be zero/not exist)
                    let dailySnap = try? txn.getDocument(dailyRef)
                    let prevSteps: Int
                    // set to zero if doesn't exist
                    if let data = dailySnap?.data(), let storedSteps = data["step_count"] {
                        prevSteps = self.asInt(storedSteps)
                    } else {
                        prevSteps = 0  // explicitly state: no doc = zero previous steps
                    }
                    let delta = max(0, newStepCount - prevSteps)
                    
                    // Update/Insert daily metrics
                    let now = Date()
                    if dailySnap?.exists == true {
                        txn.updateData([
                            "step_count": newStepCount,
                            "updated_at": now
                        ], forDocument: dailyRef)
                    } else {
                        txn.setData([
                            "date_id": dateId,
                            "step_count": newStepCount,
                            "created_at": now,
                            "updated_at": now
                        ], forDocument: dailyRef, merge: true)
                    }
                    
                    // Increment balance by delta
                    if delta > 0 {
                        balance += delta
                        if userSnap.exists {
                            txn.updateData(["balance": balance], forDocument: userRef)
                        } else {
                            txn.setData([
                                "user_id": userId,
                                "balance": balance
                            ], forDocument: userRef, merge: true)
                        }
                    }
                    
                    // Return values to completion block
                    return ["delta": delta, "balance": balance]
                    
                } catch let err as NSError {
                    errorPointer?.pointee = err
                    return nil
                }
            }, completion: { result, error in
                if let error = error { return cont.resume(throwing: error) }
                guard
                    let dict = result as? [String: Int],
                    let delta = dict["delta"],
                    let balance = dict["balance"]
                else {
                    return cont.resume(throwing: NSError(
                        domain: "UserManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Transaction result malformed"]
                    ))
                }
                cont.resume(returning: (delta, balance))
            })
        }
    }
    
    //MARK: Shop/Transaction methods
    // Spend from balance (atomic)
    func spend(userId: String, amount: Int) async throws -> Int {
        let fs = Firestore.firestore()
        let userRef = userDocument(userId)
        
        return try await withCheckedThrowingContinuation { cont in
            fs.runTransaction({ (txn, errorPointer) -> Any? in
                do {
                    let userSnap = try txn.getDocument(userRef)
                    var balance = (userSnap.data()?["balance"] as? Int) ?? 0
                    guard amount >= 0 else { throw SpendError.insufficientFunds }
                    guard balance >= amount else { throw SpendError.insufficientFunds }
                    balance -= amount
                    
                    if userSnap.exists {
                        txn.updateData(["balance": balance], forDocument: userRef)
                    } else {
                        txn.setData(["user_id": userId, "balance": balance], forDocument: userRef, merge: true)
                    }
                    return balance
                } catch let err as NSError {
                    errorPointer?.pointee = err
                    return nil
                }
            }, completion: { result, error in
                if let error = error {
                    if case SpendError.insufficientFunds = error {
                        return cont.resume(throwing: SpendError.insufficientFunds)
                    }
                    return cont.resume(throwing: error)
                }
                guard let newBalance = result as? Int else {
                    return cont.resume(throwing: NSError(
                        domain: "UserManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Transaction result malformed"]
                    ))
                }
                cont.resume(returning: newBalance)
            })
        }
    }
    
    // function to refund to balance
    func refund(userId: String, amount: Int) async throws -> Int {
        let fs = Firestore.firestore()
        let userRef = userDocument(userId)
        
        return try await withCheckedThrowingContinuation { cont in
            fs.runTransaction({ (txn, errorPointer) -> Any? in
                do {
                    let userSnap = try txn.getDocument(userRef)
                    var balance = (userSnap.data()?["balance"] as? Int) ?? 0
                    guard amount >= 0 else {
                        throw NSError(
                            domain: "UserManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Refund amount cannot be negative"]
                        )
                    }
                    
                    balance += amount
                    
                    if userSnap.exists {
                        txn.updateData(["balance": balance], forDocument: userRef)
                    } else {
                        txn.setData(["user_id": userId, "balance": balance], forDocument: userRef, merge: true)
                    }
                    
                    return balance
                } catch let err as NSError {
                    errorPointer?.pointee = err
                    return nil
                }
            }, completion: { result, error in
                if let error = error {
                    return cont.resume(throwing: error)
                }
                guard let newBalance = result as? Int else {
                    return cont.resume(throwing: NSError(
                        domain: "UserManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Transaction result malformed"]
                    ))
                }
                cont.resume(returning: newBalance)
            })
        }
    }
    
    // Fetch today's metrics (no need to pass stepCount or money)
    func getDailyMetrics(userId: String, date: Date) async throws -> DBDailyMetrics? {
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
        
        return try snapshot.documents.map { try $0.data(as: DBDailyMetrics.self) }
    }
    
    private static func dateId(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = .init(identifier: .gregorian)
        fmt.locale = .init(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
    
    func dateId(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
    
}

// MARK: Map Data Functions
private struct UserMapWrapper: Codable {
    let map_buildings: [Building]?
}

extension UserManager {
    /*
     
     
     
     /// Fetch buildings; convert x/y back to CGFloat for your SpriteKit code
     func fetchMapBuildings(userId: String) async throws -> [[String: Any]] {
     let snap = try await userDocument(userId).getDocument()
     guard let raw = snap.data()?["map_buildings"] as? [[String: Any]] else { return [] }
     
     return raw.map { d in
     var out = d
     let xNum = d["x"] as? NSNumber
     let yNum = d["y"] as? NSNumber
     out["x"] = CGFloat(xNum?.doubleValue ?? 0)
     out["y"] = CGFloat(yNum?.doubleValue ?? 0)
     return out
     }
     }
     */
    /*
     func saveMapBuildings(userId: String, buildings: [Building]) async throws {
     try await userDocument(userId).setData([
     "map_buildings": try encoder.encode(buildings),
     "map_updated_at": FieldValue.serverTimestamp()
     ], merge: true)
     }
     
     func fetchMapBuildings(userId: String) async throws -> [Building] {
     let snap = try await userDocument(userId).getDocument()
     guard let arr = snap.data()?["map_buildings"] as? [[String: Any]] else { return [] }
     // decode each item back to Building
     return try arr.map { try decoder.decode(Building.self, from: $0) }
     }
     */
    
    // save array of building data
    func saveMapBuildings(userId: String, buildings: [Building]) async throws {
        let encodedArray: [[String: Any]] = try buildings.map { try encoder.encode($0) }
        try await userDocument(userId).setData([
            "map_buildings": encodedArray,
            "map_updated_at": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    func fetchMapBuildings(userId: String) async throws -> [Building] {
        let snap = try await userDocument(userId).getDocument()
        guard let raw = snap.data()?["map_buildings"] as? [[String: Any]] else { return [] }
        return try raw.map { try decoder.decode(Building.self, from: $0) }
    }
}

// MARK: DBUser Factory Methods
extension DBUser {
    static func fromAuth(_ auth: AuthDataResultModel) -> DBUser {
        DBUser(
            userId: auth.uid,
            email: auth.email,
            photoUrl: auth.photoURL,
            name: auth.name,
            balance: 0
        )
    }
}

// TODO: Refactor encoder and decoder functions
// MARK: Encoder-Decoder Functions
