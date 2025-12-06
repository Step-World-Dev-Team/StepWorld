//
//  StatsDisplay.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 10/9/25.
//

import SwiftUI
import Combine
import FirebaseFirestore

final class StatsDisplayViewModel: ObservableObject {
    @Published private(set) var balance: Int = 0
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var isLoaded = false
    
    private var userListener: ListenerRegistration?
    private var dailyListener: ListenerRegistration?
    
    deinit {
        stop()
    }
    
    func start() async {
        // Get current user id however you already do it elsewhere
        let auth = try? AuthenticationManager.shared.getAuthenticatedUser()
        guard let uid = auth?.uid else { return }
        
        // Initial fetch (so the HUD isn't empty before listeners fire)
        await initialFetch(userId: uid)
        
        // Live updates for balance (user doc)
        let userRef = Firestore.firestore()
            .collection("Users")
            .document(uid)
        
        userListener = userRef.addSnapshotListener { [weak self] snap, _ in
            guard let self, let data = snap?.data() else { return }
            // Be defensive about numeric types from Firestore
            let bal: Int
            if let i = data["balance"] as? Int { bal = i }
            else if let d = data["balance"] as? Double { bal = Int(d) }
            else if let n = data["balance"] as? NSNumber { bal = n.intValue }
            else { bal = 0 }
            Task { @MainActor in self.balance = bal }
        }
        
        // Live updates for today's steps (daily_metrics/todayId)
        //let todayId = UserManager.shared.dateId(for: Date())
        let todayId = UserManager.dateId(for: Date())
        let dailyRef = Firestore.firestore()
            .collection("Users")
            .document(uid)
            .collection("daily_metrics")
            .document(todayId)
        
        dailyListener = dailyRef.addSnapshotListener { [weak self] snap, _ in
            guard let self else { return }
            let steps: Int
            if let data = snap?.data(), let any = data["step_count"] {
                if let i = any as? Int { steps = i }
                else if let d = any as? Double { steps = Int(d) }
                else if let n = any as? NSNumber { steps = n.intValue }
                else { steps = 0 }
            } else {
                steps = 0
            }
            Task { @MainActor in
                self.todaySteps = steps
                self.isLoaded = true
            }
        }
    }
    
    func stop() {
        userListener?.remove(); userListener = nil
        dailyListener?.remove(); dailyListener = nil
    }
    
    private func initialFetch(userId: String) async {
        do {
            let bal = try await UserManager.shared.getBalance(userId: userId)
            let metrics = try await UserManager.shared.getDailyMetrics(userId: userId, date: Date())
            await MainActor.run {
                self.balance = bal
                self.todaySteps = metrics?.stepCount ?? 0
                self.isLoaded = true
            }
        } catch {
            // TODO: log error
        }
    }
}

enum StatChange {
    case none
    case up
    case down
}

struct StatsDisplay: View {
    
    @EnvironmentObject var map: MapManager
    @StateObject private var viewModel = StatsDisplayViewModel()
    
    @State private var stepChange: StatChange = .none
    @State private var balanceChange: StatChange = .none
    
    @State private var lastSteps: Int = 0
    @State private var lastBalance: Int = 0
    
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
                            
                            Text(viewModel.todaySteps.formattedString())
                                .font(.custom("Press Start 2P", size: 13))
                                .foregroundColor(color(for: stepChange))
                                .shadow(color: glowColor(for: stepChange),
                                        radius: glowRadius(for: stepChange))
                                .animation(.easeOut(duration: 0.25), value: stepChange)
                        }
                        HStack {
                            Image("Coin")
                                .interpolation(.none)
                                .padding(.leading, 5)
                            
                            Text(viewModel.balance.formattedString())
                                .font(.custom("Press Start 2P", size: 13))
                                .padding(.leading, 6)
                                .foregroundColor(color(for: balanceChange))
                                .shadow(color: glowColor(for: balanceChange),
                                        radius: glowRadius(for: balanceChange))
                                .animation(.easeOut(duration: 0.25), value: balanceChange)
                        }
                    }
                    .padding()
                    .padding(.bottom,6)
                }
            }
        }
        .task {
            await viewModel.start()
            lastSteps = viewModel.todaySteps
            lastBalance = viewModel.balance
        }     // kick off listeners + initial fetch
        .onDisappear { viewModel.stop() }     // tidy up if this view can disappear
        
        // React to step changes
        .onChange(of: viewModel.todaySteps) {
            let newValue = viewModel.todaySteps
            let change: StatChange
            
            if newValue > lastSteps { change = .up }
            else if newValue < lastSteps { change = .down }
            else { change = .none }
            
            lastSteps = newValue
            flashStepChange(change)
        }
        
        // React to balance changes
        .onChange(of: viewModel.balance) {
            let newValue = viewModel.balance
            let change: StatChange
            
            if newValue > lastBalance { change = .up }
            else if newValue < lastBalance { change = .down }
            else { change = .none }
            
            lastBalance = newValue
            flashBalanceChange(change)
        }
    }
    
    // MARK: - Glow helpers
    private func color(for change: StatChange) -> Color {
        switch change {
        case .none: return .black
        case .up:   return .green
        case .down: return .red
        }
    }
    
    private func glowColor(for change: StatChange) -> Color {
        switch change {
        case .none: return .clear
        case .up:   return Color.green.opacity(0.9)
        case .down: return Color.red.opacity(0.9)
        }
    }
    
    private func glowRadius(for change: StatChange) -> CGFloat {
        change == .none ? 0 : 10
    }
    
    private func flashStepChange(_ change: StatChange) {
        guard change != .none else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            stepChange = change
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.25)) {
                stepChange = .none
            }
        }
    }
    
    private func flashBalanceChange(_ change: StatChange) {
        guard change != .none else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            balanceChange = change
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.25)) {
                balanceChange = .none
            }
        }
    }
}

#Preview {
    StatsDisplay()
        .environmentObject(MapManager())
    
}

extension Int {
    func formattedString() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
