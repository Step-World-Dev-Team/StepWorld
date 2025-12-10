//
//  AchievementsViewModel.swift
//  StepWorld
//
//  Created by Isai soria on 11/24/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AchievementsViewModel: ObservableObject {
    
    struct Row: Identifiable {
        let id: String                 // same as achievement.id
        let achievement: DBAchievement
        let definition: AchievementsManager.Definition
    }
    
    @Published var rows: [Row] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    func startListening() {
        guard listener == nil else { return }  // already listening
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not signed in."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let userDoc = Firestore.firestore()
            .collection("Users")
            .document(uid)
        
        let col = userDoc.collection("achievements")
        
        listener = col.addSnapshotListener { [weak self] snap, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            guard let snap = snap else {
                self.errorMessage = "No snapshot received."
                self.isLoading = false
                return
            }
            
            var newRows: [Row] = []
            for doc in snap.documents {
                let data = doc.data()
                let docId = doc.documentID
                
                guard let achId = AchievementId(rawValue: docId),
                      let def = AchievementsManager.shared.definition(for: achId) else {
                    continue
                }
                
                let progress    = data["progress"] as? Int ?? 0
                let target      = data["target"] as? Int ?? def.target
                let isCompleted = data["isCompleted"] as? Bool ?? false
                let isClaimed   = data["isClaimed"] as? Bool ?? false
                
                // Handle Date / Timestamp / String defensively
                func parseDate(_ value: Any?) -> Date? {
                    if let ts = value as? Timestamp {
                        return ts.dateValue()
                    } else if let str = value as? String {
                        // very simple fallback parser; adjust if you have a specific format
                        return ISO8601DateFormatter().date(from: str)
                    } else {
                        return nil
                    }
                }
                
                let createdAt   = parseDate(data["createdAt"]) ?? Date()
                let updatedAt   = parseDate(data["updatedAt"]) ?? createdAt
                let completedAt = parseDate(data["completedAt"])
                let claimedAt   = parseDate(data["claimedAt"])
                
                let model = DBAchievement(
                    id: docId,
                    progress: progress,
                    target: target,
                    isCompleted: isCompleted,
                    isClaimed: isClaimed,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    completedAt: completedAt,
                    claimedAt: claimedAt
                )
                
                newRows.append(
                    Row(id: docId, achievement: model, definition: def)
                )
            }
            
            // Example sort: by category / target
            self.rows = newRows.sorted { $0.definition.target < $1.definition.target }
            self.isLoading = false
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Claim action (used by the row)
    
    func claim(_ row: Row) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Achievements", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        try await AchievementsManager.shared.claimReward(
            userId: uid,
            id: row.definition.id
        )
        // Firestore listener will update `rows` once the claim is written
    }
}
