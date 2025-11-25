//
//  AchievementManager.swift
//  StepWorld
//
//  Created by Isai soria on 11/24/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: Achievement IDs
enum AchievementId: String, CaseIterable, Codable {
    // Lifetime (total) steps
    case lifetime10k   = "lifetime_10k"
    case lifetime30k   = "lifetime_30k"
    case lifetime50k   = "lifetime_50k"
    
    // One-time events
    case firstBuilding = "first_building"
    case firstDecor    = "first_decor"
    case firstSkin     = "first_skin"
    
    // “Best day” – steps in a single day
    case day5k         = "day_5k"
    case day7_5k       = "day_7_5k"
    case day10k        = "day_10k"
    case day12k        = "day_12k"
}

// MARK: Firestore model
struct DBAchievement: Codable {
    let id: String
    
    var progress: Int
    var target: Int
    
    var isCompleted: Bool
    var isClaimed: Bool
    
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var claimedAt: Date?
}

final class AchievementsManager {
    static let shared = AchievementsManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // Definition: targets + rewards
    struct Definition {
        let id: AchievementId
        let title: String
        let target: Int
        let rewardCoins: Int
    }
    
    // Definitions of acheivements
    private let definitions: [AchievementId: Definition] = [
        .lifetime10k: .init(id: .lifetime10k, title: "Walk 10,000 steps total", target: 10_000, rewardCoins: 1000),
        .lifetime30k: .init(id: .lifetime30k, title: "Walk 30,000 steps total", target: 30_000, rewardCoins: 2000),
        .lifetime50k: .init(id: .lifetime50k, title: "Walk 50,000 steps total", target: 50_000, rewardCoins: 3000),
        
        .firstBuilding: .init(id: .firstBuilding, title: "Build your first building", target: 1, rewardCoins: 100),
        .firstDecor:    .init(id: .firstDecor,    title: "Place your first decor",    target: 1, rewardCoins: 75),
        .firstSkin:     .init(id: .firstSkin,     title: "Buy your first skin",       target: 1, rewardCoins: 75),
        
        .day5k:   .init(id: .day5k,   title: "Reach 5,000 steps in a day",  target: 5_000,  rewardCoins: 1000),
        .day7_5k: .init(id: .day7_5k, title: "Reach 7,500 steps in a day",  target: 7_500,  rewardCoins: 2000),
        .day10k:  .init(id: .day10k,  title: "Reach 10,000 steps in a day", target: 10_000, rewardCoins: 3000),
        .day12k:  .init(id: .day12k,  title: "Reach 12,000 steps in a day", target: 12_000, rewardCoins: 4000)
    ]
    
    // MARK: - Firestore helpers
    private func userDoc(_ userId: String) -> DocumentReference {
        db.collection("Users").document(userId)
    }
    
    private func achievementsCollection(_ userId: String) -> CollectionReference {
        userDoc(userId).collection("achievements")
    }
    
    private func achievementDoc(_ userId: String, _ id: AchievementId) -> DocumentReference {
        achievementsCollection(userId).document(id.rawValue)
    }
    
    // MARK: - Public APIs the rest of the app calls
    // Called whenever you sync steps for today.
    func handleStepsUpdate(
        userId: String,
        todaySteps: Int,
        lifetimeSteps: Int,
        date: Date
    ) async {
        // Lifetime thresholds
        await updateProgress(userId: userId, achievement: .lifetime10k, newProgress: lifetimeSteps)
        await updateProgress(userId: userId, achievement: .lifetime30k, newProgress: lifetimeSteps)
        await updateProgress(userId: userId, achievement: .lifetime50k, newProgress: lifetimeSteps)
        
        // “Best day ever” thresholds (we just care that there exists SOME day
        // where steps >= target; we store the max day steps as progress)
        await updateProgress(userId: userId, achievement: .day5k,   newProgress: todaySteps)
        await updateProgress(userId: userId, achievement: .day7_5k, newProgress: todaySteps)
        await updateProgress(userId: userId, achievement: .day10k,  newProgress: todaySteps)
        await updateProgress(userId: userId, achievement: .day12k,  newProgress: todaySteps)
    }
    
    /// Call after first building is created.
    func registerFirstBuildingIfNeeded(userId: String) async {
        print("ATTEMPTED TO CALL EVENT - FIRST BUILDING")
        await markEventAchievementIfNeeded(userId: userId, id: .firstBuilding)
    }
    
    /// Call after first decor is placed (or first decor purchase).
    func registerFirstDecorIfNeeded(userId: String) async {
        print("ATTEMPTED TO CALL EVENT - FIRST DECOR")
        await markEventAchievementIfNeeded(userId: userId, id: .firstDecor)
    }
    
    /// Call after first skin is successfully purchased.
    func registerFirstSkinIfNeeded(userId: String) async {
        print("ATTEMPTED TO CALL EVENT - FIRST SKIN")
        await markEventAchievementIfNeeded(userId: userId, id: .firstSkin)
    }
    
    // MARK: - Reward claim
    
    enum ClaimError: Error {
        case unknownAchievement
        case notCompleted
        case alreadyClaimed
    }
    
    /// Called from your AchievementsView button to claim reward coins.
    /// Returns new balance after claim.
    func claimReward(userId: String, id: AchievementId) async throws -> Int {
        guard let def = definitions[id] else { throw ClaimError.unknownAchievement }
        
        let userRef = userDoc(userId)
        let achRef  = achievementDoc(userId, id)
        let reward  = def.rewardCoins
        
        return try await withCheckedThrowingContinuation { cont in
            db.runTransaction({ txn, errPtr in
                do {
                    let achSnap = try txn.getDocument(achRef)
                    guard var data = achSnap.data() else {
                        throw ClaimError.notCompleted
                    }
                    
                    let isCompleted = data["isCompleted"] as? Bool ?? false
                    let isClaimed   = data["isClaimed"] as? Bool ?? false
                    
                    guard isCompleted else { throw ClaimError.notCompleted }
                    guard !isClaimed else { throw ClaimError.alreadyClaimed }
                    
                    // Update user balance
                    let userSnap = try txn.getDocument(userRef)
                    var balance = (userSnap.data()?["balance"] as? Int) ?? 0
                    balance += reward
                    
                    txn.setData(["balance": balance], forDocument: userRef, merge: true)
                    
                    // Mark claimed
                    txn.setData([
                        "isClaimed": true,
                        "claimedAt": FieldValue.serverTimestamp()
                    ], forDocument: achRef, merge: true)
                    
                    return balance
                } catch let e as NSError {
                    errPtr?.pointee = e
                    return nil
                }
            }, completion: { result, error in
                if let error = error {
                    return cont.resume(throwing: error)
                }
                guard let newBalance = result as? Int else {
                    return cont.resume(throwing: ClaimError.notCompleted)
                }
                
                NotificationCenter.default.post(
                    name: .achievementRewardClaimed,
                    object: nil,
                    userInfo: [
                        "id": id.rawValue,
                        "reward": reward,
                        "newBalance": newBalance
                    ]
                )
                
                cont.resume(returning: newBalance)
            })
        }
    }
    
    // MARK: - Internal helpers
    /// For numeric achievements (steps).
    private func updateProgress(
        userId: String,
        achievement: AchievementId,
        newProgress: Int
    ) async {
        guard let def = definitions[achievement] else { return }
        
        // Don’t bother writing if progress is zero.
        guard newProgress > 0 else { return }
        
        let ref = achievementDoc(userId, achievement)
        
        do {
            let snap = try await ref.getDocument()
            let now  = Date()
            var unlockedNow = false
            
            if snap.exists {
                // Document exists → decode it
                var existing = try snap.data(as: DBAchievement.self)
                let oldCompleted = existing.isCompleted
                
                existing.progress = max(existing.progress, newProgress)
                existing.updatedAt = now
                
                if !existing.isCompleted && existing.progress >= existing.target {
                    existing.isCompleted = true
                    existing.completedAt = now
                    unlockedNow = true
                }
                
                try ref.setData(from: existing, merge: true)
                
                if !oldCompleted && unlockedNow {
                    postUnlocked(id: achievement)
                }
                
            } else {
                // Document does NOT exist → create it fresh
                let ach = DBAchievement(
                    id: achievement.rawValue,
                    progress: min(newProgress, def.target),
                    target: def.target,
                    isCompleted: newProgress >= def.target,
                    isClaimed: false,
                    createdAt: now,
                    updatedAt: now,
                    completedAt: newProgress >= def.target ? now : nil,
                    claimedAt: nil
                )
                
                try ref.setData(from: ach, merge: true)
                
                if ach.isCompleted {
                    postUnlocked(id: achievement)
                }
            }
        } catch {
            print("⚠️ Failed to update achievement \(achievement.rawValue): \(error)")
        }
    }
    
    /// For “first X” event achievements (target = 1).
    private func markEventAchievementIfNeeded(userId: String, id: AchievementId) async {
        print("🏅 markEventAchievementIfNeeded CALLED for \(id.rawValue), user: \(userId)")
        guard let def = definitions[id] else { return }
        let ref = achievementDoc(userId, id)
        
        do {
            let snap = try await ref.getDocument()
            if snap.exists {
                // Already at least created; don’t overwrite (could already be completed)
                return
            }
            
            let now = Date()
            let ach = DBAchievement(
                id: id.rawValue,
                progress: 1,
                target: def.target,
                isCompleted: true,
                isClaimed: false,
                createdAt: now,
                updatedAt: now,
                completedAt: now,
                claimedAt: nil
            )
            try ref.setData(from: ach, merge: true)
            print("✅ Successfully wrote achievement \(id.rawValue) to Firestore")
            postUnlocked(id: id)
        } catch {
            print("⚠️ Failed to mark event achievement \(id.rawValue): \(error)")
        }
    }
    
    private func postUnlocked(id: AchievementId) {
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: nil,
            userInfo: ["id": id.rawValue]
        )
    }
}
