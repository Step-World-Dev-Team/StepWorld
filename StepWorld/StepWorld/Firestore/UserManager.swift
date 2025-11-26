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
    let disasterApplied: Bool?
    
    enum CodingKeys: String, CodingKey {
        case dateId = "date_id"
        case stepCount = "step_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case disasterApplied = "disaster_applied"
    }
}

// MARK: Decore Data Model
struct DBPurchase: Codable {
    let purchaseId: String
    let userId: String
    let productId: String          // e.g., "JackOLantern"
    let type: String               // "decor"
    let quantity: Int
    let pricePaid: Int
    let createdAt: Date
    let status: String
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
    func creditStepsAndSyncDaily(userId: String, date: Date, newStepCount: Int) async throws -> (delta: Int, balance: Int, totalSteps: Int) {
        let fs = Firestore.firestore()
        let dateId = Self.dateId(for: date)
        let userRef = userDocument(userId)
        let dailyRef = dailyMetricsDocument(userId, dateId: dateId)
        
        return try await withCheckedThrowingContinuation { cont in
                fs.runTransaction({ (txn, errorPointer) -> Any? in
                    do {
                        // --- Read user & current balance
                        let userSnap = try txn.getDocument(userRef)
                        var balance = self.asInt(userSnap.data()?["balance"])
                        var totalSteps = self.asInt(userSnap.data()?["total_steps"])

                        // --- Read today's metrics (may not exist)
                        let dailySnap = try? txn.getDocument(dailyRef)
                        let dailyData = dailySnap?.data() ?? [:]

                        let prevSteps = self.asInt(dailyData["step_count"])
                        let creditedInitial = (dailyData["credited_initial"] as? Bool) ?? false
                        let now = Date()

                        // --- Always write the latest step_count (upsert)
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
                                "updated_at": now,
                                // we may set credited_initial below in the same transaction
                            ], forDocument: dailyRef, merge: true)
                        }

                        // --- Compute delta normally
                        let baseDelta = max(0, newStepCount - prevSteps)
                        var deltaToCredit = baseDelta

                        //     non-zero steps today AND initial wasn’t credited yet, credit once now.
                        if deltaToCredit == 0, newStepCount > 0, creditedInitial == false {
                            deltaToCredit = newStepCount
                            // Mark the flag so we never double-credit
                            txn.setData(["credited_initial": true], forDocument: dailyRef, merge: true)
                        } else if creditedInitial == false, newStepCount == 0 {
                            // Keep it false and let later increments credit via baseDelta
                        } else if creditedInitial == false, baseDelta > 0 {
                            txn.setData(["credited_initial": true], forDocument: dailyRef, merge: true)
                        }

                        // --- Apply balance change
                        if deltaToCredit > 0 {
                                            balance    += deltaToCredit
                                            totalSteps += deltaToCredit
                                            
                                            if userSnap.exists {
                                                txn.updateData([
                                                    "balance": balance,
                                                    "total_steps": totalSteps
                                                ], forDocument: userRef)
                                            } else {
                                                txn.setData([
                                                    "user_id": userId,
                                                    "balance": balance,
                                                    "total_steps": totalSteps
                                                ], forDocument: userRef, merge: true)
                                            }
                                        }
                                        
                                        return ["delta": deltaToCredit, "balance": balance, "total_steps": totalSteps]
                    } catch let err as NSError {
                        errorPointer?.pointee = err
                        return nil
                    }
                }, completion: { result, error in
                if let error = error { return cont.resume(throwing: error) }
                guard
                    let dict = result as? [String: Int],
                    let delta = dict["delta"],
                    let balance = dict["balance"],
                    let total = dict["total_steps"]
                else {
                    return cont.resume(throwing: NSError(
                        domain: "UserManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Transaction result malformed"]
                    ))
                }
                cont.resume(returning: (delta, balance, total))
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
    
    static func dateId(for date: Date) -> String {
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

// MARK: Decore Data
final class ShopRepository {
    static let shared = ShopRepository()
    private init() {}
    
    private let db = Firestore.firestore()
    private var catalog: CollectionReference { db.collection("ShopCatalog") }
    
    // Fetch a product (price & type) to trust server-side values
    func getProduct(_ productId: String) async throws -> (type: String, price: Int) {
        let doc = try await catalog.document(productId).getDocument()
        guard let data = doc.data(),
              let isActive = data["is_active"] as? Bool, isActive,
              let type = data["type"] as? String,
              let price = (data["price"] as? Int) ?? (data["price"] as? NSNumber)?.intValue
        else { throw NSError(domain: "Shop", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found or inactive"]) }
        return (type, price)
    }
}

extension UserManager {
    private func decorFieldKey() -> String { "decor_items" }
    
    func saveDecor(userId: String, items: [DecorItem]) async throws {
        // Firestore.Encoder handles nested maps fine (CGPoint encodes as {x,y})
        let encoded: [[String: Any]] = try items.map { try encoder.encode($0) }
        try await userDocument(userId).setData([
            decorFieldKey(): encoded,
            "decor_updated_at": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    func fetchDecor(userId: String) async throws -> [DecorItem] {
        let snap = try await userDocument(userId).getDocument()
        guard let raw = snap.data()?[decorFieldKey()] as? [[String: Any]] else { return [] }
        return try raw.map { try decoder.decode(DecorItem.self, from: $0) }
    }
    
    func purchaseProduct(userId: String, productId: String, quantity: Int = 1) async throws -> (newBalance: Int, purchaseId: String) {
        let db = Firestore.firestore()
        let userRef = userDocument(userId)
        let purchasesRef = userRef.collection("purchases")
        let invRef = userRef.collection("inventory").document(productId)
        let product = try await ShopRepository.shared.getProduct(productId)
        
        return try await withCheckedThrowingContinuation { cont in
            db.runTransaction({ (txn, errPtr) -> Any? in
                do {
                    // 1) Read user balance
                    let userSnap = try txn.getDocument(userRef)
                    var balance = (userSnap.data()?["balance"] as? Int) ?? 0
                    
                    // 2) Compute total cost
                    let total = product.price * max(1, quantity)
                    guard total >= 0, balance >= total else {
                        throw SpendError.insufficientFunds
                    }
                    
                    // 3) Deduct & write new balance
                    balance -= total
                    if userSnap.exists {
                        txn.updateData(["balance": balance], forDocument: userRef)
                    } else {
                        txn.setData(["user_id": userId, "balance": balance], forDocument: userRef, merge: true)
                    }
                    
                    // 4) Record purchase
                    let purchaseId = purchasesRef.document().documentID
                    let purchase: [String: Any] = [
                        "purchaseId": purchaseId,
                        "userId": userId,
                        "productId": productId,
                        "type": product.type,
                        "quantity": quantity,
                        "pricePaid": product.price,
                        "createdAt": FieldValue.serverTimestamp(),
                        "status": "completed"
                    ]
                    txn.setData(purchase, forDocument: purchasesRef.document(purchaseId))
                    
                    // 5) Increment inventory count
                    txn.setData(["quantity": FieldValue.increment(Int64(quantity))],
                                forDocument: invRef, merge: true)
                    
                    return ["balance": balance, "purchaseId": purchaseId]
                } catch let e as NSError {
                    errPtr?.pointee = e
                    return nil
                }
            }, completion: { result, error in
                if let error = error {
                    if case SpendError.insufficientFunds = error { return cont.resume(throwing: SpendError.insufficientFunds) }
                    return cont.resume(throwing: error)
                }
                guard let dict = result as? [String: Any],
                      let bal = dict["balance"] as? Int,
                      let pid = dict["purchaseId"] as? String else {
                    return cont.resume(throwing: NSError(domain: "Shop", code: -3, userInfo: [NSLocalizedDescriptionKey: "Bad transaction result"]))
                }
                cont.resume(returning: (bal, pid))
            })
        }
    }
}

// MARK: Skins Persistence
extension UserManager {
    struct SkinState: Codable {
            let owned: [String]            // e.g. ["Barn#Blue", "House#Candy"]
            let equipped: [String:String]  // baseType -> skin name (e.g. ["Barn":"Blue"])
        }

        func saveSkinState(userId: String, owned: Set<String>, equipped: [String:String]) async throws {
            try await userDocument(userId).setData([
                "owned_skins": Array(owned),
                "equipped_skins": equipped,
                "skins_updated_at": FieldValue.serverTimestamp()
            ], merge: true)
        }

        func fetchSkinState(userId: String) async throws -> SkinState {
            let snap = try await userDocument(userId).getDocument()
            let owned = (snap.data()?["owned_skins"] as? [String]) ?? []
            let equipped = (snap.data()?["equipped_skins"] as? [String:String]) ?? [:]
            return .init(owned: owned, equipped: equipped)
        }
}


// MARK: Helper Functions
extension UserManager {
    func ensureUserExists(for auth: AuthDataResultModel) async throws {
        do {
            _ = try await getUser(userId: auth.uid)
        } catch {
            let newUser = DBUser.fromAuth(auth)
            try await Firestore.firestore().collection("Users")
                .document(auth.uid)
                .setData([
                    "user_id": newUser.userId,
                    "email": newUser.email ?? "",
                    "photo_url": newUser.photoUrl ?? "",
                    "name": newUser.name ?? "",
                    "balance": newUser.balance ?? 0
                ], merge: true)
        }
    }
}

// MARK: Disaster Helpers
extension UserManager {
    func setDisasterApplied(userId: String, date: Date, applied: Bool) async throws {
        let dateId = Self.dateId(for: date)
        try await dailyMetricsDocument(userId, dateId: dateId).setData([
            "date_id": dateId,
            "disaster_applied": applied,
            "updated_at": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

// TODO: Refactor encoder and decoder functions
// MARK: Encoder-Decoder Functions
