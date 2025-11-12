//
//  ShopModels.swift
//  StepWorld
//
//  Created by Anali Cardoza on 11/9/25.
//
import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

struct ShopItem: Identifiable {
    let id = UUID()
    let type: String      // matches your asset name: "JackOLantern", "SunFlower"
    let price: Int
    let iconName: String  // typically same as type
}
/*
let defaultShopItems: [ShopItem] = [
    .init(type: "JackOLantern", price: 150, iconName: "JackOLantern"),
    .init(type: "SunFlower",    price: 120, iconName: "SunFlower"),
]*/

struct ShopProduct: Identifiable, Codable {
    let id: String
    let type: String        // "decor"
    let asset_name: String
    let price: Int
    let is_active: Bool
}

final class ShopViewModel: ObservableObject {
    @Published var items: [ShopItem] = []
    @Published var isLoading = false
    @Published var errorText: String?

    /*
    func load() async {
        do {
            print("-*-*-ATTEMPTED TO LOAD FROM FIRESTORE - SHOP")
            let snap = try await Firestore.firestore()
                .collection("ShopCatalog")
                .whereField("is_active", isEqualTo: true)
                .getDocuments()

            let parsed: [ShopItem] = snap.documents.compactMap { doc in
                let d = doc.data()
                guard let type = d["type"] as? String, type == "decor",
                      let asset = d["asset_name"] as? String,
                      let price = (d["price"] as? Int) ?? (d["price"] as? NSNumber)?.intValue
                else { return nil }
                return ShopItem(type: asset, price: price, iconName: asset)
            }
            await MainActor.run { self.items = parsed }
        } catch {
            print("Shop load failed: \(error)")
        }
    }
     */
    func load() async {
            await MainActor.run {
                isLoading = true
                errorText = nil
            }

            do {
                let db = Firestore.firestore()
                let q = db.collection("ShopCatalog")
                          .whereField("is_active", isEqualTo: true)

                let snap = try await q.getDocuments()
                print("🛒 ShopCatalog fetched. count=\(snap.documents.count) fromCache=\(snap.metadata.isFromCache)")

                var parsed: [ShopItem] = []

                for doc in snap.documents {
                    let id = doc.documentID
                    let d = doc.data()

                    guard let typeStr = d["type"] as? String else {
                        print("⛔️ \(id) skipped: missing 'type'")
                        continue
                    }
                    guard typeStr == "decor" else {
                        print("ℹ️ \(id) skipped: type=\(typeStr) (want 'decor')")
                        continue
                    }

                    let asset = (d["asset_name"] as? String) ?? id
                    if d["asset_name"] == nil {
                        print("⚠️ \(id) missing 'asset_name'; using docID '\(id)'")
                    }

                    // accept Int / Double / NSNumber
                    let priceAny = d["price"]
                    let price: Int? = (priceAny as? Int)
                        ?? (priceAny as? Double).map(Int.init)
                        ?? (priceAny as? NSNumber)?.intValue

                    guard let p = price else {
                        print("⛔️ \(id) skipped: unparseable price: \(String(describing: priceAny))")
                        continue
                    }

                    let icon = (d["icon"] as? String) ?? asset
                    parsed.append(ShopItem(type: asset, price: p, iconName: icon))
                    print("✅ catalog item: id=\(id) asset=\(asset) price=\(p)")
                }

                await MainActor.run {
                    self.items = parsed
                    self.isLoading = false
                }
            } catch {
                print("❌ Shop load failed:", error.localizedDescription)
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
}
