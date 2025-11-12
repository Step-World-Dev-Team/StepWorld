//
//  ShopPanelViewModel.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 11/12/25.
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class ShopPanelViewModel: ObservableObject {
    @Published private(set) var balance: Int? = nil

    func loadBalance() async {
        do {
            let auth = try AuthenticationManager.shared.getAuthenticatedUser()
            let coins = try await UserManager.shared.getBalance(userId: auth.uid)
            self.balance = coins
        } catch {
            print("❌ Failed to load shop balance:", error)
            self.balance = nil
        }
    }
}


