//
//  StatsDisplay.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 10/9/25.
//

import SwiftUI
import Combine

@MainActor
final class StatsDisplayViewModel: ObservableObject {
    
    @Published private(set) var user: DBUser? = nil
    @Published private(set) var balance: Int? = nil
    @Published private(set) var todaySteps: Int? = nil
    
    // attempts to pull user data from authentication & user managers
    func loadCurrentUser() async throws {
        do {
            let authDataResult = try AuthenticationManager.shared.getAuthenticatedUser()
            self.user = try await UserManager.shared.getUser(userId: authDataResult.uid)
            
            let coins = try await UserManager.shared.getBalance(userId: authDataResult.uid)
            self.balance = coins
            
            if let metrics = try await UserManager.shared.getDailyMetrics(userId: authDataResult.uid, date: Date()) {
                self.todaySteps = metrics.stepCount
            } else {
                self.todaySteps = 0
            }
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
}

struct StatsDisplay: View {
    @EnvironmentObject var steps: StepManager
    @Environment(\.dismiss) private var dismiss  // for closing the view
    @StateObject private var viewModel = StatsDisplayViewModel()
    
    var body: some View {
            //might have to correct the alignment...
        ZStack {
            Image("Empty_Plank2")
                .resizable()
                .frame(width: 140, height: 100)
            
            HStack {
                VStack {
                    VStack {
                        HStack {
                            Image("Boot")
                                .resizable()
                                .interpolation(.none)   // keeps pixel art sharp
                                .frame(width: 25, height: 25) // smaller size
                            
                            Text(viewModel.todaySteps?.formattedString() ?? "--")
                                .font(.custom("Press Start 2P", size: 13))
                        }
                        HStack {
                            Image("Coin")
                                .interpolation(.none)
                                .padding(.leading, 5)
                            
                            Text(viewModel.balance?.formattedString() ?? "--")
                                .font(.custom("Press Start 2P", size: 13))
                                .padding(.leading, 6)
                        }
                    }
                    .padding()
                    .padding(.bottom,6)
                }
            }
            .task {
                try? await viewModel.loadCurrentUser()
            }
        }

    }
}

#Preview {
    StatsDisplay()
        .environmentObject(StepManager())

}

extension Int {
    func formattedString() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
