//
//  AchievementsView.swift
//  StepWorld
//
//  Created by Isai soria on 11/24/25.
//

import SwiftUI

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    
    // TODO: Decide how you present this (sheet, full screen, navigation)
    // For now, we assume it’s inside a NavigationStack.
    
    var body: some View {
        VStack {
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if viewModel.isLoading {
                ProgressView("Loading achievements…")
                    .padding()
            }
            
            if viewModel.rows.isEmpty && !viewModel.isLoading {
                // TODO: nicer empty state
                Text("No achievements yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    // TODO: optionally group into sections, e.g. "Steps", "World", etc.
                    ForEach(viewModel.rows) { row in
                        AchievementRowView(row: row) {
                            await handleClaim(for: row)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Achievements") // TODO: custom title styling
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    // MARK: - Claim wrapper with basic error handling
    
    private func handleClaim(for row: AchievementsViewModel.Row) async {
        do {
            try await viewModel.claim(row)
        } catch {
            // TODO: surface errors nicely in UI (toast / banner)
            print("❌ Claim failed for \(row.id): \(error)")
        }
    }
}
